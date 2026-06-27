# ARIA — Adaptive Reasoning Intelligence Assistant

> One app. Your tasks, your AI, your focus — all in sync.

ARIA is a cross-platform mobile productivity app that replaces the fragmented stack of task managers, timers, note apps, and AI assistants with a single intelligent interface. It learns from your workflow and gives you context-aware guidance — not just reminders.

---

## The Problem

Students and professionals average 5+ productivity apps daily. Switching between them breaks focus, fragments context, and means your task manager never knows what your AI assistant knows. ARIA closes that gap.

---

## Features

### 🧠 AI Chat
Conversational assistant powered by LLaMA 3.1-8B via Groq API. Remembers context across sessions, extracts actionable insights, and suggests next steps based on your workload.

### ✅ Smart Task Management
Create, organize, and prioritize tasks. The AI surfaces what matters most based on deadlines, habits, and past behavior — not just due dates.

### ⏱️ Deep Focus Sessions
Pomodoro-style focus tracking with app-blocking to eliminate distractions. View streaks, session logs, and focus analytics over time.

### 🎙️ Voice I/O
Fully hands-free: speak to create tasks, ask questions, or get updates. Daily briefings are read aloud each morning via text-to-speech.

### 📋 Daily Briefing
AI-generated morning summary of your tasks, habits, and behavioral insights — delivered as audio or text.

### 🔔 Smart Reminders
Context-aware notifications that adapt to your patterns, not just a fixed schedule.

### 🔄 Real-Time Sync
Firestore-backed multi-device sync with under 500ms latency. Pick up exactly where you left off.

---

## Tech Stack

| Layer | Technology | Purpose |
|---|---|---|
| **Frontend** | Flutter 3.41 + Dart | Cross-platform mobile UI (Android tested) |
| **AI Engine** | Groq API + LLaMA 3.1-8B | Conversational AI with memory extraction |
| **Database** | Cloud Firestore (NoSQL) | Real-time task, chat, and session data |
| **Auth** | Firebase Auth | Email/password + JWT token management |
| **Voice** | flutter_tts + speech_to_text | TTS for briefings; STT for voice chat |
| **Local Storage** | SharedPreferences | Cached briefs, preferences, streaks |
| **Notifications** | flutter_local_notifications | Daily summaries and session reminders |
| **Automation** | n8n | Backend workflow automation and data pipeline |
| **Deployment** | Firebase App Distribution | APK hosting and tester distribution |
| **Version Control** | GitHub | 2 active contributors |

---

## Project Structure

```
aria/
├── lib/
│   ├── models/          # Data models — Task, Session, Memory
│   ├── services/        # Firebase, Groq API, voice services
│   ├── screens/         # UI pages — chat, tasks, dashboard
│   ├── widgets/         # Reusable UI components
│   └── main.dart        # App entry point
├── assets/              # Icons, fonts, images
└── pubspec.yaml         # Dependencies
```

---

## Architecture

- **State Management:** Provider pattern for reactive UI updates
- **AI Integration:** Streaming responses from Groq API for low-latency chat (~800ms average)
- **Real-Time Sync:** Firestore listeners with <500ms latency
- **Voice Processing:** Background isolate for STT accuracy during active tasks
- **Cold Start:** <2s on tested Android devices
- **APK Size:** ~150MB (includes TTS/STT models)

---

## Getting Started

### Prerequisites

- Flutter 3.41+
- Dart SDK
- A Firebase project with Firestore and Auth enabled
- A [Groq API key](https://console.groq.com/) for LLaMA access

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/sadia500/ARIA.git
   cd ARIA
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Download `google-services.json` from your Firebase console
   - Place it in `android/app/`
   - Set up Firestore security rules for real-time sync

4. **Add API keys**
   - Create `lib/config/keys.dart` and add your Groq API key:
     ```dart
     const String groqApiKey = 'YOUR_GROQ_API_KEY';
     ```

5. **Run the app**
   ```bash
   flutter run
   ```

---

## Roadmap

- [ ] iOS support
- [ ] Habit tracking with streaks
- [ ] Google Calendar integration
- [ ] PDF export for focus analytics
- [ ] Offline-first mode with local sync queue
- [ ] Custom LLM fine-tuning on anonymized user patterns

---

## License

This project is for educational and portfolio purposes. No license has been applied — all rights reserved by the authors.
