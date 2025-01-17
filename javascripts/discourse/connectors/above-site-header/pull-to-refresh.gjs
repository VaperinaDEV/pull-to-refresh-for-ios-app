import Component from "@glimmer/component";
import { service } from "@ember/service";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import discourseLater from "discourse/lib/later";
import { htmlSafe } from "@ember/template";
import concatClass from "discourse/helpers/concat-class";

export default class PwaPullToRefresh extends Component {
  @service capabilities;
  @service router;

  @tracked isPulling = false;
  @tracked startY = 0;
  @tracked currentY = 0;
  @tracked pullDistance = 0;
  @tracked isRefreshing = false;
  @tracked pullProgress = 0;
  @tracked highlightPosition = 0;
  @tracked isReloading = false;
  
  LINE_COUNT = 8;
  THRESHOLD = 100;
  MAX_PULL = 150;
  mainOutlet = null;

  get shouldShow() {
    const isChat = this.router.currentRouteName.startsWith("chat");
    const isAppWebview = this.capabilities.isAppWebview;
    const isiOSPWA = this.capabilities.isiOSPWA;

    return !isChat && (isAppWebview || isiOSPWA);
  }

  get spinnerSvg() {
    const lines = Array.from({ length: this.LINE_COUNT }, (_, index) => {
      const baseRotation = (index * 360) / this.LINE_COUNT;
      let opacity = 0;
      
      if (this.isRefreshing) {
        opacity = 0.85;
      } else {
        opacity = Math.max(0, Math.min(1, (this.pullProgress * 2) - (index / this.LINE_COUNT)));
      }

      return `<line
        x1="32"
        y1="14"
        x2="32"
        y2="22"
        stroke="${settings.spinner_color}"
        stroke-width="5"
        stroke-linecap="round"
        style="transform: rotate(${baseRotation}deg); opacity: ${opacity.toFixed(2)}; transform-origin: center;"
        class="spinner-line"
      />`;
    }).join('');

    return htmlSafe(`
      <svg
        viewBox="0 0 64 64"
        class="safari-spinner ${this.isRefreshing ? 'spinning' : ''}"
      >
        ${lines}
      </svg>
    `);
  }

  @action
  startAnimation() {
    const spinner = document.querySelector(".safari-spinner");
    if (spinner) {
      spinner.classList.add("spinning");
    }
  }

  @action
  stopAnimation() {
    const spinner = document.querySelector(".safari-spinner");
    if (spinner) {
      spinner.classList.remove("spinning");
    }
  }

  constructor() {
    super(...arguments);
    if (this.shouldShow) {
      this.setupListeners();
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);
    if (this.shouldShow) {
      this.removeListeners();
      this.stopAnimation();
    }
  }

  @action
  setupListeners() {
    const attemptSetup = () => {
      this.mainOutlet = document.querySelector("#main-outlet");
      if (this.mainOutlet) {
        this.mainOutlet.addEventListener(
          "touchstart",
          this.handleTouchStart.bind(this),
          { passive: true }
        );
        this.mainOutlet.addEventListener(
          "touchmove",
          this.handleTouchMove.bind(this),
          { passive: false }
        );
        this.mainOutlet.addEventListener(
          "touchend",
          this.handleTouchEnd.bind(this),
          { passive: true }
        );
      } else {
        discourseLater(attemptSetup, 100);
      }
    };
  
    attemptSetup();
  }

  @action
  removeListeners() {
    if (this.mainOutlet) {
      this.mainOutlet.removeEventListener(
        "touchstart",
        this.handleTouchStart.bind(this)
      );
      this.mainOutlet.removeEventListener(
        "touchmove",
        this.handleTouchMove.bind(this)
      );
      this.mainOutlet.removeEventListener(
        "touchend",
        this.handleTouchEnd.bind(this)
      );
    }
  }

  isMainOutletTouch(event) {
    let element = event.target;
    while (element) {
      if (element.id === "main-outlet") {
        return true;
      }
      element = element.parentElement;
    }
    return false;
  }

  @action
  handleTouchStart(event) {
    if (!this.shouldShow || !this.isMainOutletTouch(event)) {
      return;
    }
    
    if (window.scrollY === 0) {
      this.startY = event.touches[0].clientY;
      this.currentY = event.touches[0].clientY;
      this.isPulling = true;
      this.pullDistance = 0;
      this.pullProgress = 0;
      this.highlightPosition = 0;
      this.isReloading = false;
    }
  }

  @action
  handleTouchMove(event) {
    if (
      !this.shouldShow ||
      !this.isPulling ||
      !this.isMainOutletTouch(event) ||
      window.scrollY > 0
    ) {
      return;
    }
  
    this.currentY = event.touches[0].clientY;
    const delta = this.currentY - this.startY;
  
    if (delta > 0) {
      const damping = 0.5;
      this.pullDistance = Math.min(delta * damping, this.MAX_PULL);
      this.pullProgress = Math.min(this.pullDistance / this.THRESHOLD, 1);
  
      const loader = document.querySelector(".pwa-pull-loader");
  
      if (loader) {
        loader.style.opacity = "1";
  
        if (this.pullDistance >= this.THRESHOLD) {
          loader.classList.add("ready");
  
          if (!this.isRefreshing) {
            this.isRefreshing = true;
            this.startAnimation();
          }
        } else {
          loader.classList.remove("ready");
        }
      }
    }
  }
  
  @action
  handleTouchEnd(event) {
    if (
      !this.shouldShow ||
      !this.isPulling ||
      !this.isMainOutletTouch(event)
    ) {
      return;
    }
    
    const loader = document.querySelector(".pwa-pull-loader");
    
    if (this.pullDistance >= this.THRESHOLD) {
      this.isRefreshing = true;
      this.isReloading = true;
      
      if (loader) {
        loader.classList.add("loading");
      }
            
      discourseLater(() => {
        window.location.reload();
      }, 1000);
    } else {
      this.isRefreshing = false;
      this.isReloading = false;
      this.stopAnimation();
      
      if (loader) {
        loader.style.opacity = "0";
        loader.classList.remove("ready", "loading");
      }
    }
    
    this.isPulling = false;
    this.pullDistance = 0;
  }

  <template>
    {{#if this.shouldShow}}
      <div class="pwa-pull-loader">
        <div class={{concatClass "pwa-loader-content" (if this.isPulling "is-pulling")}}>
          {{{this.spinnerSvg}}}
        </div>
      </div>
    {{/if}}
  </template>
}
