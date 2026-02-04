import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.8.0", (api) => {
  const router = api.container.lookup("router:main");
  
  // 页面变化时初始化
  api.onPageChange((url) => {
    initNavPosition();
    highlightActiveCategory(url);
    initCustomSidebar();
    checkGuestGate(url);
  });
  
  // 点击事件处理
  document.addEventListener("click", (e) => {
    // 版块导航点击
    const categoryItem = e.target.closest(".category-item");
    if (categoryItem) {
      e.preventDefault();
      const href = categoryItem.getAttribute("href");
      if (href) {
        router.transitionTo(href);
      }
      return;
    }
    
    // 标签导航点击
    const tagItem = e.target.closest(".tag-item");
    if (tagItem) {
      e.preventDefault();
      const href = tagItem.getAttribute("href");
      if (href) {
        router.transitionTo(href);
      }
      return;
    }
    
    // 左箭头
    const leftArrow = e.target.closest(".nav-arrow-left");
    if (leftArrow) {
      const container = document.querySelector(".category-list");
      if (container) {
        container.scrollBy({ left: -200, behavior: "smooth" });
      }
    }
    
    // 右箭头
    const rightArrow = e.target.closest(".nav-arrow-right");
    if (rightArrow) {
      const container = document.querySelector(".category-list");
      if (container) {
        container.scrollBy({ left: 200, behavior: "smooth" });
      }
    }
  });
  
  // 滚动监听
  window.addEventListener("scroll", onScroll, { passive: true });
});

// 滚动节流
let ticking = false;

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
    // 滚动超过100px时收缩，回到50px以内恢复
    if (scrollTop > 100) {
      nav.classList.add("shrink");
    } else if (scrollTop < 50) {
      nav.classList.remove("shrink");
    }
  }
  ticking = false;
}

// 初始化导航栏位置
function initNavPosition() {
  const header = document.querySelector(".d-header-wrap");
  const brandNav = document.querySelector("#robotime-brand-nav");
  const categoryNav = document.querySelector("#robotime-category-nav");
  const tagNav = document.querySelector("#robotime-tag-nav");
  
  // 插入品牌导航栏
  if (header && brandNav && !brandNav.dataset.inserted) {
    header.insertAdjacentElement("afterend", brandNav);
    brandNav.dataset.inserted = "true";
  }
  
  // 插入版块导航栏
  if (brandNav && categoryNav && !categoryNav.dataset.inserted) {
    brandNav.insertAdjacentElement("afterend", categoryNav);
    categoryNav.dataset.inserted = "true";
  }
  
  // 插入标签导航栏
  if (categoryNav && tagNav && !tagNav.dataset.inserted) {
    categoryNav.insertAdjacentElement("afterend", tagNav);
    tagNav.dataset.inserted = "true";
  }
}

// 高亮当前版块
function highlightActiveCategory(currentUrl) {
  const items = document.querySelectorAll(".category-item");
  items.forEach((item) => {
    item.classList.remove("active");
    const href = item.getAttribute("href");
    if (href) {
      // 提取版块slug进行匹配
      const categorySlug = href.replace("/c/", "").split("/")[0];
      if (currentUrl.includes(`/c/${categorySlug}`) || 
          currentUrl.includes(`/c/${categorySlug}/`)) {
        item.classList.add("active");
      }
    }
  });
}

// ==========================================
// 自定义侧边栏
// ==========================================
function initCustomSidebar() {
  // 只在桌面端执行
  if (window.innerWidth <= 768) return;
  
  // 检查是否已初始化
  if (document.querySelector(".custom-sidebar-content")) return;
  
  const sidebar = document.querySelector(".sidebar-wrapper .sidebar-sections");
  if (!sidebar) return;
  
  // 创建自定义侧边栏内容
  const customContent = document.createElement("div");
  customContent.className = "custom-sidebar-content";
  customContent.innerHTML = `
    <div class="sidebar-section">
      <div class="sidebar-section-header">
        <span class="sidebar-section-header-text">Topics</span>
      </div>
      <ul class="sidebar-section-links">
        <li><a href="/my/activity" class="sidebar-link"><span>My Posts</span></a></li>
        <li><a href="/my/messages" class="sidebar-link"><span>my messages</span></a></li>
        <li><a href="/my/invited" class="sidebar-link"><span>Invite Friends</span></a></li>
        <li><a href="/latest" class="sidebar-link"><span>Topics</span></a></li>
        <li><a href="/c/help" class="sidebar-link"><span>Help</span></a></li>
        <li><a href="/c/how-to" class="sidebar-link"><span>How To</span></a></li>
        <li><a href="/badges" class="sidebar-link"><span>Badges</span></a></li>
      </ul>
    </div>
    
    <div class="sidebar-activity-widget">
      <div class="widget-header">
        <span>Official Events</span>
      </div>
      <div class="widget-carousel">
        <div class="carousel-slide active">
          <img src="https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=300&h=150&fit=crop" alt="Event 1" />
        </div>
        <div class="carousel-slide">
          <img src="https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=300&h=150&fit=crop" alt="Event 2" />
        </div>
        <div class="carousel-slide">
          <img src="https://images.unsplash.com/photo-1475721027785-f74eccf877e2?w=300&h=150&fit=crop" alt="Event 3" />
        </div>
        <div class="carousel-dots">
          <span class="dot active" data-index="0"></span>
          <span class="dot" data-index="1"></span>
          <span class="dot" data-index="2"></span>
        </div>
      </div>
      <a href="/c/events" class="widget-link">View All Events</a>
    </div>
    
    <button class="sidebar-new-topic-btn" onclick="document.querySelector('#create-topic')?.click()">
      <svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor">
        <path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z"/>
      </svg>
      NEW TOPIC
    </button>
  `;
  
  // 隐藏原有内容，插入自定义内容
  sidebar.style.display = "none";
  sidebar.parentNode.insertBefore(customContent, sidebar);
  
  // 启动轮播
  initSidebarCarousel();
}

