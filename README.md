# Distance Monitor

An Android-only Flutter dashboard for ESP32 + HC-SR04 distance monitoring. Built with Flutter 3.32.6 / Dart 3.8.1, Material 3, native widgets and a CustomPainter gauge.

## Run in VS Code

1. Install Flutter and the VS Code Flutter/Dart extensions. Install Android SDK platform/build tools and a compatible JDK. Run `flutter doctor` and address Android toolchain issues; review licenses with `flutter doctor --android-licenses`.
2. Open this folder in VS Code and run `flutter pub get`.
3. Connect an Android phone with Developer options / USB debugging enabled, authorize the computer, and select the device in VS Code. Alternatively start an Android emulator.
4. Press F5, or run `flutter run -d <device-id>`.
5. Build a development APK with `flutter build apk --debug`. For MediaFire distribution, follow the **Prepare a public release** steps below before running `flutter build apk --release`. APKs are in `build/app/outputs/flutter-apk/`.

## Connect hardware

The app always reads live data from the ESP32; readings are never simulated. Flash the [ESP32 sketch](firmware/distance_monitor/distance_monitor.ino), set its WiFi credentials, and read its IP in Serial Monitor at 115200 baud. On the phone, open Settings, enter the host and port (default 80), then Save configuration. Test connection contacts the entered endpoint and does not save changes.

Both devices need the same reachable LAN. Guest WiFi isolation, VPN routing, mobile-only connections, or firewall rules may prevent access. Open `http://<ESP32-IP>/distance` in the phone browser first. `esp32.local` uses mDNS; use the numeric IP if the network does not resolve it. The emulator has a different network path; `10.0.2.2` means the development computer, not the ESP32.

### HTTP and Android

`GET http://<configured-host>:<port>/distance`

```json
{"distance_cm":22.4,"sensor_ok":true}
```

Sensor failure response (HTTP 200):

```json
{"distance_cm":null,"sensor_ok":false}
```

The app rejects missing fields, invalid JSON, nonnumeric/nonfinite/negative values, failed sensor status, non-200 responses and timeouts. Firmware only reports valid HC-SR04 readings within its assumed 2–400 cm operating range; the UI classifier supports any finite nonnegative distance.

Android internet permission is included. Release builds allow cleartext HTTP to any host because each user can enter a different ESP32 address in Settings. Android cannot safely restrict cleartext access to only the address entered at runtime. Traffic is unencrypted and the ESP32 endpoint is unauthenticated: only connect over a trusted local WiFi network, never expose the ESP32 endpoint directly to the internet, and do not send sensitive data through it.

## Prepare a public release

The Android release build requires your own signing key; the build is intentionally blocked if release signing is not configured. Keep the keystore and its passwords private and backed up. Losing the key prevents you from signing future updates that install over this release.

1. From the project root, create a private keystore (replace the alias and choose a strong password when prompted; press Enter at the key-password prompt to reuse the keystore password, or set a separate one):

   ```powershell
   keytool -genkey -v -keystore android\app\upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias distance-monitor
   ```

2. Create `android\key.properties` locally (it is ignored by Git) with the matching values:

   ```properties
   storePassword=YOUR_KEYSTORE_PASSWORD
   keyPassword=YOUR_KEY_PASSWORD
   keyAlias=distance-monitor
   storeFile=upload-keystore.jks
   ```

   Do not commit or share this file or `android\app\upload-keystore.jks`.

3. Build the signed APK:

   ```powershell
   flutter build apk --release
   ```

4. Upload `build\app\outputs\flutter-apk\app-release.apk` to MediaFire. Users may need to allow installation from their browser or file manager. For updates, keep the same application ID and signing key, and increase the version in `pubspec.yaml`.

## Behavior

- DANGER: <15 cm; CAUTION: 15–30 cm inclusive; SAFE: >30 cm. Invalid/missing/stale data is always NO DATA.
- Default poll delay is 500 ms **after completion**, configurable 250–10000 ms. Requests never overlap in the monitor. A separate settings connection test is user initiated.
- Request timeout: 3 seconds, followed by closing its HTTP client. Failure retry delay doubles up to 10 seconds. Reconnect retries immediately when no request is in flight.
- The first failure clears the current distance. A secondary stale limit is `max(5 seconds, 3 × configured polling interval)`. Last update is the age of the last valid response, not an assertion that it is still current. Firmware also expires its own sample after one second.
- Polling stops when the app becomes inactive. Resume requests a new reading; late responses from previous configurations are ignored.
- The visual arc is distance / configured gauge maximum, clamped to 0–1. Default scale is 0–100 cm; actual readings above it remain visible. Thresholds never change with the visual scale.
- Settings are stored locally with shared_preferences. Missing settings use the default ESP32 host; damaged settings fall back to default connection settings. Existing saved settings from older versions remain readable.
- The dashboard scrolls, limits maximum content width on large screens, and stacks tiles when text or width requires it. At large text sizes, the reading is placed below the arc. No orientation lock. Animations respect the system reduced-motion setting.

## Project structure and authored files

```text
lib/
  main.dart                         startup and settings loading
  app/app.dart                      Material theme and lifecycle ownership
  models/distance_reading.dart      validated model + single classifier
  models/monitor_settings.dart      settings model and host validation
  controllers/distance_controller.dart   polling and stale state
  services/esp32_service.dart        HTTP, timeout and parsing
  services/settings_service.dart    local persistence
  screens/dashboard_screen.dart     responsive dashboard
  screens/settings_screen.dart      validated settings and connection test
  widgets/distance_gauge.dart        animated native arc painter
  widgets/dashboard_components.dart     reusable responsive cards
firmware/distance_monitor/distance_monitor.ino
firmware/README.md                   wiring and firmware setup
 test/monitor_test.dart              classifier, HTTP and lifecycle tests
 test/widget_test.dart               sizes, text scales and settings tests
.vscode/launch.json                  F5 Android launch
.vscode/tasks.json                   analyze, tests, APK tasks
```

The generated Android Flutter scaffold is included. Android manifest and network security resources are configured for ESP32 HTTP. Runtime packages: `http` 1.6.0 and `shared_preferences` 2.5.3 (resolved for the installed SDK); test dependencies: Flutter SDK `flutter_test` and `flutter_lints`. Exact transitive versions are in [pubspec.lock](pubspec.lock).

## Validate

```sh
flutter pub get
dart format .
flutter analyze
flutter test
flutter build apk --debug
```

Responsive tests cover 320×568, 360×800, 412×915, 800×360, and 600×960 logical pixels at 100%, 200%, and 300% text size. These are automated layout checks, not a guarantee for every Android device or vendor accessibility configuration.

Real ESP32 sensor/LED/LCD operation, WiFi behavior on a physical phone, and perceived animation smoothness require device testing. The Arduino sketch is provided separately and must be compiled with your board and LCD library. Release signing uses the private keystore configured locally as described above. No iOS target is included.

## Validation recorded for this implementation

- `flutter pub get`: passed on Flutter 3.32.6 / Dart 3.8.1.
- `dart format .`: passed.
- `flutter analyze`: no issues found.
- `flutter test`: all 29 tests passed, including 15 size/text-scale combinations.
- `flutter build apk --debug`: passed; final build completed after pinning Android NDK 27.0.12077973 and disabling Kotlin incremental compilation to handle project/cache paths on different Windows drives.
- Physical Android phone and ESP32 hardware: not tested.
- Firmware: not compiled here; Arduino CLI is not installed.
- Android emulator smoke check: previously installed and launched on the configured API 36 Medium Phone emulator. Physical-device performance and hardware connectivity still require device testing.
