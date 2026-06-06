import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["header", "body"]

    connect() {
        this.syncLayout = this.syncLayout.bind(this)

        this.resizeObserver = new ResizeObserver(this.syncLayout)
        this.resizeObserver.observe(this.headerTarget)

        window.addEventListener("resize", this.syncLayout)
        this.syncLayout()
    }

    disconnect() {
        this.resizeObserver?.disconnect()
        window.removeEventListener("resize", this.syncLayout)
    }

    syncLayout() {
        const headerHeight = Math.ceil(this.headerTarget.getBoundingClientRect().height)
        this.bodyTarget.style.paddingTop = `${headerHeight}px`
    }
}
