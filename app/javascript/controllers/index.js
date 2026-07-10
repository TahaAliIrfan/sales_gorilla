// Import and register all your controllers from the importmap under controllers/*

import { application } from "controllers/application"

// Explicitly import and register all controllers for reliable loading in production
import AudioPlayerController from "./audio_player_controller"
application.register("audio-player", AudioPlayerController)

import BulkAssignController from "./bulk_assign_controller"
application.register("bulk-assign", BulkAssignController)

import CallingController from "./calling_controller"
application.register("calling", CallingController)

import CampaignCustomerSelectorController from "./campaign_customer_selector_controller"
application.register("campaign-customer-selector", CampaignCustomerSelectorController)

import ChatController from "./chat_controller"
application.register("chat", ChatController)

import WhatsappUsController from "./whatsapp_us_controller"
application.register("whatsapp-us", WhatsappUsController)

import CommunicationStatusController from "./communication_status_controller"
application.register("communication-status", CommunicationStatusController)

import CostCalculatorController from "./cost_calculator_controller"
application.register("cost-calculator", CostCalculatorController)

import OdooCalculatorController from "./odoo_calculator_controller"
application.register("odoo-calculator", OdooCalculatorController)

import CountryController from "./country_controller"
application.register("country", CountryController)

import CustomerDocumentsController from "./customer_documents_controller"
application.register("customer-documents", CustomerDocumentsController)

import CustomerFilterController from "./customer_filter_controller"
application.register("customer-filter", CustomerFilterController)

import SplitViewController from "./split_view_controller"
application.register("split-view", SplitViewController)

import CallWidgetController from "./call_widget_controller"
application.register("call-widget", CallWidgetController)

import LeadScoreController from "./lead_score_controller"
application.register("lead-score", LeadScoreController)

import CustomerNavigationController from "./customer_navigation_controller"
application.register("customer-navigation", CustomerNavigationController)

import DealDescriptionEditorController from "./deal_description_editor_controller"
application.register("deal-description-editor", DealDescriptionEditorController)

import DocumentDeleteController from "./document_delete_controller"
application.register("document-delete", DocumentDeleteController)

import DocumentManagerController from "./document_manager_controller"
application.register("document-manager", DocumentManagerController)

import DragController from "./drag_controller"
application.register("drag", DragController)

import DropdownController from "./dropdown_controller"
application.register("dropdown", DropdownController)

import EmailComposerController from "./email_composer_controller"
application.register("email-composer", EmailComposerController)

import EmailInboxController from "./email_inbox_controller"
application.register("email-inbox", EmailInboxController)

import EmailModalController from "./email_modal_controller"
application.register("email-modal", EmailModalController)

import FollowupModalController from "./followup_modal_controller"
application.register("followup-modal", FollowupModalController)

import HelloController from "./hello_controller"
application.register("hello", HelloController)

import LeadQualityController from "./lead_quality_controller"
application.register("lead-quality", LeadQualityController)

import LeadSourceController from "./lead_source_controller"
application.register("lead-source", LeadSourceController)

import MessageTemplateController from "./message_template_controller"
application.register("message-template", MessageTemplateController)

import MobileMenuController from "./mobile_menu_controller"
application.register("mobile-menu", MobileMenuController)

import ModalController from "./modal_controller"
application.register("modal", ModalController)

import MultiselectDropdownController from "./multiselect_dropdown_controller"
application.register("multiselect-dropdown", MultiselectDropdownController)

import NotesEditorController from "./notes_editor_controller"
application.register("notes-editor", NotesEditorController)

import PageTranscriptController from "./page_transcript_controller"
application.register("page-transcript", PageTranscriptController)

import PhoneModalController from "./phone_modal_controller"
application.register("phone-modal", PhoneModalController)

import RecordingController from "./recording_controller"
application.register("recording", RecordingController)

import RecordingPlayerController from "./recording_player_controller"
application.register("recording-player", RecordingPlayerController)

import StatusUpdaterController from "./status_updater_controller"
application.register("status-updater", StatusUpdaterController)

import TabsController from "./tabs_controller"
application.register("tabs", TabsController)

import TeamManagementController from "./team_management_controller"
application.register("team-management", TeamManagementController)

import TranscriptController from "./transcript_controller"
application.register("transcript", TranscriptController)

import TranscriptModalController from "./transcript_modal_controller"
application.register("transcript-modal", TranscriptModalController)

import NestedFormController from "./nested_form_controller"
application.register("nested-form", NestedFormController)
