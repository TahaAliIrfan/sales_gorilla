// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)

// Import and register custom controllers
import DragController from "./drag_controller"
application.register("drag", DragController)

import CustomerFilterController from "./customer_filter_controller"
application.register("customer-filter", CustomerFilterController)

import CustomerNavigationController from "./customer_navigation_controller"
application.register("customer-navigation", CustomerNavigationController)

import LeadSourceController from "./lead_source_controller"
application.register("lead-source", LeadSourceController)

import CountryController from "./country_controller"
application.register("country", CountryController)
