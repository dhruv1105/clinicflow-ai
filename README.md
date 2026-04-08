# 🏥 ClinicFlow AI

AI-powered clinic management assistant built for **Google Cloud Gen AI Academy APAC 2026**

## What it does
- **Patient:** Book appointments, view history, receive prescription reminders via Telegram
- **Doctor:** Manage schedule, record patient sessions, upload prescriptions, trigger AI summarization

## Unique Capabilities
- 🎙️ Audio session recording → Gemini transcribes doctor-patient conversation
- 📋 Prescription photo → Gemini OCR → Telegram reminder to patient
- 🔄 Periodic session auto-scheduling (weekly physiotherapy, injections etc.)
- 📊 Disease trend analysis with AlloyDB AI vector search
- 🤖 Role-aware agent (same agent behaves differently for doctor vs patient)

## Tech Stack
- **Google ADK** — multi-agent framework
- **Gemini 2.5 Flash** — transcription, OCR, summarization
- **AlloyDB AI** — vector search on medical history
- **Google Cloud Storage** — audio and prescription files
- **Telegram Bot API** — patient notifications
- **Cloud Run** — serverless deployment

## Participant Details
- **Participant Name:** Dhruv Sindha — Solution Analyst, Argusoft
- **Problem Statement:** Multi-Agent Productivity Assistant — Build a multi-agent AI system that helps users manage tasks, schedules, and information by interacting with multiple tools and data sources.

## Brief About the Idea
ClinicFlow AI is an AI-powered clinic management assistant built on Google Cloud Gen AI stack. It serves as a one-stop platform for doctors and patients — enabling doctors to manage schedules, record patient sessions via audio, upload prescriptions for AI-powered OCR, and receive intelligent analytics; while patients can book appointments with nearby doctors, view their complete health history, and receive instant post-visit summaries on Telegram. The system uses a role-aware multi-agent architecture where the same ADK agent behaves completely differently based on whether a doctor or patient is logged in.

## Solution Explanation
**ADK Approach:** Single `root_agent` with dynamic instruction via `ReadonlyContext`. Role injected at login into shared in-memory state. Same agent, two completely different behaviours for doctor vs patient. All tools are Python functions registered directly on the agent.

**Real-World Problem:** Indian clinic management is fragmented — paper registers, WhatsApp reminders, manual prescriptions. ClinicFlow AI replaces all of it in one conversational interface: scheduling, audio recording, OCR, Telegram notifications, Calendar invites, and analytics.

**Core Workflow:** Patient books appointment → Calendar invite created → Doctor reviews patient history → Records audio + uploads prescription → Marks appointment complete → Gemini transcribes + generates clinical summary + OCRs prescription → Patient gets Telegram summary → Doctor views disease trends via AlloyDB AI.

## Opportunities / USP
1. **Role-aware agent:** Same ADK agent, two completely different behaviours — doctor vs patient — no separate deployments.
2. **Audio → diagnosis pipeline:** Gemini multimodal transcribes doctor-patient conversation → structured clinical summary automatically.
3. **Prescription OCR:** Gemini Vision extracts medicine list from photo → sent to patient via Telegram instantly.
4. **AlloyDB AI vector search:** `embedding()` SQL function for semantic search on medical history and disease trends.
5. **Location-aware doctor discovery:** Haversine distance SQL on AlloyDB → nearest doctors ranked by distance + rating + experience.
6. **Google Calendar auto-invite:** Every booking/reschedule creates/updates Calendar event with 1hr + 10min reminders.
7. **Priority booking:** High-priority cases auto-swap lower-priority slots.

*Existing tools handle one piece. ClinicFlow AI covers the entire clinical workflow end-to-end.*

## Features List

**Doctor Features:**
- Role-aware ADK agent shows today's schedule automatically on login
- View patient full history (diagnoses, medications, allergies) before session
- Session Panel UI: record audio in segments via browser MediaRecorder API
- Upload prescription photo — Gemini Vision OCR extracts medicine list
- Mark appointment complete → triggers full AI pipeline automatically
- Gemini 2.5 Flash multimodal transcription of doctor-patient audio
- AI-generated clinical summary: diagnosis, clinical notes, follow-up
- Disease trend analytics: top conditions this week/month via AlloyDB AI
- Periodic session scheduling: auto-create weekly physiotherapy or injection series
- Record payments (cash/UPI/card)
- Reschedule → Google Calendar event updated, patient notified

**Patient Features:**
- Book appointment with any registered doctor via natural conversation
- Find nearest doctors by location — ranked by distance + rating + experience
- Emergency button (tel:112) in session panel UI
- View complete medical history, past diagnoses, current medications
- Receive post-visit summary on Telegram (diagnosis + prescription + follow-up)
- Google Calendar invite on every booking with automatic reminders
- Check outstanding payment dues

## Process Flow
**Booking Flow:** Patient: "Book appointment with Dr. Arjun tomorrow at 11am" → `book_appointment()` checks slot → confirmed → `create_appointment_calendar_event()` → Google Calendar invite sent to both.

**Session Flow:** Doctor: "Start session for Rahul" → `get_session_panel_url()` returns link → Doctor opens `/session/3` → records audio + uploads prescription → clicks Mark Complete → API fires: `mark_appointment_complete()` + `summarize_appointment()` [GCS fetch → Gemini transcribe → clinical JSON → OCR → AlloyDB save → Telegram to patient].

