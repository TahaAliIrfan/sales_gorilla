# WhatsApp US — Mobile Integration Guide

Reference for the iOS/Android client integrating the Twilio-backed "WhatsApp US" channel.

- **API base:** `https://crm.tecaudex.com`
- **WebSocket base:** `wss://crm.tecaudex.com/cable`
- **Auth:** JWT (Bearer for REST, `?token=` query string for WebSocket)
- **Sender (from-number, fixed):** `whatsapp:+13022067878`

---

## 1. Authentication

Get a JWT with the existing login endpoint:

```http
POST /api/v2/auth/login
Content-Type: application/json

{ "email": "user@example.com", "password": "..." }
```

Response includes `token`. Use it for everything below:

```http
Authorization: Bearer <JWT>
```

### Register an FCM token (for inbound push notifications)

The server pushes `"<customer name> has sent you a message"` to the assigned user via Firebase whenever an inbound WhatsApp message lands. Register the device on login (and on token refresh):

```http
PATCH /api/v2/users/:id/update_fcm_token
Authorization: Bearer <JWT>
Content-Type: application/json

{ "fcm_token": "<FCM registration token>" }
```

The push payload includes a `data` block:

```json
{ "type": "whatsapp_us_message", "customer_id": "1837", "message_id": "999" }
```

Use those fields to deep-link into the conversation.

---

## 2. REST endpoints

All require `Authorization: Bearer <JWT>`. Responses follow the standard envelope:

```json
{ "success": true, "message": "...", "data": { ... } }
```

Errors return `{ "success": false, "error": "..." }` with an appropriate HTTP status.

### 2.1 List conversations

```http
GET /api/v2/whatsapp_us/conversations[?page=1&per_page=20]
```

Returns customers (role-scoped — admin sees all, manager sees self + associates, others see their own) who have at least one WhatsApp message. Ordered by most recent activity.

```jsonc
{
  "data": {
    "conversations": [
      {
        "customer": { "id": 1837, "name": "Jane Doe", "phone": "+923004363534", "assigned_user_id": 1, "whatsapp_status": "Connected" },
        "last_message": { "id": 999, "body": "Hi", "direction": "inbound", "status": "received", "timestamp": "2026-06-03T10:00:00Z", "media_url": null, "media_filename": null, "media_content_type": null, "template_sid": null, "template_name": null },
        "last_message_at": "2026-06-03T10:00:00Z",
        "window_open": true,
        "unread": 2
      }
    ],
    "pagination": { "page": 1, "per_page": 20, "total": 57, "total_pages": 3 } // null when per_page omitted
  }
}
```

`pagination` is `null` if no `per_page` was sent; otherwise it's populated. Both endpoints follow this rule.

### 2.2 Fetch a conversation's messages

```http
GET /api/v2/whatsapp_us/customers/:customer_id/messages
        [?after_id=N][&page=1&per_page=50]
```

- `after_id=N` — delta fetch: only messages with `id > N`. Use this after a reconnect, or after merging WebSocket pushes that came in while you were loading initial state.
- `per_page`+`page` — opt-in pagination.

```jsonc
{
  "data": {
    "customer":         { "id": 1837, "name": "Jane Doe", ... },
    "window_open":      true,
    "last_inbound_at":  "2026-06-03T10:00:00Z",
    "messages":         [ /* see "Message shape" below */ ],
    "pagination":       null
  }
}
```

### 2.3 Cross-conversation delta (catch-up after reconnect)

```http
GET /api/v2/whatsapp_us/latest[?after_id=N]
```

Returns every message — any direction, any visible customer — with `id > after_id`. If `after_id` is omitted, returns the most recent 50.

```jsonc
{
  "data": {
    "messages":  [ /* Message shape */ ],
    "latest_id": 1023   // pass this as after_id next time
  }
}
```

**Typical reconnect flow:** persist `latest_id` after each batch; on reconnect, call `/latest?after_id=<latest_id>` once before re-subscribing to the WebSocket.

### 2.4 Send a message (text, document, image, or voice note)

```http
POST /api/v2/whatsapp_us/customers/:customer_id/send
Authorization: Bearer <JWT>
Content-Type: multipart/form-data

body=Hello%20there      # optional text body / caption
file=@/path/to/file     # optional upload — any allowed MIME (see §5)
```

Either `body` or `file` is required; both can be sent together (file with caption).

- Audio uploads (`audio/webm`, `audio/x-m4a`, `audio/mp4`, ...) are accepted directly. The server transcodes formats Twilio doesn't natively accept (mainly Chrome's `audio/webm`) to `audio/ogg` opus.
- Document/image/audio is uploaded to S3, Twilio fetches it, and the message is persisted with the same blob attached so the client can render it back.
- The server enforces the **24-hour reply window**. If the customer hasn't messaged the business in the last 24h, you'll get a `403`:

