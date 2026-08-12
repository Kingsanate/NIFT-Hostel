# NIFT Hostel — Smart Student Management System

A cross-platform **Flutter** application for managing student hostels at NIFT Shillong. Available as an Android APK and a Progressive Web App (PWA).

## ✨ Features

- 🎓 **Student Management** — Add, edit, search students with photo scanning
- 📋 **Attendance Tracking** — Daily attendance with real-time sync
- 🤖 **AI Scanner** — Scan admission forms using Gemini AI to auto-fill student data
- 💬 **AI Chat Assistant** — Hostel management assistant powered by Gemini / Groq
- 🏥 **Medical Records** — Track student health and medical incidents
- 📅 **Events & Notices** — Hostel event management and announcements
- 📊 **PDF Reports** — Generate and print attendance and student reports
- 🔔 **Reminders** — Smart AI-generated reminders
- 🌐 **Offline Support** — Works offline with Hive local cache + Supabase sync

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.41 (Dart 3.11) |
| Backend | Supabase (PostgreSQL + Auth + Realtime) |
| AI | Google Gemini API + Groq API |
| State | Riverpod |
| Local Cache | Hive |
| Notifications | flutter_local_notifications (mobile) |

## 🚀 Getting Started

### Prerequisites
- Flutter 3.41+ (`flutter --version`)
- Dart 3.11+

### Run locally

```bash
# Clone the repo
git clone https://github.com/YOUR_USERNAME/nift-hostel-app.git
cd nift-hostel-app

# Install dependencies
flutter pub get

# Run on Android
flutter run

# Run on Web (browser)
flutter run -d chrome

# Build web release
flutter build web --release --no-wasm-dry-run
```

## 🌐 Web Deployment

The app is hosted on **Cloudflare Pages** and auto-deploys on every push to `main` via GitHub Actions.

**Live URL:** https://nift-hostel.pages.dev

### Platform compatibility notes
| Feature | Android | Web |
|---|---|---|
| Student management | ✅ | ✅ |
| Attendance | ✅ | ✅ |
| AI Chat | ✅ | ✅ |
| PDF export | ✅ | ✅ (browser print) |
| Scanner (live camera) | ✅ | ✅ (file upload) |
| Face detection | ✅ | ⬛ (skipped gracefully) |
| Push notifications | ✅ | ⬛ (browser permission) |
| Speech to text | ✅ | ✅ (Chrome/Edge) |

## 📁 Project Structure

```
lib/
├── main.dart              # App entry + Supabase init
├── splash_screen.dart     # Animated splash
├── auth/                  # Login / auth flow
├── home/                  # Dashboard + reminders
├── students/              # Student CRUD
├── attendance/            # Attendance tracking
├── scanner/               # AI form scanner
├── chat/                  # AI assistant
├── events/                # Events & notices
├── medical/               # Medical records
├── profile/               # User profile
├── rules/                 # Hostel rules
├── settings/              # App settings
├── services/              # Notification, offline cache, sync
└── core/                  # Config, providers
```

## 🔐 Environment & Keys

All API keys (Gemini, Groq) are fetched at runtime from the **Supabase `app_config` table** — no keys are hardcoded in this repository. The Supabase publishable anon key is safe to commit.

## 📄 License

Internal use — NIFT Shillong Hostel Administration.
