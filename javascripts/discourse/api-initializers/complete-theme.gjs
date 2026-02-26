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
  if (options.method === "POST") {
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
      setupFloatingButton(S, composer);
      setupRegistrationBanner(S, url);
      initialized = true;
    }
    insertNavBars();
    highlightActiveCategory(url);
    checkGuestGate(url, S);
    showRegistrationBanner(S, url);
  });

  document.addEventListener("click", (e) => {
    const checkinBtn = e.target.closest("#nav-checkin-btn");
    if (checkinBtn) {
      e.preventDefault();
      showCheckinModal();
      return;
    }

    const markReadBtn = e.target.closest("#nav-mark-read-btn");
    if (markReadBtn) {
      e.preventDefault();
      markAllRead(markReadBtn);
      return;
    }

    const floatingBtn = e.target.closest("#floating-new-topic");
    if (floatingBtn) {
      e.preventDefault();
      openNewTopicComposer(composer);
      return;
    }

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

    const leftArrow = e.target.closest(".nav-arrow-left");
    if (leftArrow) {
      document.querySelector(".category-list")?.scrollBy({ left: -200, behavior: "smooth" });
    }

    const rightArrow = e.target.closest(".nav-arrow-right");
    if (rightArrow) {
      document.querySelector(".category-list")?.scrollBy({ left: 200, behavior: "smooth" });
    }
  });

  window.addEventListener("scroll", onScroll, { passive: true });
});

// ===========================================
// 构建品牌导航栏
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
// 构建版块导航（从 Discourse 分类数据动态生成）
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

    if (cat.uploaded_logo) {
      const img = document.createElement("img");
      img.src = cat.uploaded_logo.url || cat.uploaded_logo;
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
// 构建标签导航栏
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
// 插入导航栏到正确位置
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
function setupFloatingButton(S, composer) {
  if (!S.show_floating_button) return;

  const btn = document.getElementById("floating-new-topic");
  if (!btn) return;

  const currentUser = document.querySelector(".header-dropdown-toggle.current-user");
  if (currentUser) {
    btn.style.display = "";
  }
}

function openNewTopicComposer(composer) {
  if (!composer) return;
  const currentUser = document.querySelector(".header-dropdown-toggle.current-user");
  if (!currentUser) {
    window.location.href = "/login";
    return;
  }
  composer.open({ action: "createTopic", draftKey: "new_topic", draftSequence: 0 });
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
  } catch {
    btn.textContent = originalText;
  }
}

// ===========================================
// 注册页面 Banner
// ===========================================
function setupRegistrationBanner(S, url) {
  if (!S.show_registration_banner || !S.registration_banner_url) return;

  const banner = document.getElementById("registration-banner");
  if (!banner) return;

  if (S.registration_banner_url) {
    banner.style.backgroundImage = `url(${S.registration_banner_url})`;
  }
  banner.querySelector(".registration-banner-title").textContent = S.registration_banner_text || "";
  banner.querySelector(".registration-banner-desc").textContent = S.registration_banner_desc || "";
}

function showRegistrationBanner(S, url) {
  if (!S.show_registration_banner) return;
  const banner = document.getElementById("registration-banner");
  if (!banner) return;

  const isSignup = url.includes("/signup") || url.includes("/register");
  banner.style.display = isSignup ? "" : "none";
}

// ===========================================
// 签到弹窗
// ===========================================
function showCheckinModal() {
  const currentUser = document.querySelector(".header-dropdown-toggle.current-user");
  if (!currentUser) {
    window.location.href = "/login";
    return;
  }

  const existing = document.querySelector(".checkin-modal-overlay");
  if (existing) {
    existing.style.display = "flex";
    return;
  }

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
  btn.disabled = true;
  btn.textContent = "Checking in...";
  try {
    const data = await fetchJson("/custom-plugin/checkin", { method: "POST" });
    if (data.success) loadCheckinStatus();
  } catch {
    btn.disabled = false;
    btn.textContent = "Check In Now";
  }
}

async function doLotteryDraw() {
  const btn = document.getElementById("do-lottery-btn");
  btn.disabled = true;
  btn.textContent = "Drawing...";
  try {
    const data = await fetchJson("/custom-plugin/checkin/draw", { method: "POST" });
    if (data.success) {
      btn.style.display = "none";
      document.getElementById("lottery-result").innerHTML = `<p class="prize-won">Won: ${data.prize}</p>`;
    }
  } catch {
    btn.disabled = false;
    btn.textContent = "Draw Now";
  }
}

