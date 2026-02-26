import { apiInitializer } from "discourse/lib/api";

function getSettings() {
  const el = document.getElementById("theme-settings-data");
  if (!el) return {};
  const s = {};
  for (const attr of el.attributes) {
    if (attr.name.startsWith("data-")) {
      const key = attr.name.slice(5);
      let val = attr.value;
      if (val === "true") val = true;
      else if (val === "false") val = false;
      else if (/^\d+$/.test(val)) val = parseInt(val, 10);
      s[key] = val;
    }
  }
  return s;
}

function getCsrfToken() {
  const meta = document.querySelector('meta[name="csrf-token"]');
  return meta ? meta.getAttribute("content") : "";
}

async function fetchJson(url, options = {}) {
  const headers = {
    "Accept": "application/json",
    "X-CSRF-Token": getCsrfToken(),
    ...(options.headers || {}),
  };
  if (options.method === "POST" || options.method === "PUT") {
    headers["Content-Type"] = "application/json";
  }
  const response = await fetch(url, { ...options, headers });
  return response.json();
}

export default apiInitializer("1.8.0", (api) => {
  const router = api.container.lookup("router:main");
  const site = api.container.lookup("service:site");
  const composer = api.container.lookup("service:composer");
  const S = getSettings();

  let initialized = false;

  api.onPageChange((url) => {
    if (!initialized) {
      buildBrandNav(S);
      buildCategoryNav(site, S);
      buildTagNav(S);
      buildActivityCarousel(S);
      setupFloatingButton(S);
      setupRegistrationBanner(S, url);
      initialized = true;
    }
    insertNavBars();
    insertLeftPanel();
    highlightActiveCategory(url);
    highlightActiveSidebar(url);
    checkGuestGate(url, S);
    showRegistrationBanner(S, url);
    setTimeout(() => enhanceTopicCards(), 800);
  });

  document.addEventListener("click", (e) => {
    const checkinBtn = e.target.closest("#nav-checkin-btn");
    if (checkinBtn) { e.preventDefault(); showCheckinModal(); return; }

    const markReadBtn = e.target.closest("#nav-mark-read-btn");
    if (markReadBtn) { e.preventDefault(); markAllRead(markReadBtn); return; }

    const floatingBtn = e.target.closest("#floating-new-topic");
    if (floatingBtn) { e.preventDefault(); openNewTopicComposer(composer); return; }

    const categoryItem = e.target.closest(".category-item");
    if (categoryItem) {
      e.preventDefault();
      const href = categoryItem.getAttribute("href");
      if (href) router.transitionTo(href);
      return;
    }

    const tagItem = e.target.closest(".tag-item");
    if (tagItem) {
      e.preventDefault();
      const href = tagItem.getAttribute("href");
      if (href) router.transitionTo(href);
      return;
    }

    const sidebarItem = e.target.closest(".sidebar-section .sidebar-item");
    if (sidebarItem) {
      e.preventDefault();
      const href = sidebarItem.getAttribute("href");
      if (href) router.transitionTo(href);
      return;
    }

    const leftArrow = e.target.closest(".nav-arrow-left");
    if (leftArrow) {
      document.querySelector(".category-list")?.scrollBy({ left: -200, behavior: "smooth" });
    }
    const rightArrow = e.target.closest(".nav-arrow-right");
    if (rightArrow) {
      document.querySelector(".category-list")?.scrollBy({ left: 200, behavior: "smooth" });
    }

    const dot = e.target.closest(".carousel-dots .dot");
    if (dot) {
      goToSlide(parseInt(dot.dataset.index));
    }
  });

  window.addEventListener("scroll", onScroll, { passive: true });

  const contentObserver = new MutationObserver(() => {
    const items = document.querySelectorAll(".topic-list-item:not([data-enhanced])");
    if (items.length > 0) setTimeout(() => enhanceTopicCards(), 300);
  });
  const mainOutlet = document.getElementById("main-outlet");
  if (mainOutlet) {
    contentObserver.observe(mainOutlet, { childList: true, subtree: true });
  }
});

