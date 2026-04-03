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

## Setup
See [SETUP_GUIDE.md](SETUP_GUIDE.md) for complete instructions.

## Demo Accounts
| Role | Email | Password |
|------|-------|----------|
| Doctor | doctor@clinicflow.demo | demo1234 |
| Patient | patient@clinicflow.demo | demo1234 |
