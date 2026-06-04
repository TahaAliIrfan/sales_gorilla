// Auto-discovers and registers every `*_controller.js` file in this directory.
// Adding a new controller file is enough — no manual registration required.
// This kills the silent failure mode where forgetting to register a controller
// makes its data-action / data-target attributes do nothing at runtime.
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"

eagerLoadControllersFrom("controllers", application)