// ===========================================
// 滚动行为
// ===========================================
let ticking = false;
let isShrunken = false;

function onScroll() {
  if (!ticking) {
    requestAnimationFrame(updateNavOnScroll);
    ticking = true;
  }
}

function updateNavOnScroll() {
  const nav = document.querySelector(".robotime-category-nav");
  if (nav) {
    const scrollTop = window.pageYOffset || document.documentElement.scrollTop;
    if (!isShrunken && scrollTop > 150) {
      nav.classList.add("shrink");
      isShrunken = true;
    } else if (isShrunken && scrollTop < 30) {
      nav.classList.remove("shrink");
      isShrunken = false;
    }
  }
  ticking = false;
}

// ===========================================
// 访客阅读限制
// ===========================================
const GATE_STORAGE = "guest_topic_views";
const GATE_TIME = "guest_read_time";
const GATE_SESSION = "guest_gate_shown";
let guestTimer = null;
let guestStart = null;

function checkGuestGate(url, S) {
  if (!S.guest_gate_enabled) return;

  const currentUser = document.querySelector(".header-dropdown-toggle.current-user");
  if (currentUser) { stopGuestTimer(); return; }
  if (!url.includes("/t/")) { stopGuestTimer(); return; }
  if (sessionStorage.getItem(GATE_SESSION)) return;

  let views = parseInt(localStorage.getItem(GATE_STORAGE) || "0");
  views++;
  localStorage.setItem(GATE_STORAGE, views.toString());

  if (views >= (S.guest_max_views || 3)) {
    showGuestGate();
    sessionStorage.setItem(GATE_SESSION, "true");
    return;
  }

  startGuestTimer(S);
}

function startGuestTimer(S) {
  stopGuestTimer();
  const saved = parseInt(localStorage.getItem(GATE_TIME) || "0");
  const limit = S.guest_read_time || 180;

  if (saved >= limit) {
    showGuestGate();
    sessionStorage.setItem(GATE_SESSION, "true");
    return;
  }

  guestStart = Date.now();
  guestTimer = setTimeout(() => {
    const elapsed = Math.floor((Date.now() - guestStart) / 1000);
    localStorage.setItem(GATE_TIME, (saved + elapsed).toString());
    showGuestGate();
    sessionStorage.setItem(GATE_SESSION, "true");
  }, (limit - saved) * 1000);
}

function stopGuestTimer() {
  if (guestTimer) {
    if (guestStart) {
      const saved = parseInt(localStorage.getItem(GATE_TIME) || "0");
      const elapsed = Math.floor((Date.now() - guestStart) / 1000);
      localStorage.setItem(GATE_TIME, (saved + elapsed).toString());
    }
    clearTimeout(guestTimer);
    guestTimer = null;
    guestStart = null;
  }
}

function showGuestGate() {
  if (document.querySelector(".guest-gate-modal")) return;

  const modal = document.createElement("div");
  modal.className = "guest-gate-modal";
  modal.innerHTML = `
    <div class="guest-gate-overlay"></div>
    <div class="guest-gate-content">
      <button class="guest-gate-close">&times;</button>
      <div class="guest-gate-icon">
        <svg viewBox="0 0 24 24" width="48" height="48" fill="#228B22">
          <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 3c1.66 0 3 1.34 3 3s-1.34 3-3 3-3-1.34-3-3 1.34-3 3-3zm0 14.2c-2.5 0-4.71-1.28-6-3.22.03-1.99 4-3.08 6-3.08 1.99 0 5.97 1.09 6 3.08-1.29 1.94-3.5 3.22-6 3.22z"/>
        </svg>
      </div>
      <h2>Welcome to the Community!</h2>
      <p>Sign up to unlock more content and connect with others</p>
      <div class="guest-gate-buttons">
        <a href="/signup" class="guest-gate-btn-primary">Sign Up</a>
        <a href="/login" class="guest-gate-btn-secondary">Log In</a>
      </div>
    </div>
  `;

  document.body.appendChild(modal);
  requestAnimationFrame(() => modal.classList.add("show"));

  const close = () => {
    modal.classList.remove("show");
    modal.classList.add("hide");
    setTimeout(() => modal.remove(), 300);
  };
  modal.querySelector(".guest-gate-close").addEventListener("click", close);
  modal.querySelector(".guest-gate-overlay").addEventListener("click", close);
}
