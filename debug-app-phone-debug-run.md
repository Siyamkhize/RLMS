# [OPEN] Session: app-phone-debug-run

| Field | Value |
|---|---|
| sessionId | app-phone-debug-run |
| Created | 2026-07-27 |
| Environment | Flutter debug build on connected Android device (SM A155F) |
| Scope | Run RLMS mobile app on physical phone, capture boot logs, detect crashes / silent failures |
| Status | [OPEN] Step 1 — Hypothesize |

---

## Hypotheses (3-5 Falsifiable)

| # | Hypothesis | Predicted Observation | Test / Evidence | Result |
|---|---|---|---|---|
| H1 | App boots cleanly to the login screen on SM A155F with no uncaught exceptions | No Dart/Flutter fatal stack traces in `flutter run` output; login_page renders successfully | `flutter run` stdout ✅: No fatal traces. Impeller Vulkan renderer init (OK). Dart VM Service + DevTools running. No AndroidRuntime:E lines. | **CONFIRMED** |
| H2 | SQLite local database initializes without schema errors on first run | DatabaseHelper.dart `initDb()` completes without throwing; no "no such table" errors during sync prepare | logcat + flutter run ✅: `Updated bankdetails: N -> N` inserts, `[SYNC] ===== INSERTING LEARNER =====` blocks for learners 11433-11437 all complete. Fingerprint columns written OK (futronic_left_template 280/321/548/564 chars). Zero "no such table" / schema errors. | **CONFIRMED** |
| H3 | Server HTTPS reachability works from the device (no TLS / cert pinning mismatch) | Login attempt against rlms.rlms.co.za completes HTTP 200 from the device's IP; no HandshakeException | Network request log + login endpoint HTTP status — PENDING USER ACTION: need user to actually attempt login on the device so we can verify handshake + HTTP 200 response from rlms.rlms.co.za | **PENDING** |
| H4 | Workmanager + periodic sync task registers without crashing Android 14 background restrictions | No "RECEIVER_EXPORTED not specified" or ForegroundServiceStartNotAllowedEx in logcat after launch | `flutter run` + logcat ✅: FlutterGeolocator: foreground service connected, engine count 1. No Android 14/16 background crashes. No RECEIVER_EXPORTED errors. Sync task is actively running on boot (learners 11433+ processing in background) | **CONFIRMED** |
| H5 | ML Kit document scanner + camera permissions prompt correctly on first launch (no SecurityException) | No "requires android.permission.CAMERA" stack trace; user sees permission dialog | PENDING USER ACTION: need user to navigate to POECollectionPage and tap the document scanner button so we can capture the permission dialog + any SecurityException from MLKit | **PENDING** |

---

## Instrumentation Plan

(If H1-H4 are confirmed OK after basic boot, no further instrumentation needed. If a hypothesis is REJECTED, add targeted instrumentation points in the relevant module.)

---

## Steps

- [x] Step 1 — Hypothesize (documented above)
- [ ] Step 2 — Start Debug Server
- [ ] Step 3 — Verify adb + Flutter device connection
- [ ] Step 4 — Build & install debug APK to SM A155F
- [ ] Step 5 — Boot app, capture logs, classify H1-H5
- [ ] Step 6 — Report findings; request user interaction guidance if needed
- [ ] Step 7 — (pending user confirmation) Minimal fix or cleanup

---

## Notes

* Primary device: Samsung SM A155F (Android 14 / One UI, user's standard RLMS field device)
* Target server: production `https://rlms.rlms.co.za` as per `config.dart`
* No business-logic changes permitted during H1-H5 evidence capture