// ===========================================
// 品牌导航栏
// ===========================================
function buildBrandNav(S) {
  const nav = document.getElementById("robotime-brand-nav");
  if (!nav) return;

  const logo = nav.querySelector(".brand-logo");
  if (logo) logo.textContent = S.brand_name || "ROBOTIME";

  const container = document.getElementById("brand-links-container");
  if (!container) return;

  if (S.show_checkin_nav) {
    const btn = document.createElement("a");
    btn.href = "#";
    btn.className = "checkin-link";
    btn.id = "nav-checkin-btn";
    btn.textContent = "Check-in";
    container.appendChild(btn);
  }

  const currentUser = document.querySelector(".header-dropdown-toggle.current-user");
  if (currentUser) {
    const markBtn = document.createElement("a");
    markBtn.href = "#";
    markBtn.className = "mark-read-link";
    markBtn.id = "nav-mark-read-btn";
    markBtn.textContent = "Mark All Read";
    container.appendChild(markBtn);
  }

  const links = (S.brand_links || "").split(",");
  links.forEach(item => {
    const parts = item.trim().split("|");
    if (parts.length >= 2) {
      const a = document.createElement("a");
      a.href = parts[1].trim();
      a.textContent = parts[0].trim();
      if (parts[1].trim().startsWith("http")) a.target = "_blank";
      container.appendChild(a);
    }
  });

  nav.style.display = "";
  if (S.nav_background) nav.style.background = S.nav_background;
}

// ===========================================
// 版块导航
// ===========================================
function buildCategoryNav(site, S) {
  const container = document.getElementById("category-list-container");
  const nav = document.getElementById("robotime-category-nav");
  if (!container || !nav) return;

  const categories = site.categories || [];
  if (categories.length === 0) return;

  const sorted = categories
    .filter(c => !c.parent_category_id && c.id !== 1)
    .sort((a, b) => (a.position || 0) - (b.position || 0))
    .slice(0, 12);

  sorted.forEach(cat => {
    const a = document.createElement("a");
    a.href = `/c/${cat.slug}/${cat.id}`;
    a.className = "category-item";
    a.dataset.slug = cat.slug;

    const imgDiv = document.createElement("div");
    imgDiv.className = "category-image";

    const catAssetMap = {
      help: S.asset_cat_help,
      "community-perks": S.asset_cat_community,
      "win-prize": S.asset_cat_prize,
      general: S.asset_cat_general,
      "how-to": S.asset_cat_howto,
    };

    const logoUrl = cat.uploaded_logo?.url || cat.uploaded_logo || catAssetMap[cat.slug] || "";

    if (logoUrl) {
      const img = document.createElement("img");
      img.src = logoUrl;
      img.alt = cat.name;
      img.loading = "lazy";
      imgDiv.appendChild(img);
    } else {
      const placeholder = document.createElement("div");
      placeholder.className = "category-placeholder";
      placeholder.textContent = cat.name.charAt(0).toUpperCase();
      if (cat.color) placeholder.style.background = `#${cat.color}`;
      imgDiv.appendChild(placeholder);
    }

    const nameSpan = document.createElement("span");
    nameSpan.className = "category-name";
    nameSpan.textContent = cat.name;

    a.appendChild(imgDiv);
    a.appendChild(nameSpan);
    container.appendChild(a);
  });

  nav.style.display = "";
  if (S.nav_background) nav.style.background = S.nav_background;
}

// ===========================================
// 标签导航栏
// ===========================================
function buildTagNav(S) {
  if (!S.show_tag_nav) return;
  const nav = document.getElementById("robotime-tag-nav");
  if (!nav) return;

  const items = (S.tag_nav_items || "").split(",");
  items.forEach(item => {
    const parts = item.trim().split("|");
    if (parts.length >= 2) {
      const a = document.createElement("a");
      a.href = parts[1].trim();
      a.className = "tag-item";
      a.textContent = parts[0].trim();
      nav.appendChild(a);
    }
  });
  nav.style.display = "";
}

// ===========================================
// 左侧面板插入
// ===========================================
function insertLeftPanel() {
  const panel = document.getElementById("left-panel");
  const wrapper = document.getElementById("main-outlet-wrapper");
  const mainOutlet = document.getElementById("main-outlet");

  if (panel && wrapper && mainOutlet && !panel.dataset.inserted) {
    panel.style.display = "";
    wrapper.insertBefore(panel, mainOutlet);
    panel.dataset.inserted = "true";
  }
}

