import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.8.0", (api) => {
  const router = api.container.lookup("router:main");
  
  // Initialize on page change
  api.onPageChange((url) => {
    initNavPosition();
    highlightActiveCategory(url);
    highlightActiveTag(url);
    initFloatingWidgets();
    checkGuestGate(url);
  });
  
  // Navigation item click handlers
  document.addEventListener("click", (e) => {
    // Category navigation click
    const item = e.target.closest(".rtt-item");
    if (item) {
      e.preventDefault();
      
      // 签到按钮特殊处理
      if (item.dataset.action === "checkin") {
        showCheckinModal();
        return;
      }
      
      const url = item.dataset.url;
      if (url) {
        router.transitionTo(url);
      }
      return;
    }
    
    // Tag navigation click
    const tagItem = e.target.closest(".tag-nav-item");
    if (tagItem) {
      e.preventDefault();
      const href = tagItem.getAttribute("href");
      if (href) {
        router.transitionTo(href);
      }
    }
    
    // Left arrow
    const leftArrow = e.target.closest(".rtt-arrow-left");
    if (leftArrow) {
      const container = document.querySelector(".rtt-inner");
      if (container) {
        container.scrollBy({ left: -200, behavior: "smooth" });
      }
    }
    
    // Right arrow
    const rightArrow = e.target.closest(".rtt-arrow-right");
    if (rightArrow) {
      const container = document.querySelector(".rtt-inner");
      if (container) {
        container.scrollBy({ left: 200, behavior: "smooth" });
      }
    }
  });
  
  // Scroll listener
  window.addEventListener("scroll", onScroll, { passive: true });
});

// Scroll throttle
let ticking = false;

function onScroll() {
  if (!ticking) {
    requestAnimationFrame(updateHeader);
    ticking = true;
  }
}

function updateHeader() {
  const bar = document.querySelector("#robotime-tag-top");
  if (bar) {
    const scrollTop = window.pageYOffset || document.documentElement.scrollTop;
    if (scrollTop > 200) {
      bar.classList.add("hideImg");
    } else if (scrollTop < 120) {
      bar.classList.remove("hideImg");
    }
  }
  ticking = false;
}

// Initialize navigation position
function initNavPosition() {
  const header = document.querySelector(".d-header-wrap");
  const bar = document.querySelector("#robotime-tag-top");
  const tagNav = document.querySelector("#robotime-tag-nav");
  
  if (header && bar && !bar.dataset.inserted) {
    header.insertAdjacentElement("afterend", bar);
    bar.dataset.inserted = "true";
  }
  
  if (bar && tagNav && !tagNav.dataset.inserted) {
    bar.insertAdjacentElement("afterend", tagNav);
    tagNav.dataset.inserted = "true";
  }
}

// Highlight active category
function highlightActiveCategory(currentUrl) {
  const items = document.querySelectorAll(".rtt-item");
  items.forEach((item) => {
    item.classList.remove("active");
    const category = item.dataset.category;
    const itemUrl = item.dataset.url;
    
    if (category === "home" && (currentUrl === "/" || currentUrl === "")) {
      item.classList.add("active");
    } else if (category && category !== "home") {
      if (currentUrl.includes(`/c/${category}`) || currentUrl.includes(itemUrl)) {
        item.classList.add("active");
      }
    }
  });
}

// Highlight active tag
function highlightActiveTag(currentUrl) {
  const items = document.querySelectorAll(".tag-nav-item");
  items.forEach((item) => {
    item.classList.remove("active");
    const href = item.getAttribute("href");
    if (href && currentUrl.includes(href) && href !== "/tags") {
      item.classList.add("active");
    }
  });
}

// Initialize floating widgets
function initFloatingWidgets() {
  // Check if already initialized
  if (document.querySelector(".robotime-left-panel")) {
    return;
  }
  
  // Only on desktop
  if (window.innerWidth <= 768) {
    return;
  }
  
  // Create left panel container
  const panel = document.createElement("div");
  panel.className = "robotime-left-panel";
  
  // Add activity widget
  const widget = createActivityWidgetElement();
  panel.appendChild(widget);
  
  // Add NEW TOPIC button for logged-in users
  const currentUser = document.querySelector(".header-dropdown-toggle.current-user");
  if (currentUser) {
    const fab = createFloatingButtonElement();
    panel.appendChild(fab);
  }
  
  document.body.appendChild(panel);
  
  // Initialize carousel
  initCarousel(widget);
}

function createFloatingButtonElement() {
  const fab = document.createElement("button");
  fab.className = "robotime-fab";
  fab.innerHTML = `
    <svg class="fab-icon" viewBox="0 0 24 24">
      <path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z"/>
    </svg>
    <span class="fab-text">NEW TOPIC</span>
  `;
  
  fab.addEventListener("click", () => {
    const createBtn = document.querySelector("#create-topic");
    if (createBtn) {
      createBtn.click();
    } else {
      window.location.href = "/new-topic";
    }
  });
  
  return fab;
}

