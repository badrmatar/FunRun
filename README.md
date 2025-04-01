# FunRun App - README

Welcome to **FunRun**, a socially-driven, gamified fitness tracking app built with Flutter and integrated with Supabase. This README provides user guides, setup instructions, and developer insights.

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.x recommended)
- Dart SDK
- Xcode (for iOS)
- Android Studio (for Android)
- Supabase account & project with necessary Edge Functions

---

## 📥 Installation (User Guide)

### iOS (via TestFlight)
- [Install DuoRun v1 via TestFlight](https://testflight.apple.com/join/nQ8urZrW)

### Android
- [Download Android APK](https://drive.google.com/file/d/1qSHyYQ1TRFqlQ0HTSeOyTTyJyEsBwztf/view)

---

## 📖 User Manual

### Navigation
- **Home:** Daily stats, tips, logout
- **Challenges:** View and join daily team challenges
- **Run Types:** Choose between Solo or Duo runs
- **Run Pages:** Real-time tracking, stats, maps, auto-pause, streaks
- **League:** Compete with other teams in the leaderboard
- **History:** Browse personal and team run history

### Features
- 🏃‍♂️ GPS-based run tracking (Solo & Duo)
- 🤝 Duo runs: stay within 500m of your partner
- 🔥 3-day streaks for rewards
- 🎯 Daily team challenges
- 🏆 Leagues: light team-based competition
- 🗺️ Real-time map updates
- 📊 Run summaries with route replay

---

## 👨‍💻 Developer Setup

### Clone the Repository
```bash
git clone https://github.com/badrmatar/year4_project_final.git](https://github.com/badrmatar/FunRun
cd year4_project_final
Install Dependencies
bash
Copy
flutter pub get
Configure Environment
Create a .env file using .env.example as a template.

Set the following:

SUPABASE_URL

SUPABASE_ANON_KEY

SUPABASE_BEARER_TOKEN

iOS Specific Setup
Open ios/Runner.xcworkspace in Xcode.

Ensure the deployment target is set to iOS 14.0 or higher.

Run:

bash
Copy
cd ios && pod install
Ensure Info.plist includes:

Location permissions (Always + When In Use)

Background modes enabled (Location)

Run the App
bash
Copy
flutter run
📍 Permissions & Location Handling
App requests and uses background location

On iOS, location is handled natively via AppDelegate.swift

Real-time updates are passed to Flutter via method channels

📁 Key Files Overview
File	Purpose
main.dart	Entry point, route definitions
active_run_page.dart	Solo run tracking
duo_active_run_page.dart	Duo partner-based run tracking
duo_waiting_room_page.dart	Matchmaking logic before Duo run
home_page.dart	Stats, tips, and navigation
league_room_page.dart	Leaderboard & team rankings
run_tracking_mixin.dart	Shared GPS logic and route management
auth_service.dart	Login, signup, logout, secure storage
location_service.dart	GPS, Kalman filtering, quality detection
✅ Testing
Manual Testing
Solo Run ✅

Duo Run & Auto-End ✅

Streak Preservation ✅

League Functionality ✅

Edge Functions (Supabase) ✅

🚀 Deployment Notes
iOS beta distributed via TestFlight

Edge Functions deployed in Supabase project

For Supabase team access, please email: 2722762m@student.gla.ac.uk

👨‍💼 Maintainer
Bader Matar
University of Glasgow | Final Year Computer Science Student
