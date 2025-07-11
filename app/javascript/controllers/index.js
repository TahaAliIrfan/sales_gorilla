// Import and register all your controllers from the importmap under controllers/*

import { application } from "controllers/application"

// Eager load all controllers defined in the import map under controllers/**/*_controller
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)

// Lazy load controllers as they appear in the DOM (remember to delete this file if you've generated it)
import CallingController from "./calling_controller"
application.register("calling", CallingController)

import CommunicationStatusController from "./communication_status_controller"
application.register("communication-status", CommunicationStatusController)

import CountryController from "./country_controller"
application.register("country", CountryController)

import CustomerFilterController from "./customer_filter_controller"
application.register("customer-filter", CustomerFilterController)

import LeadSourceController from "./lead_source_controller"
application.register("lead-source", LeadSourceController)

import DragController from "./drag_controller"
application.register("drag", DragController)

import PhoneModalController from "./phone_modal_controller"
application.register("phone-modal", PhoneModalController)

import CustomerNavigationController from "./customer_navigation_controller"
application.register("customer-navigation", CustomerNavigationController)

import FollowupModalController from "./followup_modal_controller"
application.register("followup-modal", FollowupModalController)

import BulkAssignController from "./bulk_assign_controller"
application.register("bulk-assign", BulkAssignController)

import WhatsappChatController from "./whatsapp_chat_controller"
application.register("whatsapp-chat", WhatsappChatController)

import DropdownController from "./dropdown_controller"
application.register("dropdown", DropdownController)

import CustomerDocumentsController from "./customer_documents_controller"
application.register("customer-documents", CustomerDocumentsController)
