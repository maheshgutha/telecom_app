# TelecomCRM - Flutter Mobile App

Mobile app for the Telecommunication CRM system, mirroring the web application features.

## 🔧 Setup Before Building

### 1. Update Server URL
Edit `lib/services/auth_service.dart` and `lib/services/api_service.dart`:
```dart
static const String baseUrl = 'http://YOUR_SERVER_IP:5000/api';
```

### 2. Install Flutter
Download from: https://flutter.dev/docs/get-started/install
- Requires Flutter 3.x or later
- Java 11+ required for Android builds

### 3. Install Android SDK
- Install Android Studio: https://developer.android.com/studio
- Open SDK Manager → install Android SDK 31+

### 4. Update local.properties
Edit `android/local.properties`:
```
sdk.dir=C:\\Users\\YourName\\AppData\\Local\\Android\\Sdk
flutter.sdk=C:\\flutter
flutter.buildMode=release
flutter.versionName=1.0.0
flutter.versionCode=1
```

## 🚀 Build APK

```bash
# Install dependencies
flutter pub get

# Check setup
flutter doctor

# Build debug APK (for testing)
flutter build apk --debug

# Build release APK (for distribution)
flutter build apk --release

# APK location:
# build/app/outputs/flutter-apk/app-release.apk
```

## 📱 App Features

| Screen | Description |
|--------|-------------|
| **Login** | JWT auth with your backend |
| **Dashboard** | Stats: total leads, today's calls, follow-ups, conversions + pie chart |
| **Leads** | List with search, filter by status, one-tap call |
| **Lead Detail** | Full info, call/WhatsApp buttons, status update |
| **Follow-ups** | All/Today/Overdue tabs, mark as done |
| **My Calls** | Date-picker view of your assigned calls |
| **Campaigns** | Progress bars, conversion rates |
| **Reports** | Charts: bar trend, caller performance |
| **Profile** | User info, role badge, logout |

## 🔐 Permissions Required
- `INTERNET` - API calls
- `CALL_PHONE` - Direct dial from app
- `ACCESS_NETWORK_STATE` - Connection check

## 📡 API Endpoints Used
```
POST /api/auth/login
GET  /api/leads
GET  /api/leads/:id
POST /api/leads
PUT  /api/leads/:id/status
GET  /api/followups
PUT  /api/followups/:id
GET  /api/campaigns
GET  /api/reports
GET  /api/reports/dashboard
GET  /api/leads/my-calls
GET  /api/users
```

## 🎨 Tech Stack
- Flutter 3.x
- Provider (state management)
- HTTP (API calls)
- fl_chart (charts)
- shared_preferences (JWT storage)
- url_launcher (call/WhatsApp)
- google_fonts (Inter font)