function highlightActiveSidebar(url) {
  const items = document.querySelectorAll(".sidebar-section .sidebar-item");
  items.forEach(item => {
    item.classList.remove("active");
    const href = item.getAttribute("href");
    if (href === "/latest" && (url === "/" || url === "/latest")) {
      item.classList.add("active");
    } else if (href !== "/latest" && href && url.startsWith(href)) {
      item.classList.add("active");
    }
  });
}

// ===========================================
// 活动轮播
// ===========================================
let currentSlide = 0;
let totalSlides = 0;

function buildActivityCarousel(S) {
  if (!S.show_carousel) return;

  const carouselSection = document.getElementById("activity-carousel");
  const slidesContainer = document.getElementById("carousel-slides-container");
  const dotsContainer = document.getElementById("carousel-dots");
  const titleEl = carouselSection?.querySelector(".carousel-title");
  if (!carouselSection || !slidesContainer || !dotsContainer) return;

  if (titleEl) titleEl.textContent = S.carousel_title || "Official Events";

  const slides = [];
  for (let i = 1; i <= 5; i++) {
    const slideData = S[`carousel_slide_${i}`];
    if (slideData && typeof slideData === "string" && slideData.trim()) {
      const parts = slideData.split("|");
      if (parts.length >= 2) {
        slides.push({
          image: parts[0].trim(),
          link: parts[1].trim(),
          title: parts[2]?.trim() || ""
        });
      }
    }
  }

  if (slides.length === 0) {
    carouselSection.style.display = "none";
    return;
  }

  slides.forEach((slide, idx) => {
    const a = document.createElement("a");
    a.className = "carousel-slide";
    a.href = slide.link;

    const img = document.createElement("img");
    img.src = slide.image;
    img.alt = slide.title;
    img.loading = "lazy";
    a.appendChild(img);

    if (slide.title) {
      const titleDiv = document.createElement("div");
      titleDiv.className = "slide-title";
      titleDiv.textContent = slide.title;
      a.appendChild(titleDiv);
    }

    slidesContainer.appendChild(a);

    const dot = document.createElement("span");
    dot.className = "dot" + (idx === 0 ? " active" : "");
    dot.dataset.index = idx;
    dotsContainer.appendChild(dot);
  });

  totalSlides = slides.length;
  carouselSection.style.display = "";

  if (totalSlides > 1) {
    setInterval(() => {
      currentSlide = (currentSlide + 1) % totalSlides;
      goToSlide(currentSlide);
    }, 4000);
  }
}

function goToSlide(idx) {
  currentSlide = idx;
  const slidesContainer = document.getElementById("carousel-slides-container");
  if (slidesContainer) {
    slidesContainer.style.transform = `translateX(-${idx * 100}%)`;
  }
  const dots = document.querySelectorAll(".carousel-dots .dot");
  dots.forEach((d, i) => d.classList.toggle("active", i === idx));
}

// ===========================================
// 导航栏插入
// ===========================================
function insertNavBars() {
  const header = document.querySelector(".d-header-wrap");
  const brandNav = document.getElementById("robotime-brand-nav");
  const categoryNav = document.getElementById("robotime-category-nav");
  const tagNav = document.getElementById("robotime-tag-nav");

  if (header && brandNav && !brandNav.dataset.inserted) {
    header.insertAdjacentElement("afterend", brandNav);
    brandNav.dataset.inserted = "true";
  }
  if (brandNav && categoryNav && !categoryNav.dataset.inserted) {
    brandNav.insertAdjacentElement("afterend", categoryNav);
    categoryNav.dataset.inserted = "true";
  }
  if (categoryNav && tagNav && !tagNav.dataset.inserted) {
    categoryNav.insertAdjacentElement("afterend", tagNav);
    tagNav.dataset.inserted = "true";
  }
}

// ===========================================
// 高亮当前版块
// ===========================================
function highlightActiveCategory(currentUrl) {
  const items = document.querySelectorAll(".category-item");
  items.forEach(item => {
    item.classList.remove("active");
    const slug = item.dataset.slug;
    if (slug && currentUrl.includes(`/c/${slug}`)) {
      item.classList.add("active");
    }
  });
}

