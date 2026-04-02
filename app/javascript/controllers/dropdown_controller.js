import { Controller } from "@hotwired/stimulus"

export default class DropdownController extends Controller {
  static targets = ["menu"]

  connect() {
    this.isOpen = false
  }

  toggle(event) {
    event.preventDefault()
    this.isOpen = !this.isOpen
    this.menuTarget.classList.toggle("hidden", !this.isOpen)
  }

  close(event) {
    if (!this.element.contains(event.target)) {
      this.isOpen = false
      this.menuTarget.classList.add("hidden")
    }
  }
}