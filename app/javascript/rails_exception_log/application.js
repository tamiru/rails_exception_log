import { Application } from "@hotwired/stimulus"

import RailsExceptionLogController from "rails_exception_log/controllers/rails_exception_log"
import RailsExceptionLogDetailController from "rails_exception_log/controllers/rails_exception_log_detail"
import RailsExceptionLogSidebarController from "rails_exception_log/controllers/rails_exception_log_sidebar"
import RailsExceptionLogThemeController from "rails_exception_log/controllers/rails_exception_log_theme"

async function ensureTurbo() {
  if (window.Turbo) return

  const module = await import("@hotwired/turbo-rails")
  window.Turbo = module.Turbo
}

// Reuse an explicitly exposed host Stimulus application when possible. If the
// host keeps it module-local, create one namespaced engine application only.
const application = window.Stimulus?.register
  ? window.Stimulus
  : (window.RailsExceptionLogStimulus ||= Application.start())

application.debug = false

// Register engine controllers
application.register("rails_exception_log", RailsExceptionLogController)
application.register("rails_exception_log-theme", RailsExceptionLogThemeController)
application.register("rails_exception_log-sidebar", RailsExceptionLogSidebarController)
application.register("rails_exception_log-detail", RailsExceptionLogDetailController)

ensureTurbo()