// ===========================================
// 悬浮发帖按钮
// ===========================================
function setupFloatingButton(S) {
  if (!S.show_floating_button) return;
  const btn = document.getElementById("floating-new-topic");
  if (!btn) return;

  const currentUser = document.querySelector(".header-dropdown-toggle.current-user");
  if (currentUser) btn.style.display = "";
}

function openNewTopicComposer(composer) {
  if (!composer) return;
  const currentUser = document.querySelector(".header-dropdown-toggle.current-user");
  if (!currentUser) { window.location.href = "/login"; return; }
  composer.open({ action: "createTopic", draftKey: "new_topic", draftSequence: 0 });
}

// ===========================================
// 帖子卡片增强
// ===========================================
let enhancePending = false;

function enhanceTopicCards() {
  const items = document.querySelectorAll(".topic-list-item:not([data-enhanced])");
  if (items.length === 0 || enhancePending) return;
  enhancePending = true;

  const currentPath = window.location.pathname;
  let apiUrl = "/latest.json";
  if (currentPath.includes("/c/")) {
    const match = currentPath.match(/\/c\/[^/]+\/(\d+)/);
    if (match) apiUrl = `/c/${match[1]}.json`;
    else apiUrl = currentPath.replace(/\/$/, "") + ".json";
  } else if (currentPath.includes("/top")) {
    apiUrl = "/top.json";
  } else if (currentPath.includes("/new")) {
    apiUrl = "/new.json";
  }

  fetch(apiUrl, { headers: { "Accept": "application/json" } })
    .then(r => r.json())
    .then(data => {
      const topics = data.topic_list?.topics || [];
      const topicMap = {};
      topics.forEach(t => { topicMap[t.id] = t; });

      items.forEach(item => {
        item.dataset.enhanced = "true";
        const topicId = parseInt(item.dataset.topicId);
        const topic = topicMap[topicId];
        if (!topic) return;

        const mainLink = item.querySelector(".main-link");
        if (!mainLink) return;

        if (topic.image_url && !item.querySelector(".topic-thumbnail")) {
          const thumb = document.createElement("div");
          thumb.className = "topic-thumbnail";
          const img = document.createElement("img");
          img.src = topic.image_url;
          img.alt = "";
          img.loading = "lazy";
          thumb.appendChild(img);
          item.insertBefore(thumb, item.firstChild);
        }

        if (!item.querySelector(".topic-stats-bar")) {
          const statsBar = document.createElement("div");
          statsBar.className = "topic-stats-bar";
          const views = topic.views || 0;
          const likes = topic.like_count || 0;
          const replies = (topic.posts_count || 1) - 1;

          statsBar.innerHTML = `
            <span class="stat-item" title="Views">
              <svg viewBox="0 0 24 24"><path d="M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5c-1.73-4.39-6-7.5-11-7.5zM12 17c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm0-8c-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3-1.34-3-3-3z"/></svg>
              ${views}
            </span>
            <span class="stat-item" title="Likes">
              <svg viewBox="0 0 24 24"><path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/></svg>
              ${likes}
            </span>
            <span class="stat-item" title="Replies">
              <svg viewBox="0 0 24 24"><path d="M21 6h-2v9H6v2c0 .55.45 1 1 1h11l4 4V7c0-.55-.45-1-1-1zm-4 6V3c0-.55-.45-1-1-1H3c-.55 0-1 .45-1 1v14l4-4h10c.55 0 1-.45 1-1z"/></svg>
              ${replies}
            </span>
          `;
          const linkBottom = mainLink.querySelector(".link-bottom-line");
          if (linkBottom) mainLink.insertBefore(statsBar, linkBottom.nextSibling);
          else mainLink.appendChild(statsBar);
        }
      });
      enhancePending = false;
    })
    .catch(() => { enhancePending = false; });
}

// ===========================================
// 一键已读
// ===========================================
async function markAllRead(btn) {
  const originalText = btn.textContent;
  btn.textContent = "...";
  try {
    await fetchJson("/notifications/mark-read", { method: "PUT" });
    await fetchJson("/topics/reset-new", { method: "PUT" });
    btn.textContent = "Done!";
    setTimeout(() => { btn.textContent = originalText; }, 2000);
  } catch { btn.textContent = originalText; }
}

