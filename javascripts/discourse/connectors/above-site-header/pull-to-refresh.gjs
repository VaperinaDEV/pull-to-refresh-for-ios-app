import Component from "@glimmer/component";
import { service } from "@ember/service";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import discourseLater from "discourse-common/lib/later";

export default class PwaPullToRefresh extends Component {
  @service capabilities;
  @service router;

  @tracked isPulling = false;
  @tracked startY = 0;
  @tracked currentY = 0;
  @tracked pullDistance = 0;
  
  THRESHOLD = 100;
  MAX_PULL = 150;
  mainOutlet = null;

  get shouldShow() {
    const isChat = this.router.currentRouteName.startsWith("chat");
    const isAppWebview = this.capabilities.isAppWebview;
    const isiOSPWA = this.capabilities.isiOSPWA;

    return !isChat && (isAppWebview || isiOSPWA);
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
      this.isPulling = true;
      this.pullDistance = 0;
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
      
      const loader = document.querySelector(".pwa-pull-loader");
      
      if (loader) {
        loader.style.opacity = "1";
        
        if (this.pullDistance >= this.THRESHOLD) {
          loader.classList.add("ready");
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
      if (loader) {
        loader.classList.add("loading");
      }
      
      discourseLater(() => {
        window.location.reload();
      }, 1000);
    } else {
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
        <div class="pwa-loader-content">
          <div class="pwa-loader-spinner"></div>
          <div class="pwa-loader-arrow"></div>
        </div>
      </div>
    {{/if}}
  </template>
}