// 侧边栏轮播
function initSidebarCarousel() {
  const slides = document.querySelectorAll(".widget-carousel .carousel-slide");
  const dots = document.querySelectorAll(".widget-carousel .dot");
  if (slides.length === 0) return;
  
  let currentIndex = 0;
  
  function showSlide(index) {
    slides.forEach((s, i) => s.classList.toggle("active", i === index));
    dots.forEach((d, i) => d.classList.toggle("active", i === index));
  }
  
  // 自动轮播
  setInterval(() => {
    currentIndex = (currentIndex + 1) % slides.length;
    showSlide(currentIndex);
  }, 4000);
  
  // 点击切换
  dots.forEach((dot) => {
    dot.addEventListener("click", () => {
      currentIndex = parseInt(dot.dataset.index);
      showSlide(currentIndex);
    });
  });
}

// ==========================================
// 访客阅读限制
// ==========================================
const GUEST_GATE_CONFIG = {
  maxViews: 3,
  readTimeLimit: 180, // 3分钟
  storageKey: "guest_topic_views",
  timeKey: "guest_read_time",
  sessionKey: "guest_gate_shown",
};

let guestReadTimer = null;
let guestReadStartTime = null;

function checkGuestGate(url) {
  const currentUser = document.querySelector(".header-dropdown-toggle.current-user");
  if (currentUser) {
    stopGuestReadTimer();
    return;
  }
  
  if (!url.includes("/t/")) {
    stopGuestReadTimer();
    return;
  }
  
  if (sessionStorage.getItem(GUEST_GATE_CONFIG.sessionKey)) {
    return;
  }
  
  let views = parseInt(localStorage.getItem(GUEST_GATE_CONFIG.storageKey) || "0");
  views++;
  localStorage.setItem(GUEST_GATE_CONFIG.storageKey, views.toString());
  
  if (views >= GUEST_GATE_CONFIG.maxViews) {
    showGuestGateModal();
    sessionStorage.setItem(GUEST_GATE_CONFIG.sessionKey, "true");
    return;
  }
  
  startGuestReadTimer();
}

function startGuestReadTimer() {
  stopGuestReadTimer();
  
  const savedTime = parseInt(localStorage.getItem(GUEST_GATE_CONFIG.timeKey) || "0");
  
  if (savedTime >= GUEST_GATE_CONFIG.readTimeLimit) {
    showGuestGateModal();
    sessionStorage.setItem(GUEST_GATE_CONFIG.sessionKey, "true");
    return;
  }
  
  guestReadStartTime = Date.now();
  const remainingTime = (GUEST_GATE_CONFIG.readTimeLimit - savedTime) * 1000;
  
  guestReadTimer = setTimeout(() => {
    const elapsedSeconds = Math.floor((Date.now() - guestReadStartTime) / 1000);
    localStorage.setItem(GUEST_GATE_CONFIG.timeKey, (savedTime + elapsedSeconds).toString());
    showGuestGateModal();
    sessionStorage.setItem(GUEST_GATE_CONFIG.sessionKey, "true");
  }, remainingTime);
}

function stopGuestReadTimer() {
  if (guestReadTimer) {
    if (guestReadStartTime) {
      const savedTime = parseInt(localStorage.getItem(GUEST_GATE_CONFIG.timeKey) || "0");
      const elapsedSeconds = Math.floor((Date.now() - guestReadStartTime) / 1000);
      localStorage.setItem(GUEST_GATE_CONFIG.timeKey, (savedTime + elapsedSeconds).toString());
    }
    clearTimeout(guestReadTimer);
    guestReadTimer = null;
    guestReadStartTime = null;
  }
}

function showGuestGateModal() {
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
        <a href="/signup" class="btn-primary">Sign Up</a>
        <a href="/login" class="btn-secondary">Log In</a>
      </div>
    </div>
  `;
  
  document.body.appendChild(modal);
  
  modal.querySelector(".guest-gate-close").addEventListener("click", () => modal.remove());
  modal.querySelector(".guest-gate-overlay").addEventListener("click", () => modal.remove());
}
