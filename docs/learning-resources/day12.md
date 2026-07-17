# Day 12: AI Trust & Safety & Twilio Proxy Communication

> [!WARNING]
> **Status: OUTSTANDING (Future Phase)**

---

## 1. Architectural Rationale: Why We Do This
Marketplace platforms must prevent disintermediation (transactions moving off-platform) to secure fee revenue and protect users from fraudulent schemes.
* **AI-Assisted Content Moderation**: Scanning and analyzing message content dynamically to assign risk scores to phone numbers, emails, social accounts, and alternative billing platform terms.
* **Anonymized Twilio Proxy**: Routing calls and SMS communications through masked virtual intermediaries so users never disclose their personal contact numbers.

---

## 2. Core Tasks

### A. SQLite Moderation Events Table
Create a migration script adding `moderation_events` to store flagged events:
```sql
CREATE TABLE IF NOT EXISTS moderation_events (
  id TEXT PRIMARY KEY,
  booking_id TEXT,
  chat_message_id TEXT,
  offender_id TEXT NOT NULL,
  risk_score REAL NOT NULL, -- 0.0 to 1.0 range
  flagged_terms TEXT,       -- JSON array of keywords matched
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

### B. Upgrade Leakage Detection & Moderation
Refactor `src/lib/leakage-scanner.ts` and `/api/agent/chat` route:
* Expose risk scoring configurations in the AI concierge system instruction.
* If user messages exceed a risk score of `0.8` (e.g. sharing emails, alternative cash platforms), log the incident to `moderation_events`, block message dispatch, and prompt the client to complete bookings via standard platform checkout.

### C. Configure Twilio Number Proxy
Map virtual masking records to forward incoming traffic:
* Create a `phone_masks` table mapping connected user IDs to virtual Twilio numbers.
* Configure Twilio Studio voice and SMS webhooks to dynamically route calls/texts to the mapped recipient's private numbers.

---

## 3. Study & Reference Materials
* **AI-assisted Content Moderation Patterns**: Learn how to implement risk grading systems:  
  [https://cloud.google.com/natural-language/docs/moderating-text](https://cloud.google.com/natural-language/docs/moderating-text)
* **Twilio Proxy API and Masking**: Study number masking architectures:  
  [https://www.twilio.com/docs/proxy](https://www.twilio.com/docs/proxy)
