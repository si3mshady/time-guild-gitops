# Day 9: Onboarding, Scheduling & Pricing Engine

---

## 1. Architectural Rationale: Why We Do This
A reliable marketplace platform requires structured availability slots and clear pricing definitions. The initial onboarding flow must support a creator's scheduling and pricing preferences rather than restricting them to single local slots.
* **Onboarding Availability Scheduler**: Instead of setting a single specific appointment, creators configure a date range (e.g. 90 days out), timezone, and weekly availability rules. A background generator programmatically generates available time slots in the database.
* **Flexible Pricing Models**: Assumptions of hourly rates multiply price by duration, creating data inconsistencies for flat-rate/session pricing. We must support both Flat Rate/Per-Session and Hourly pricing models and keep calculations consistent across checkouts, database records, and stripe payout transfers.

---

## 2. Core Tasks

### A. Database Schema Migrations
Add the following columns to the `creator_profiles` table in SQLite:
* `pricing_type`: TEXT CHECK(pricing_type IN ('flat', 'hourly')) NOT NULL DEFAULT 'flat'
* `session_name`: TEXT DEFAULT 'Consultation'
* `session_description`: TEXT

### B. Implement Availability Range Slot Generator
Create a slots generation utility function inside `src/lib/slots.ts` that:
* Accepts `startDate`, `endDate`, `daysOfWeek` (e.g. `[1, 2, 3, 4, 5]`), timezone, hours range (e.g. `09:00` to `17:00`), and `slotDurationMinutes` (e.g. `60`).
* Computes each slot boundary in the specified timezone and generates individual `slots` records in the database with status `available`.

### C. Redesign Onboarding UI
Refactor `src/app/onboarding/page.tsx`:
* Replace the single-slot start/end inputs with range selection fields: Date Range, Timezone, Active Days (checkboxes), and Business Hours (start/end select options).
* Add a pricing model toggle selector (Flat Rate vs. Hourly) and form fields to define the Flat Price/Session Description or Hourly Rate/Duration limits.

---

## 3. Study & Reference Materials
* **Date-fns Zone Calculations**: Learn how timezone conversions are calculated safely:  
  [https://date-fns.org/docs/Time-Zones](https://date-fns.org/docs/Time-Zones)
* **Structuring Availability in Calendars**: Study best practices for modeling calendar slots:  
  [https://schema.org/Schedule](https://schema.org/Schedule)