```json
{ "success": false,
  "error": "The 24-hour reply window has closed. The customer must message first, or use an approved template." }
```

When the window is closed, use the **template send** path instead (§2.5).

Success:

```json
{ "data": { "message": { /* Message shape */ } } }
```

### 2.5 Send an approved template (works outside the 24h window)

```http
GET /api/v2/whatsapp_us/templates     # list approved templates
POST /api/v2/whatsapp_us/templates/sync   # ADMIN ONLY — pull fresh from Twilio
```

```jsonc
// GET /templates response
{ "data": { "templates": [
  { "content_sid":   "HXcd24...",
    "friendly_name": "tecaudex_greeting",
    "language":      "en_US",
    "category":      "MARKETING",
    "body":          "Hi {{customer_name}},\nGreat to connect with you! I'm {{sales_agent_name}}...",
    "variable_keys": ["customer_name", "sales_agent_name"],
    "last_synced_at": "2026-06-03T09:00:00Z"
  }
] } }
```

To send:

```http
POST /api/v2/whatsapp_us/customers/:customer_id/send_template
Content-Type: application/json

{
  "content_sid": "HXcd24...",
  "variables":   { "customer_name": "Taha", "sales_agent_name": "Hina" }
}
```

Returns `{ "data": { "message": {...} } }` on success.

### 2.6 Mark a conversation as read

```http
POST /api/v2/whatsapp_us/customers/:customer_id/mark_read
Content-Type: application/json

{ "up_to_message_id": 999 }     // optional — mark up to (and including) this id
// OR { "up_to_timestamp": "2026-06-03T10:00:00Z" }
// OR {} to mark everything
```

```json
{ "data": { "marked": 3, "remaining_unread": 0 } }
```

Clears the `unread` counter the `conversations` endpoint returns.

---

## 3. Message shape (common across endpoints + WebSocket)

```jsonc
{
  "id":                 999,                              // primary key — use as cursor
  "message_id":         "MMab3f...",                     // Twilio SID (SM for SMS, MM for media)
  "body":               "Hello",                          // text or caption; may be null when media-only
  "direction":          "inbound" | "outbound",
  "status":             "received" | "queued" | "sent" | "delivered" | "read" | "failed" | "undelivered",
  "timestamp":          "2026-06-03T10:00:00Z",
  "media_url":          "/rails/active_storage/blobs/redirect/...",   // relative path; prefix with API base
  "media_filename":     "voice-note.ogg",
  "media_content_type": "audio/ogg",
  "template_sid":       "HXcd24...",   // only set for outbound template sends
  "template_name":      "tecaudex_greeting"
}
```

`media_url` is a relative path — concatenate with the API base. The endpoint 302s to a signed S3 URL on demand; honor the redirect (most HTTP clients do this by default).

---

## 4. Real-time via WebSocket (ActionCable)

The same JWT authenticates the WebSocket. Open:

```
wss://crm.tecaudex.com/cable?token=<JWT>
```

The server speaks the standard ActionCable JSON protocol.

### Handshake

After the socket opens, send the subscribe frame. There are two streams you can join:

**A) User-wide stream** — every new message touching any customer this user can see (good for the conversations-list screen):

```json
{ "command": "subscribe",
  "identifier": "{\"channel\":\"WhatsappUsChannel\"}" }
```

**B) Per-customer stream** — open this in addition while a chat is on-screen:

```json
{ "command": "subscribe",
  "identifier": "{\"channel\":\"WhatsappUsChannel\",\"customer_id\":1837}" }
```

You can subscribe to both at once; broadcasts hit both streams independently. Unsubscribe from the per-customer one when leaving the chat:

```json
{ "command": "unsubscribe",
  "identifier": "{\"channel\":\"WhatsappUsChannel\",\"customer_id\":1837}" }
```

### Broadcast payload

```jsonc
{
  "identifier": "{\"channel\":\"WhatsappUsChannel\",\"customer_id\":1837}",
  "message": {
    "type":        "whatsapp_us.message",
    "direction":   "inbound",          // or "outbound"
    "customer_id": 1837,
    "message":     { /* Message shape, same as REST */ }
  }
}
```

Broadcasts fire for both **inbound** (received via Twilio webhook) and **outbound** (sent from any surface — web, this app, or a second device). That lets multi-device users see what they themselves sent on another device.

### Keep-alive / reconnect strategy

ActionCable sends `{ "type": "ping" }` frames every ~3s. If your client doesn't see one for ~10s, treat the socket as dead and reconnect.