// ===========================================
// 注册页面 Banner
// ===========================================
function setupRegistrationBanner(S, url) {
  if (!S.show_registration_banner || !S.registration_banner_url) return;
  const banner = document.getElementById("registration-banner");
  if (!banner) return;
  if (S.registration_banner_url) banner.style.backgroundImage = `url(${S.registration_banner_url})`;
  banner.querySelector(".registration-banner-title").textContent = S.registration_banner_text || "";
  banner.querySelector(".registration-banner-desc").textContent = S.registration_banner_desc || "";
}

function showRegistrationBanner(S, url) {
  if (!S.show_registration_banner) return;
  const banner = document.getElementById("registration-banner");
  if (!banner) return;
  banner.style.display = (url.includes("/signup") || url.includes("/register")) ? "" : "none";
}

// ===========================================
// 签到弹窗
// ===========================================
function showCheckinModal() {
  const currentUser = document.querySelector(".header-dropdown-toggle.current-user");
  if (!currentUser) { window.location.href = "/login"; return; }

  const existing = document.querySelector(".checkin-modal-overlay");
  if (existing) { existing.style.display = "flex"; return; }

  const modal = document.createElement("div");
  modal.className = "checkin-modal-overlay";
  modal.innerHTML = `
    <div class="checkin-modal">
      <button class="modal-close">&times;</button>
      <h2>Daily Check-in</h2>
      <div class="checkin-modal-content">
        <div id="checkin-status">Loading...</div>
        <button id="do-checkin-btn" class="checkin-action-btn" style="display:none;">Check In Now</button>
        <div id="checkin-stats" class="modal-stats"></div>
        <div id="lottery-section" style="display:none;">
          <h3>Lucky Draw</h3>
          <button id="do-lottery-btn" class="lottery-action-btn">Draw Now</button>
          <div id="lottery-result"></div>
        </div>
      </div>
    </div>
  `;
  document.body.appendChild(modal);

  const closeModal = () => { modal.style.display = "none"; };
  modal.querySelector(".modal-close").addEventListener("click", closeModal);
  modal.addEventListener("click", (e) => { if (e.target === modal) closeModal(); });
  loadCheckinStatus();
}

async function loadCheckinStatus() {
  try {
    const data = await fetchJson("/custom-plugin/checkin");
    const statusEl = document.getElementById("checkin-status");
    const btnEl = document.getElementById("do-checkin-btn");
    const statsEl = document.getElementById("checkin-stats");
    const lotteryEl = document.getElementById("lottery-section");

    if (data.checked_in_today) {
      statusEl.innerHTML = `<span class="checked-text">Checked in! +${data.today_checkin?.points_earned || 10} pts</span>`;
      btnEl.style.display = "none";
      const lotteryData = await fetchJson("/custom-plugin/checkin/lottery");
      if (lotteryData.can_draw) {
        lotteryEl.style.display = "block";
        document.getElementById("do-lottery-btn").onclick = doLotteryDraw;
      } else if (lotteryData.today_prize) {
        lotteryEl.style.display = "block";
        document.getElementById("do-lottery-btn").style.display = "none";
        document.getElementById("lottery-result").innerHTML = `<p class="prize-won">Won: ${lotteryData.today_prize}</p>`;
      }
    } else {
      statusEl.textContent = "You haven't checked in today";
      btnEl.style.display = "block";
      btnEl.onclick = doCheckin;
    }

    statsEl.innerHTML = `
      <div class="stat"><span class="value">${data.stats?.total_checkins || 0}</span><span class="label">Total</span></div>
      <div class="stat"><span class="value">${data.stats?.total_points || 0}</span><span class="label">Points</span></div>
      <div class="stat"><span class="value">${data.consecutive_days || 0}</span><span class="label">Streak</span></div>
    `;
  } catch {
    const el = document.getElementById("checkin-status");
    if (el) el.textContent = "Failed to load";
  }
}

async function doCheckin() {
  const btn = document.getElementById("do-checkin-btn");
  btn.disabled = true; btn.textContent = "Checking in...";
  try {
    const data = await fetchJson("/custom-plugin/checkin", { method: "POST" });
    if (data.success) loadCheckinStatus();
  } catch { btn.disabled = false; btn.textContent = "Check In Now"; }
}

