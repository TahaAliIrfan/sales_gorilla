# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Starting the Application
- `bin/dev` - Starts Rails server, Tailwind CSS compilation, and Sidekiq worker (recommended for development)
- `bin/rails server` - Rails server only
- `bundle exec sidekiq -C config/sidekiq.yml` - Start Sidekiq manually

### Database Operations
- `rails db:create db:migrate` - Initial database setup
- `rails db:migrate` - Run pending migrations
- `rails db:rollback` - Revert last migration

### Asset Compilation
- `bin/rails tailwindcss:watch` - Watch and compile Tailwind CSS (runs automatically with `bin/dev`)

### Background Jobs
- Sidekiq dashboard: Visit `/sidekiq` (admin access required)
- Configuration: `config/sidekiq.yml` and `config/sidekiq_scheduler.yml`

### Rake Tasks
- `rails customers:add_whatsapp_chat_ids` - Add WhatsApp chat IDs to all customers
- `rails customers:sync_missing_whatsapp_chat_ids` - Sync missing WhatsApp chat IDs only
- Various S3 and recording management tasks in `lib/tasks/`

## Architecture Overview

### Core Models and Relationships
- **User**: Central model with role-based permissions (admin, manager, associate)
  - Hierarchical role system through `RoleAssignment` model
  - Google Calendar integration via OAuth
  - Phone number validation and timezone handling
- **Customer**: Main business entity with comprehensive lead management
  - Multiple communication channels (phone, email, WhatsApp, LinkedIn)
  - Document attachments via Active Storage
  - Timezone and calling time intelligence
  - Activity tracking and user assignment workflows
- **Deal**: Sales pipeline management with stages and recordings
- **Task**: User assignments with priorities and due dates
- **Recording**: Call recordings with AI transcription and analysis

### Authentication & Authorization
- Google OAuth2 via OmniAuth for authentication
- Pundit for policy-based authorization
- Role hierarchy: Admin > Manager > Associate
- Managers can oversee their assigned associates

### Background Processing
- Sidekiq with multiple queues for different job types:
  - `notifications` - User notifications and emails
  - `recordings` - Audio processing and storage
  - `emails` - Gmail integration and fetching
  - `whatsapp_analysis` - Message analysis
  - `followups` - Customer follow-up scheduling
- Scheduled jobs for daily task reminders

### External Integrations
- **Google Services**: Calendar, Gmail (via google-api-client)
- **AWS S3**: Document and recording storage
- **Twilio**: Browser-based calling functionality
- **WhatsApp API**: Message retrieval and analysis
- **Gemini AI**: Customer phone analysis and content analysis

### Key Features
- **Multi-channel CRM**: Manage customers across phone, email, WhatsApp, LinkedIn
- **Call Center**: Browser-based calling with recording and transcription
- **Role-based Access**: Hierarchical user management with associate assignments
- **AI Integration**: Automated phone number analysis and conversation insights
- **Document Management**: Customer document uploads with validation
- **Time Zone Intelligence**: Automatic timezone detection and preferred calling times

### Frontend Stack
- **Hotwire**: Turbo + Stimulus for SPA-like experience
- **Tailwind CSS**: Utility-first styling
- **JavaScript Controllers**: Stimulus controllers for interactive features
- **Sortable.js**: Drag-and-drop functionality

### Database
- PostgreSQL as primary database
- Redis for Sidekiq job queues and session storage

### File Structure Patterns
- Controllers follow RESTful conventions with additional member/collection routes
- Policies in `app/policies/` for authorization logic
- Services in `app/services/` for complex business logic
- Workers in `app/workers/` for background job processing
- Stimulus controllers in `app/javascript/controllers/`

### Testing Approach
No specific test framework configured. When adding tests, check project preferences first.

### Development Notes
- Use `bin/dev` for development to ensure all services start together
- Sidekiq web UI available at `/sidekiq` for job monitoring
- Google Calendar integration requires OAuth setup in settings
- WhatsApp integration requires API credentials configuration
- Customer phone analysis happens automatically via background jobs
- Document uploads support PDF, Word, Excel, CSV, and image formats (max 10MB)