**On reconnect**:
1. Remember the highest `message.id` you've rendered (call it `last_id`).
2. Call `GET /api/v2/whatsapp_us/latest?after_id=<last_id>` to catch up anything you missed during the gap.
3. Resubscribe to the WebSocket.

This pattern is correctness-safe regardless of how long the disconnect lasted.

---

## 5. Supported upload MIME types

Sent via `POST /send` as `multipart/form-data`. The server transcodes audio to a Twilio-compatible format when needed; everything else passes through.

| Group     | Accepted MIMEs |
|-----------|----------------|
| Image     | `image/jpeg`, `image/jpg`, `image/png`, `image/gif`, `image/webp` |
| Video     | `video/mp4`, `video/3gp`, `video/webm` |
| Audio     | `audio/mpeg`, `audio/mp3`, `audio/ogg`, `audio/wav`, `audio/m4a`, `audio/x-m4a`, `audio/flac`, `audio/webm`, `audio/aac`, `audio/mp4`, `audio/amr`, `audio/3gpp` |
| Documents | `application/pdf`, MS Word (`.doc`, `.docx`), MS Excel (`.xls`, `.xlsx`), PowerPoint (`.pptx`), `text/plain`, `text/csv`, `application/json`, `application/xml`, `application/zip` |

**Size cap:** 16 MB (mirrors WhatsApp's own limit).

For voice notes specifically: just record with `AVAudioRecorder` (iOS — `.m4a`/`audio/mp4` works) or `MediaRecorder` (Android — `audio/mp4` or `audio/aac`) and POST as `file`. No client-side transcoding needed.

---

## 6. Recommended client architecture

1. **On login:** persist JWT, call `update_fcm_token`.
2. **On conversations screen:**
   - Hit `GET /conversations` (paginated).
   - Open WebSocket, subscribe to `WhatsappUsChannel` (no `customer_id`).
   - On each broadcast → bump the matching row to the top, refresh `unread`, `last_message`.
3. **On entering a chat:**
   - Hit `GET /customers/:id/messages` (paginated, newest page first by inverting client-side, or paginate forward and reverse).
   - Subscribe to `WhatsappUsChannel` with `customer_id` (in addition to the user-wide one).
   - Track `last_id` = max id seen.
4. **On sending:** `POST /send` (or `/send_template`). The reply contains the persisted message — also expect to see the same message via WebSocket broadcast a moment later; dedupe by `id`.
5. **On leaving a chat:** unsubscribe from the customer stream; call `POST /mark_read` with `up_to_message_id: last_id`.
6. **On reconnect / app foreground:**
   - `GET /latest?after_id=<last_id>` to catch the gap.
   - Re-open WebSocket if it dropped.
7. **On background push (FCM):** `data.customer_id` deep-links to that chat.

---

## 7. Error responses

Standard envelope:

```jsonc
{ "success": false,
  "error":   "human-readable message",
  "details": [ ... ]   // optional, e.g. validation errors
}
```

| HTTP | Meaning |
|------|---------|
| 401  | JWT missing/expired/invalid — re-login |
| 403  | Window closed, admin-only endpoint, or not allowed to access this customer |
| 404  | Customer or template not found (or not accessible) |
| 422  | Validation failed (file too large, unsupported MIME, blank body+file, etc.) |
| 503  | Upstream Twilio failure |

---

## 8. Quick test cURL snippets

```bash
TOKEN="<paste JWT>"
HOST="https://crm.tecaudex.com"

# Conversations
curl -H "Authorization: Bearer $TOKEN" "$HOST/api/v2/whatsapp_us/conversations?per_page=20"

# Messages for one conversation, only what's new since id 999
curl -H "Authorization: Bearer $TOKEN" \
     "$HOST/api/v2/whatsapp_us/customers/1837/messages?after_id=999"

# Send text
curl -X POST -H "Authorization: Bearer $TOKEN" \
     -F "body=Hello from cURL" \
     "$HOST/api/v2/whatsapp_us/customers/1837/send"

# Send voice note
curl -X POST -H "Authorization: Bearer $TOKEN" \
     -F "file=@voice-note.m4a;type=audio/mp4" \
     "$HOST/api/v2/whatsapp_us/customers/1837/send"

# Send template
curl -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
     -d '{"content_sid":"HXcd24...","variables":{"customer_name":"Taha","sales_agent_name":"Hina"}}' \
     "$HOST/api/v2/whatsapp_us/customers/1837/send_template"

# Mark read
curl -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
     -d '{"up_to_message_id":999}' \
     "$HOST/api/v2/whatsapp_us/customers/1837/mark_read"
```