async function doLotteryDraw() {
  const btn = document.getElementById("do-lottery-btn");
  btn.disabled = true; btn.textContent = "Drawing...";
  try {
    const data = await fetchJson("/custom-plugin/checkin/draw", { method: "POST" });
    if (data.success) {
      btn.style.display = "none";
      document.getElementById("lottery-result").innerHTML = `<p class="prize-won">Won: ${data.prize}</p>`;
    }
  } catch { btn.disabled = false; btn.textContent = "Draw Now"; }
}

// ===========================================
// 滚动行为
// ===========================================
let ticking = false;
let isShrunken = false;

function onScroll() {
  if (!ticking) { requestAnimationFrame(updateNavOnScroll); ticking = true; }
}

function updateNavOnScroll() {
  const nav = document.querySelector(".robotime-category-nav");
  if (nav) {
    const scrollTop = window.pageYOffset || document.documentElement.scrollTop;
    if (!isShrunken && scrollTop > 150) { nav.classList.add("shrink"); isShrunken = true; }
    else if (isShrunken && scrollTop < 30) { nav.classList.remove("shrink"); isShrunken = false; }
  }
  ticking = false;
}

// ===========================================
// 访客阅读限制
// ===========================================
const GATE_STORAGE = "guest_topic_views";
const GATE_TIME = "guest_read_time";
let guestTimer = null;
let guestStart = null;

function checkGuestGate(url, S) {
  if (!S.guest_gate_enabled) return;
  const currentUser = document.querySelector(".header-dropdown-toggle.current-user");
  if (currentUser) { stopGuestTimer(); return; }
  if (!url.includes("/t/")) { stopGuestTimer(); return; }

  const views = parseInt(localStorage.getItem(GATE_STORAGE) || "0");
  const readTime = parseInt(localStorage.getItem(GATE_TIME) || "0");
  if (views >= (S.guest_max_views || 3) || readTime >= (S.guest_read_time || 180)) {
    showGuestGate(); return;
  }

  localStorage.setItem(GATE_STORAGE, (views + 1).toString());
  if (views + 1 >= (S.guest_max_views || 3)) {
    showGuestGate(); return;
  }
  startGuestTimer(S);
}

function startGuestTimer(S) {
  stopGuestTimer();
  const saved = parseInt(localStorage.getItem(GATE_TIME) || "0");
  const limit = S.guest_read_time || 180;
  if (saved >= limit) { showGuestGate(); return; }

  guestStart = Date.now();
  guestTimer = setTimeout(() => {
    const elapsed = Math.floor((Date.now() - guestStart) / 1000);
    localStorage.setItem(GATE_TIME, (saved + elapsed).toString());
    showGuestGate();
  }, (limit - saved) * 1000);
}

function stopGuestTimer() {
  if (guestTimer) {
    if (guestStart) {
      const saved = parseInt(localStorage.getItem(GATE_TIME) || "0");
      const elapsed = Math.floor((Date.now() - guestStart) / 1000);
      localStorage.setItem(GATE_TIME, (saved + elapsed).toString());
    }
    clearTimeout(guestTimer); guestTimer = null; guestStart = null;
  }
}

function showGuestGate() {
  if (document.querySelector(".guest-gate-modal")) return;
  document.body.style.overflow = "hidden";
  const modal = document.createElement("div");
  modal.className = "guest-gate-modal";
  modal.innerHTML = `
    <div class="guest-gate-overlay"></div>
    <div class="guest-gate-content">
      <div class="guest-gate-icon">
        <svg viewBox="0 0 24 24" width="48" height="48" fill="#228B22">
          <path d="M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm3.1-9H8.9V6c0-1.71 1.39-3.1 3.1-3.1 1.71 0 3.1 1.39 3.1 3.1v2z"/>
        </svg>
      </div>
      <h2>Welcome to the Community!</h2>
      <p>Sign up to unlock unlimited reading and connect with others</p>
      <div class="guest-gate-buttons">
        <a href="/signup" class="guest-gate-btn-primary">Sign Up Free</a>
        <a href="/login" class="guest-gate-btn-secondary">Log In</a>
      </div>
      <p class="guest-gate-hint">Registration is free and takes less than 30 seconds</p>
    </div>
  `;
  document.body.appendChild(modal);
  requestAnimationFrame(() => modal.classList.add("show"));
}