function createActivityWidgetElement() {
  const widget = document.createElement("div");
  widget.className = "robotime-activity-widget";
  widget.innerHTML = `
    <div class="widget-header">
      <svg viewBox="0 0 24 24">
        <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
      </svg>
      Official Events
    </div>
    <div class="carousel">
      <div class="slide active">
        <div style="width:100%;height:100%;background:#228B22;display:flex;align-items:center;justify-content:center;color:#fff;font-size:13px;">Event Banner 1</div>
      </div>
      <div class="slide">
        <div style="width:100%;height:100%;background:#1E90FF;display:flex;align-items:center;justify-content:center;color:#fff;font-size:13px;">Event Banner 2</div>
      </div>
      <div class="dots">
        <button class="dot active" data-index="0"></button>
        <button class="dot" data-index="1"></button>
      </div>
    </div>
    <a href="/latest" class="widget-link">View All Events</a>
  `;
  
  return widget;
}

function initCarousel(widget) {
  const slides = widget.querySelectorAll(".slide");
  const dots = widget.querySelectorAll(".dot");
  let currentIndex = 0;
  
  function showSlide(index) {
    slides.forEach((slide, i) => {
      slide.classList.toggle("active", i === index);
    });
    dots.forEach((dot, i) => {
      dot.classList.toggle("active", i === index);
    });
  }
  
  // Auto carousel
  setInterval(() => {
    currentIndex = (currentIndex + 1) % slides.length;
    showSlide(currentIndex);
  }, 4000);
  
  // Dot click
  dots.forEach((dot) => {
    dot.addEventListener("click", () => {
      currentIndex = parseInt(dot.dataset.index);
      showSlide(currentIndex);
    });
  });
}

// Responsive handling
window.addEventListener("resize", () => {
  const panel = document.querySelector(".robotime-left-panel");
  
  if (window.innerWidth <= 768) {
    if (panel) panel.style.display = "none";
  } else {
    if (panel) panel.style.display = "flex";
  }
});

// ==========================================
// Check-in Modal - 签到弹窗
// ==========================================

function showCheckinModal() {
  // 检查是否已登录
  const currentUser = document.querySelector(".header-dropdown-toggle.current-user");
  if (!currentUser) {
    // 未登录，跳转到登录页
    window.location.href = "/login";
    return;
  }
  
  // 创建签到弹窗
  const existingModal = document.querySelector(".checkin-modal-overlay");
  if (existingModal) {
    existingModal.remove();
  }
  
  const modal = document.createElement("div");
  modal.className = "checkin-modal-overlay";
  modal.innerHTML = `
    <div class="checkin-modal">
      <div class="checkin-modal-header">
        <h3>Daily Check-in</h3>
        <button class="close-btn">&times;</button>
      </div>
      <div class="checkin-modal-body">
        <div class="checkin-loading">Loading...</div>
      </div>
    </div>
  `;
  
  document.body.appendChild(modal);
  
  // 关闭按钮
  modal.querySelector(".close-btn").addEventListener("click", () => {
    modal.remove();
  });
  
  modal.addEventListener("click", (e) => {
    if (e.target === modal) {
      modal.remove();
    }
  });
  
  // 加载签到数据
  loadCheckinData(modal);
}

async function loadCheckinData(modal) {
  try {
    const response = await fetch("/custom-plugin/checkin");
    const data = await response.json();
    
    const body = modal.querySelector(".checkin-modal-body");
    
    if (data.checked_in_today) {
      body.innerHTML = `
        <div class="checkin-success">
          <div class="check-icon">✓</div>
          <h4>Already Checked In Today!</h4>
          <p>Streak: ${data.consecutive_days} days</p>
          <div class="checkin-stats-mini">
            <span>Total: ${data.stats?.total_checkins || 0}</span>
            <span>Points: ${data.stats?.total_points || 0}</span>
          </div>
        </div>
      `;
    } else {
      body.innerHTML = `
        <div class="checkin-prompt">
          <div class="streak-info">Current Streak: ${data.consecutive_days} days</div>
          <button class="checkin-now-btn">Check In Now</button>
          <p class="checkin-hint">Check in daily for bonus points!</p>
        </div>
      `;
      
      body.querySelector(".checkin-now-btn").addEventListener("click", async () => {
        const btn = body.querySelector(".checkin-now-btn");
        btn.disabled = true;
        btn.textContent = "Checking in...";
        
        try {
          const res = await fetch("/custom-plugin/checkin", { method: "POST" });
          const result = await res.json();
          
          if (result.success) {
            body.innerHTML = `
              <div class="checkin-success">
                <div class="check-icon animated">✓</div>
                <h4>Check-in Successful!</h4>
                <p>+${result.checkin?.points_earned || 10} points</p>
                <p>Streak: ${result.consecutive_days} days</p>
                <div class="lottery-prompt">
                  <p>You earned a lucky draw chance!</p>
                  <button class="lottery-btn">Try Your Luck</button>
                </div>
              </div>
            `;
            
            body.querySelector(".lottery-btn")?.addEventListener("click", () => {
              modal.remove();
              // 跳转到个人资料页签到面板
              const username = document.querySelector(".header-dropdown-toggle.current-user .avatar")?.title;
              if (username) {
                window.location.href = `/u/${username}/preferences`;
              }
            });
          }
        } catch (err) {
          btn.textContent = "Error, try again";
          btn.disabled = false;
        }
      });
    }
  } catch (error) {
    modal.querySelector(".checkin-modal-body").innerHTML = `
      <div class="checkin-error">
        <p>Failed to load check-in data</p>
        <button onclick="this.closest('.checkin-modal-overlay').remove()">Close</button>
      </div>
    `;
  }
}