**Nearby Doctors Flow:** Patient: "Find a cardiologist near me" → `find_nearby_doctors()` → Haversine SQL on AlloyDB → ranked list by distance + rating → patient selects → `book_appointment()`.

**Disease Trends Flow:** Doctor: "Show disease trends this week" → `get_disease_trends(days=7)` → AlloyDB `session_summaries` query → Gemini analysis → top conditions + age/gender patterns.

## Wireframes / Mock Diagrams
**Login Page:** Dark glassmorphism card on gradient background. Email + password fields. Two demo quick-fill buttons: Doctor (Dr. Arjun Sharma) and Patient (Rahul Mehta). Tech stack badges at bottom.

**ADK Dev UI — Doctor:** Agent greets "Good day Dr. Arjun Sharma! Let me show you today's schedule." and immediately lists appointments. Doctor types "Start session for Rahul" → agent replies with clickable `/session/3` link.

**Session Panel (`/session/{id}`):** Two-column layout. Left: patient details card with age, blood group, allergy badge (red), chronic condition badge (yellow), reason for visit. Right: prescription upload zone + audio recording with Start/Stop buttons + segment list. Bottom: green Mark Complete button + red Emergency 112 button. Status log shows real-time pipeline progress.

**ADK Dev UI — Patient:** Agent greets warmly. Patient types "Find a cardiologist near me" → ranked doctor list with distance, rating, fee, experience displayed.

## Architecture
**Frontend:** Login Page (HTML) | ADK Dev UI (chat) | Session Panel `/session/{id}`

**FastAPI Backend (`main.py`):**
- `POST /login` → bcrypt auth → `shared_state` → redirect to `/dev-ui/?userId=`
- `GET /session/{id}` → session panel HTML
- `POST /api/session/{id}/audio` → GCS upload
- `POST /api/session/{id}/complete` → mark complete + summarize pipeline

**ADK Agent Layer:** `root_agent` with dynamic `ReadonlyContext` instruction. Role from `context.state` or `shared_state` fallback. 14 tools: booking (5) + session (6) + summary (2) + calendar (3).

**Data Layer:** AlloyDB PostgreSQL (11 tables, ivfflat vector indexes) | AlloyDB AI `embedding()` for semantic search | Google Cloud Storage for audio + prescriptions

**External Integrations:** Gemini 2.5 Flash Vertex AI (transcription, OCR, summarisation, analytics) | Telegram Bot API | Google Calendar API OAuth2

**Deployment:** Cloud Run (serverless, HTTPS) | SQLite aiosqlite (ADK session persistence)

## Technologies / Google Services
**Google ADK 1.14.0:** Dynamic ReadonlyContext instructions. Single agent serves both roles. No separate deployments needed.

**Gemini 2.5 Flash (Vertex AI):** Multimodal — audio transcription + prescription image OCR in one model. Structured JSON clinical summaries. Fast response critical for live clinic use.

**AlloyDB AI:** `embedding()` SQL generates vectors in-database without external calls. Haversine distance for location search. ivfflat index for medical history similarity. Scales to millions of records without architecture changes.

**Google Cloud Storage:** Audio segments 5–30MB each. Multi-segment uploads keyed by `appointment_id`.

**Telegram Bot API:** 95%+ Indian patients already on Telegram. Zero install. Instant prescription summaries delivered post-visit.

**Google Calendar API (OAuth2):** Auto-creates events on booking. 1hr + 10min reminders. Reschedule updates existing event — no duplicate entries.

**Cloud Run:** Serverless — zero cost when idle, instant scale at peak. Single adk deploy command. HTTPS by default.

**Scalability:** AlloyDB horizontal scaling + Cloud Run auto-scaling. Swap `shared_state` dict for Redis for full stateless multi-replica support.

## Prototype Snapshots
**Login Page:** Dark glassmorphism card. Demo quick-fill buttons for Doctor and Patient. Tech stack badges: Google ADK, Gemini 2.5 Flash, AlloyDB AI, Cloud Run, Telegram Bot.

**Doctor Chat:** Agent greets Dr. Arjun Sharma, shows today's appointments immediately. "Start session for Rahul" → clickable session panel link returned.

**Session Panel:** Patient card with red allergy badge and yellow chronic condition badge. 2 audio segments recorded. Prescription photo uploaded. Mark Complete button ready to fire pipeline.

**Telegram to Patient:** "Diagnosis: Hypertension — BP 158/96. Medications: Amlodipine 5mg, Aspirin 75mg. Follow-up: Review in 1 week. Stay healthy!"

**Patient Chat:** "Find a cardiologist near me" → Dr. Meera Nair (2.1km, ★4.8, 22yr exp, ₹1000). Patient books with one message → Calendar invite sent.

**Google Calendar:** Event "ClinicFlow: Rahul Mehta with Dr. Arjun Sharma" created. Both emails received invites with 1hr + 10min reminders.

## Setup
See [SETUP_GUIDE.md](SETUP_GUIDE.md) for complete instructions.

## Demo Accounts
| Role | Email | Password |
|------|-------|----------|
| Doctor | doctor@clinicflow.demo | demo1234 |
| Patient | patient@clinicflow.demo | demo1234 |
