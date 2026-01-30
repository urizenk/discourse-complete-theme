import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.8.0", (api) => {
  const router = api.container.lookup("router:main");
  
  // Initialize on page change
  api.onPageChange((url) => {
    initNavPosition();
    highlightActiveCategory(url);
    highlightActiveTag(url);
    initFloatingWidgets();
  });
  
  // Navigation item click handlers
  document.addEventListener("click", (e) => {
    // Category navigation click
    const item = e.target.closest(".rtt-item");
    if (item) {
      e.preventDefault();
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
  if (document.querySelector(".robotime-fab")) {
    return;
  }
  
  // Check if logged in
  const currentUser = document.querySelector(".header-dropdown-toggle.current-user");
  
  // Create floating button for logged-in users
  if (currentUser) {
    createFloatingButton();
  }
  
  // Create activity widget (desktop only)
  if (window.innerWidth > 768) {
    createActivityWidget();
  }
}

function createFloatingButton() {
  const fab = document.createElement("button");
  fab.className = "robotime-fab";
  fab.innerHTML = `
    <svg class="fab-icon" viewBox="0 0 24 24">
      <path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z"/>
    </svg>
    <span class="fab-tooltip">Create Topic</span>
  `;
  
  fab.addEventListener("click", () => {
    const createBtn = document.querySelector("#create-topic");
    if (createBtn) {
      createBtn.click();
    } else {
      window.location.href = "/new-topic";
    }
  });
  
  document.body.appendChild(fab);
}

function createActivityWidget() {
  // Check if already exists
  if (document.querySelector(".robotime-activity-widget")) {
    return;
  }
  
  const widget = document.createElement("div");
  widget.className = "robotime-activity-widget";
  widget.innerHTML = `
    <div class="widget-header">
      <svg viewBox="0 0 24 24">
        <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
      </svg>
      Events
    </div>
    <div class="carousel">
      <div class="slide active">
        <div style="width:100%;height:100%;background:linear-gradient(135deg,#228B22,#32CD32);display:flex;align-items:center;justify-content:center;color:#fff;font-size:14px;">Event Banner 1</div>
      </div>
      <div class="slide">
        <div style="width:100%;height:100%;background:linear-gradient(135deg,#1E90FF,#00BFFF);display:flex;align-items:center;justify-content:center;color:#fff;font-size:14px;">Event Banner 2</div>
      </div>
      <div class="dots">
        <button class="dot active" data-index="0"></button>
        <button class="dot" data-index="1"></button>
      </div>
    </div>
    <a href="/latest" class="widget-link">View All Events</a>
  `;
  
  document.body.appendChild(widget);
  
  // Carousel logic
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
  const widget = document.querySelector(".robotime-activity-widget");
  const fab = document.querySelector(".robotime-fab");
  
  if (window.innerWidth <= 768) {
    if (widget) widget.style.display = "none";
    if (fab) fab.style.display = "none";
  } else {
    if (widget) widget.style.display = "block";
    const currentUser = document.querySelector(".header-dropdown-toggle.current-user");
    if (fab && currentUser) fab.style.display = "flex";
  }
});