// ==========================================
// Guest Gate - 访客登录弹窗
// ==========================================

const GUEST_GATE_CONFIG = {
  maxViews: 3,                    // 最大浏览次数
  storageKey: "guest_topic_views", // localStorage 键名
  sessionKey: "guest_gate_shown",  // 是否已显示过弹窗
  showOnTopics: true,             // 在帖子详情页显示
};

function checkGuestGate(url) {
  // 检查是否已登录
  const currentUser = document.querySelector(".header-dropdown-toggle.current-user");
  if (currentUser) {
    return; // 已登录用户不显示
  }
  
  // 检查是否在帖子详情页
  if (!url.includes("/t/")) {
    return;
  }
  
  // 检查本次会话是否已显示过
  if (sessionStorage.getItem(GUEST_GATE_CONFIG.sessionKey)) {
    return;
  }
  
  // 获取并增加浏览次数
  let views = parseInt(localStorage.getItem(GUEST_GATE_CONFIG.storageKey) || "0");
  views++;
  localStorage.setItem(GUEST_GATE_CONFIG.storageKey, views.toString());
  
  // 检查是否达到阈值
  if (views >= GUEST_GATE_CONFIG.maxViews) {
    showGuestGateModal();
    sessionStorage.setItem(GUEST_GATE_CONFIG.sessionKey, "true");
  }
}

function showGuestGateModal() {
  // 检查是否已存在
  if (document.querySelector(".guest-gate-modal")) {
    return;
  }
  
  const modal = document.createElement("div");
  modal.className = "guest-gate-modal";
  modal.innerHTML = `
    <div class="guest-gate-overlay"></div>
    <div class="guest-gate-content">
      <button class="guest-gate-close" aria-label="关闭">
        <svg viewBox="0 0 24 24" fill="currentColor">
          <path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/>
        </svg>
      </button>
      <div class="guest-gate-icon">
        <svg viewBox="0 0 24 24" fill="currentColor">
          <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 3c1.66 0 3 1.34 3 3s-1.34 3-3 3-3-1.34-3-3 1.34-3 3-3zm0 14.2c-2.5 0-4.71-1.28-6-3.22.03-1.99 4-3.08 6-3.08 1.99 0 5.97 1.09 6 3.08-1.29 1.94-3.5 3.22-6 3.22z"/>
        </svg>
      </div>
      <h2 class="guest-gate-title">欢迎加入社区！</h2>
      <p class="guest-gate-text">注册解锁更多精彩内容，与志同道合的朋友交流分享</p>
      <div class="guest-gate-buttons">
        <a href="/signup" class="guest-gate-btn guest-gate-btn-primary">
          <svg viewBox="0 0 24 24" fill="currentColor">
            <path d="M15 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm-9-2V7H4v3H1v2h3v3h2v-3h3v-2H6zm9 4c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/>
          </svg>
          立即注册
        </a>
        <a href="/login" class="guest-gate-btn guest-gate-btn-secondary">
          <svg viewBox="0 0 24 24" fill="currentColor">
            <path d="M11 7L9.6 8.4l2.6 2.6H2v2h10.2l-2.6 2.6L11 17l5-5-5-5zm9 12h-8v2h8c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2h-8v2h8v14z"/>
          </svg>
          已有账号？登录
        </a>
      </div>
      <p class="guest-gate-footer">继续浏览即表示同意我们的<a href="/tos">服务条款</a></p>
    </div>
  `;
  
  document.body.appendChild(modal);
  
  // 添加动画
  requestAnimationFrame(() => {
    modal.classList.add("show");
  });
  
  // 关闭按钮事件
  modal.querySelector(".guest-gate-close").addEventListener("click", () => {
    closeGuestGateModal(modal);
  });
  
  // 点击遮罩关闭
  modal.querySelector(".guest-gate-overlay").addEventListener("click", () => {
    closeGuestGateModal(modal);
  });
  
  // ESC 键关闭
  document.addEventListener("keydown", function escHandler(e) {
    if (e.key === "Escape") {
      closeGuestGateModal(modal);
      document.removeEventListener("keydown", escHandler);
    }
  });
}

function closeGuestGateModal(modal) {
  modal.classList.remove("show");
  modal.classList.add("hide");
  setTimeout(() => {
    modal.remove();
  }, 300);
}
