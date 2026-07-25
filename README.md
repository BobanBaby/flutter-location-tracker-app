# Location Tracking & Journey Analysis (Flutter POC)

A production-ready Flutter mobile application for **Adaptive Location Tracking**, **Discrete Multi-Journey Session Management**, and **5-Case Gap Detection Journey Analysis** integrated with **Google Routes API** and **Firebase Cloud Firestore**.

---

## 🌟 Key Architecture & Features

### 1. Mobile Location Engine (Phase 1)
- **Foreground Service**: Persistent sticky notification (`Location Tracking is active`) for Android & iOS background execution.
- **Adaptive GPS Sampling**:
  - **Driving ($\ge 14$ km/h)**: Captures point every 30s or 100m.
  - **Walking ($\ge 0.5$ km/h or $\ge 4$m displacement)**: Captures point every 20s or 15m.
  - **Still ($< 0.5$ km/h)**: Captures point every 5 minutes (Battery Saver).
- **Physical Activity Recognition**: 3-sample moving average speed filter with state debouncing to accurately detect transitions between Walking, Driving, and Still states.
- **Offline-First Storage**: Every GPS fix is saved immediately into local SQLite database (`location_logs`).
- **Cloud Upload Queue**: 5-minute periodic batch sync to Cloud Firestore collection **`sales_gps_logs`**.

### 2. Journey Analysis & Gap Detection Engine (Phase 2)
- **Discrete Journey Isolation**: Every `Start Tracking` $\rightarrow$ `Stop Tracking` run generates a unique `journey_id` and saves completed analysis into SQLite (`journey_reports`).
- **5-Case Decision Logic**:
  - **Case 1 (Normal Tracking)**: Gap $\le 2$ min $\rightarrow$ Uses raw GPS path.
  - **Case 2 (Stationary)**: Gap $> 2$ min & Dist $< 150$m $\rightarrow$ Classified as Shop/Lunch stop.
  - **Case 3 (Missing Travel)**: Gap $> 2$ min & Dist $> 300$m $\rightarrow$ Calls **Google Routes API** to reconstruct missing road distance & polyline.
  - **Case 4 (GPS Drift)**: Road distance $< 50$m vs Straight distance $> 120$m $\rightarrow$ Drift detected & ignored.
  - **Case 5 (Fallback)**: API unavailable $\rightarrow$ Uses GPS straight distance.
- **Stationary Jitter Filtering**: Filters out sub-10m satellite drift fixes while remaining stationary so `Corrected Distance` stays `0.00 km`.

### 3. UI & Visualization
- **Interactive OpenStreetMap (`flutter_map`)**: Zoom, pan, color-coded route polylines (**Blue** = Raw GPS, **Orange** = Routes API corrected), and Start/End pins.
- **KPI Metrics Cards**: Calculated Raw GPS Distance, Corrected Road Distance, Working Hours, Speed, and Quality Score %.
- **Daily Travel Timeline**: Chronological event breakdown of all stops, walking runs, and missing travel gaps.
- **Export Options**: Single-tap copy/download of JSON & CSV analysis reports.

---

## 🛠️ How to Run on VS Code

### Prerequisites
1. Install [Flutter SDK](https://docs.flutter.dev/get-started/install).
2. Install [VS Code](https://code.visualstudio.com/) with **Flutter** and **Dart** extensions.

### Steps
1. **Open Project**:
   Open VS Code and navigate to `File` $\rightarrow$ `Open Folder...` $\rightarrow$ select `c:/Location POC/app`.

2. **Install Dependencies**:
   Open VS Code Terminal (`Ctrl + ~` or `Terminal` $\rightarrow$ `New Terminal`) and run:
   ```bash
   flutter pub get
   ```

3. **Select Target Device**:
   - Click on the device selector in the bottom right corner of VS Code status bar (or press `Ctrl + Shift + P` $\rightarrow$ `Flutter: Select Device`).
   - Choose a connected Android phone, iOS Simulator, or Android Emulator.

4. **Launch Application**:
   - Press **`F5`** or go to `Run` $\rightarrow$ `Start Debugging`.
   - Or run from terminal:
     ```bash
     flutter run
     ```

---

## 🍎 How to Run on Xcode (iOS)

### Prerequisites
- macOS machine with **Xcode 15+** installed.
- CocoaPods (`sudo gem install cocoapods`).

### Steps

1. **Configure iOS Dependencies**:
   Open terminal inside `c:/Location POC/app/ios` and run:
   ```bash
   cd ios
   pod install
   ```

2. **Open Workspace in Xcode**:
   Open Xcode, then select `File` $\rightarrow$ `Open...` and select the **`Runner.xcworkspace`** file:
   ```bash
   open ios/Runner.xcworkspace
   ```
   > ⚠️ **Important**: Always open `Runner.xcworkspace`, NOT `Runner.xcodeproj`.

3. **Configure Signing & Capabilities (Free Provisioning)**:
   - In Xcode left sidebar, click on **Runner** (top project node).
   - Select the **Runner** target under *Targets*.
   - Click the **Signing & Capabilities** tab.
   - Under **Team**, select your **Personal Apple ID Team** (No paid developer subscription required for local device testing).
   - Ensure **Bundle Identifier** is set (e.g. `com.locationpoc.app`).

4. **Run on iPhone or iOS Simulator**:
   - Select your connected physical iPhone or iOS Simulator from the top device dropdown in Xcode.
   - Press the **Play (▶️)** button in top left of Xcode (or press `Cmd + R`).

---

## 🔑 Firebase & Google API Configuration

### Google Routes API Key Setup (Kept Out of Git)
To keep your API Key secure and out of version control, follow either option below:

#### Option A: Local Config File (Recommended for Local Dev)
1. Copy the template configuration file:
   ```bash
   cp lib/config/api_config.template.dart lib/config/api_config.dart
   ```
2. Open `lib/config/api_config.dart` and add your key. `lib/config/api_config.dart` is automatically ignored by `.gitignore` and will **never** be committed to Git.

#### Option B: Environment Variable (Recommended for CI/CD Builds)
Pass your API key at compile time:
```bash
flutter run --dart-define=GOOGLE_ROUTES_API_KEY=YOUR_ACTUAL_API_KEY
```

### Firebase Cloud Firestore Setup
1. **Android**: Download your `google-services.json` from Firebase Console and place it at:
   ```
   android/app/google-services.json
   ```
   *(Or copy `android/app/google-services.json.template` $\rightarrow$ `android/app/google-services.json` and edit)*
2. **iOS**: Place your `GoogleService-Info.plist` file in:
   ```
   ios/Runner/GoogleService-Info.plist
   ```
3. Enable **Cloud Firestore Database** in [Firebase Console](https://console.firebase.google.com/) under **Build $\rightarrow$ Firestore Database**.

---

## 🧪 Running Unit & Integration Tests

Run full unit tests for the 5-Case Gap Detection Engine & Haversine distance calculations:
```bash
flutter test
```
