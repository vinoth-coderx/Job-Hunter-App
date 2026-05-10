# Job Hunter — Flutter App

A modern, production-ready job-hunter mobile app built with Flutter. The UI is pixel-matched to the design references provided (welcome screen, job detail, search, applications tracking, messages, and profile).

![Flutter](https://img.shields.io/badge/Flutter-3.27%2B-blue?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.6%2B-blue?logo=dart)
![License](https://img.shields.io/badge/license-MIT-green)

---

## ✨ Features

- 🔐 **Authentication** — Email/password + Google sign-in (mock auth out of the box, swappable to Firebase in 5 minutes)
- 🏠 **Home** — Personalised greeting, search, category filters, “Job match with you” feed
- 🔎 **Search** — Active filter chips, result count, bottom-sheet Filter & Sort pills
- 📄 **Job Detail** — Tabbed view (Description / Company / Review), urgency badge, one-tap apply
- 📋 **Applications** — Live stats (applied / shortlisted / rejected) + last applications list with status badges
- 💬 **Messages** — Chat list (General / Archived tabs), 1-on-1 chat with bubbles + send box
- 👤 **Profile** — Blue gradient header card with Pro badge, Account & Social sections, log-out flow
- 🧭 **Custom black-pill bottom nav** with animated blue active circle (matches mockup exactly)
- 🎨 **Design system** — Centralised colors, typography (Inter via google_fonts), reusable widgets

---

## 🏗 Architecture

```
lib/
├── core/
│   ├── theme/         → AppColors, AppTextStyles, AppTheme
│   ├── routes/        → Named route constants
│   └── constants/     → App-wide constants
├── data/
│   ├── models/        → Job, UserModel, ChatPreview, Application
│   ├── services/      → AuthService, JobService, StorageService
│   └── mock/          → Sample jobs, chats, applications
├── providers/         → AuthProvider, JobProvider (ChangeNotifier)
└── presentation/
    ├── widgets/       → Reusable UI (cards, chips, search bar, nav, buttons)
    ├── auth/          → Splash, Login, Signup
    ├── home/          → Home feed
    ├── search/        → Search with filters
    ├── job_detail/    → Job detail with tabs
    ├── applications/  → Application tracker
    ├── messages/      → Message list + chat
    ├── profile/       → User profile
    └── main_navigation/ → IndexedStack + bottom nav
```

**State management:** Provider (lightweight, official, easy to migrate to Riverpod/Bloc later).

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK **3.27.0+** (latest stable / LTS)
- Dart **3.6.0+**
- Android Studio / Xcode / VS Code with Flutter plugin
- An Android emulator, iOS simulator, or physical device

Verify:

```bash
flutter --version
flutter doctor
```

### Install & Run

```bash
# 1. Clone or unzip the project, then:
cd job_hunter

# 2. Install dependencies
flutter pub get

# 3. Run on a connected device or emulator
flutter run
```

Want a release build?

```bash
flutter build apk --release          # Android
flutter build ios --release          # iOS (Mac required)
flutter build web --release          # Web
```

---

## 🔑 Login

The mock auth accepts **any** email/password (≥6 chars) for demo purposes:

| Field    | Value                |
|----------|----------------------|
| Email    | anything@example.com |
| Password | any 6+ chars         |

Or just tap **“Continue with Google”** — it signs you in instantly as the demo profile so you can see the populated profile screen.

---

## 🔥 Switching from Mock Auth to Firebase

The app ships with mock auth so you can run it immediately, but real Firebase auth is one config away.

1. **Enable the dependencies** in `pubspec.yaml` (uncomment):
   ```yaml
   firebase_core: ^3.6.0
   firebase_auth: ^5.3.1
   google_sign_in: ^6.2.1
   cloud_firestore: ^5.4.4
   ```
   then run `flutter pub get`.

2. **Configure Firebase**:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   This generates `firebase_options.dart`.

3. **Initialize Firebase** — uncomment the `Firebase.initializeApp(...)` block at the top of `lib/main.dart`.

4. **Swap the AuthService bodies** — open `lib/data/services/auth_service.dart`. Each method (`signInWithEmail`, `signUpWithEmail`, `signInWithGoogle`, `signOut`) has the real Firebase code already written **inside the comments**. Delete the mock body and uncomment the Firebase block.

5. **Google Sign-In platform setup**:
   - **Android** — add SHA-1 to Firebase console, download `google-services.json`.
   - **iOS** — add `GoogleService-Info.plist`, configure URL scheme in `Info.plist`.

That’s it. The rest of the app (providers, screens, routing) is already wired to whatever `AuthService` returns — no other changes needed.

---

## 🎨 Design Tokens

| Token | Value |
|-------|-------|
| Primary blue | `#2D7BFF` |
| Nav black    | `#111111` |
| Background gradient | `#E8F0FE → #FFFFFF` |
| Urgent red   | `#FF5A5A` |
| Success green | `#22C55E` |
| Card radius  | 20px |
| Pill radius  | 50px |
| Font         | Inter (google_fonts) |

All defined in `lib/core/theme/app_colors.dart` and `app_text_styles.dart` — change once, applies everywhere.

---

## 📦 Dependencies

| Package | Purpose |
|---------|---------|
| `provider` | State management |
| `google_fonts` | Inter typeface |
| `cached_network_image` | Logo & avatar caching |
| `shared_preferences` | Local persistence |
| `shimmer` | Loading placeholders |
| `intl` | Date / time formatting |

---

## 🧪 Testing

```bash
flutter analyze          # Static analysis
flutter test             # Run tests (add your own in /test)
```

---

## 📁 Project Structure Highlights

- **Single source of truth** for theme — `app_colors.dart`, `app_text_styles.dart`, `app_theme.dart`
- **No hardcoded colors / styles** in screens — everything goes through the design system
- **Mock data** is centralised in `lib/data/mock/mock_data.dart` so swapping to a real API only touches the service layer
- **Routes** are named constants in `app_routes.dart` — type-safe and refactor-friendly
- **All companies use real logos** via the free Clearbit Logo API — no asset bundle bloat

---

## 📝 License

MIT — do whatever you want with it.

---

## 🤝 Credits

Built end-to-end as a faithful Flutter implementation of the provided UI mockups. Company logos are fetched from Clearbit's free logo API; demo avatars from pravatar.cc.
# Job-Hunter-App
