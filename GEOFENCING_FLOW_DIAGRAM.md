# Geofencing Flow Diagram

## Clock-In Flow with Geofencing

```
┌─────────────────────────────────────────────────────────────────┐
│                    LEARNER CLOCK-IN FLOW                        │
└─────────────────────────────────────────────────────────────────┘

    ┌──────────────┐
    │ User selects │
    │   learner    │
    └──────┬───────┘
           │
           ▼
    ┌──────────────┐
    │ User clicks  │
    │  "Clock In"  │
    └──────┬───────┘
           │
           ▼
    ┌──────────────────────┐
    │ Check if fingerprint │
    │    is enrolled       │
    └──────┬───────────────┘
           │
           ├─── NO ──> ❌ Navigate to enrollment
           │
           ▼ YES
    ┌──────────────────────┐
    │ Show "Place finger   │
    │   on scanner..."     │
    └──────┬───────────────┘
           │
           ▼
    ┌──────────────────────┐
    │  Scan fingerprint    │
    └──────┬───────────────┘
           │
           ├─── NO MATCH ──> ❌ "Fingerprint does not match!"
           │
           ▼ MATCH
    ┌──────────────────────┐
    │ Show "Checking       │
    │   location..."       │
    └──────┬───────────────┘
           │
           ▼
    ┌──────────────────────┐
    │ Request location     │
    │   permissions        │
    └──────┬───────────────┘
           │
           ├─── DENIED ──> ❌ "Location permissions denied"
           │
           ▼ GRANTED
    ┌──────────────────────┐
    │ Check GPS enabled    │
    └──────┬───────────────┘
           │
           ├─── DISABLED ──> ❌ "Please enable GPS"
           │
           ▼ ENABLED
    ┌──────────────────────┐
    │ Get current GPS      │
    │   position           │
    └──────┬───────────────┘
           │
           ▼
    ┌──────────────────────┐
    │ Check GPS accuracy   │
    └──────┬───────────────┘
           │
           ├─── > 50m ──> ❌ "GPS accuracy too low"
           │
           ▼ < 50m
    ┌──────────────────────┐
    │ Get site coordinates │
    │   from database      │
    └──────┬───────────────┘
           │
           ├─── NOT FOUND ──> ❌ "No site coordinates found"
           │
           ▼ FOUND
    ┌──────────────────────┐
    │ Calculate distance   │
    │  (Haversine formula) │
    └──────┬───────────────┘
           │
           ├─── > 300m ──> ❌ "You are XXX meters away"
           │
           ▼ ≤ 300m
    ┌──────────────────────┐
    │ ✅ GEOFENCE PASSED   │
    └──────┬───────────────┘
           │
           ▼
    ┌──────────────────────┐
    │ Check if already     │
    │  clocked in today    │
    └──────┬───────────────┘
           │
           ├─── YES ──> ❌ "Already clocked in at XX:XX"
           │
           ▼ NO
    ┌──────────────────────┐
    │ Save to local DB:    │
    │ - Clock-in time      │
    │ - GPS latitude       │
    │ - GPS longitude      │
    │ - GPS accuracy       │
    └──────┬───────────────┘
           │
           ▼
    ┌──────────────────────┐
    │ Sync to server       │
    │  (if online)         │
    └──────┬───────────────┘
           │
           ├─── OFFLINE ──> ℹ️ "Saved locally (will sync)"
           │
           ▼ ONLINE
    ┌──────────────────────┐
    │ ✅ "Clock-in synced  │
    │    to server!"       │
    └──────────────────────┘
```

---

## Clock-Out Flow with Geofencing

```
┌─────────────────────────────────────────────────────────────────┐
│                   LEARNER CLOCK-OUT FLOW                        │
└─────────────────────────────────────────────────────────────────┘

    ┌──────────────┐
    │ User selects │
    │   learner    │
    └──────┬───────┘
           │
           ▼
    ┌──────────────┐
    │ User clicks  │
    │ "Clock Out"  │
    └──────┬───────┘
           │
           ▼
    ┌──────────────────────┐
    │ Check if clocked in  │
    │      today           │
    └──────┬───────────────┘
           │
           ├─── NO ──> ❌ "Please clock in first"
           │
           ▼ YES
    ┌──────────────────────┐
    │ Show "Place finger   │
    │   on scanner..."     │
    └──────┬───────────────┘
           │
           ▼
    ┌──────────────────────┐
    │  Scan fingerprint    │
    └──────┬───────────────┘
           │
           ├─── NO MATCH ──> ❌ "Fingerprint does not match!"
           │
           ▼ MATCH
    ┌──────────────────────┐
    │ Show "Checking       │
    │   location..."       │
    └──────┬───────────────┘
           │
           ▼
    ┌──────────────────────┐
    │ Get current GPS      │
    │   position           │
    └──────┬───────────────┘
           │
           ▼
    ┌──────────────────────┐
    │ Check GPS accuracy   │
    └──────┬───────────────┘
           │
           ├─── > 50m ──> ❌ "GPS accuracy too low"
           │
           ▼ < 50m
    ┌──────────────────────┐
    │ Calculate distance   │
    │  to site             │
    └──────┬───────────────┘
           │
           ├─── > 300m ──> ❌ "You are XXX meters away"
           │
           ▼ ≤ 300m
    ┌──────────────────────┐
    │ ✅ GEOFENCE PASSED   │
    └──────┬───────────────┘
           │
           ▼
    ┌──────────────────────┐
    │ Calculate contact    │
    │      time            │
    └──────┬───────────────┘
           │
           ▼
    ┌──────────────────────┐
    │ Update local DB:     │
    │ - Clock-out time     │
    │ - Contact time       │
    │ - GPS latitude       │
    │ - GPS longitude      │
    │ - GPS accuracy       │
    └──────┬───────────────┘
           │
           ▼
    ┌──────────────────────┐
    │ Sync to server       │
    │  (if online)         │
    └──────┬───────────────┘
           │
           ├─── OFFLINE ──> ℹ️ "Saved locally (will sync)"
           │
           ▼ ONLINE
    ┌──────────────────────┐
    │ ✅ "Clock-out synced │
    │    to server!"       │
    └──────────────────────┘
```

---

## Geofencing Validation Logic

```
┌─────────────────────────────────────────────────────────────────┐
│                  GEOFENCING VALIDATION                          │
└─────────────────────────────────────────────────────────────────┘

    ┌──────────────────────┐
    │ Get User Location    │
    │ (lat, lon, accuracy) │
    └──────┬───────────────┘
           │
           ▼
    ┌──────────────────────┐
    │ Accuracy < 50m?      │
    └──────┬───────────────┘
           │
           ├─── NO ──> ❌ FAIL: "GPS accuracy too low"
           │
           ▼ YES
    ┌──────────────────────┐
    │ Get Site Location    │
    │ from database        │
    └──────┬───────────────┘
           │
           ▼
    ┌──────────────────────┐
    │ Calculate Distance:  │
    │                      │
    │ d = R × acos(        │
    │   cos(lat1) ×        │
    │   cos(lat2) ×        │
    │   cos(lon2-lon1) +   │
    │   sin(lat1) ×        │
    │   sin(lat2)          │
    │ )                    │
    │                      │
    │ R = 6371000 (meters) │
    └──────┬───────────────┘
           │
           ▼
    ┌──────────────────────┐
    │ Distance ≤ 300m?     │
    └──────┬───────────────┘
           │
           ├─── NO ──> ❌ FAIL: "You are XXX meters away"
           │
           ▼ YES
    ┌──────────────────────┐
    │ ✅ PASS: Within      │
    │    geofence          │
    └──────────────────────┘
```

---

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      DATA FLOW                                  │
└─────────────────────────────────────────────────────────────────┘

    Flutter App                 PHP Backend              Database
    ───────────                 ───────────              ────────

    ┌──────────┐
    │ Get GPS  │
    │ Location │
    └────┬─────┘
         │
         ▼
    ┌──────────┐
    │ Validate │
    │ Geofence │
    └────┬─────┘
         │
         ▼ PASS
    ┌──────────┐
    │  Save    │
    │  Local   │
    │   DB     │
    └────┬─────┘
         │
         ▼
    ┌──────────┐                ┌──────────┐
    │   POST   │───────────────>│ clockin. │
    │   Data   │                │   php    │
    │          │                └────┬─────┘
    │ Payload: │                     │
    │ - LearnerID                    ▼
    │ - classID                 ┌──────────┐
    │ - user_latitude           │ Validate │
    │ - user_longitude          │  Input   │
    │ - user_accuracy           └────┬─────┘
    └──────────┘                     │
         ▲                           ▼
         │                      ┌──────────┐         ┌──────────┐
         │                      │  INSERT  │────────>│ learner_ │
         │                      │   INTO   │         │ clocking │
         │                      │          │         │  table   │
         │                      │ Fields:  │         └──────────┘
         │                      │ - clock_in_time
         │                      │ - user_latitude
         │                      │ - user_longitude
         │                      │ - user_accuracy
         │                      └────┬─────┘
         │                           │
         │                           ▼
         │                      ┌──────────┐
         │<─────────────────────│  Return  │
         │                      │   JSON   │
         │                      │ Response │
         │                      └──────────┘
         │
         ▼
    ┌──────────┐
    │  Update  │
    │   UI     │
    └──────────┘
```

---

## Security Layers

```
┌─────────────────────────────────────────────────────────────────┐
│                    SECURITY LAYERS                              │
└─────────────────────────────────────────────────────────────────┘

    Layer 1: Fingerprint Verification
    ──────────────────────────────────
    ┌──────────────────────────────────┐
    │ Biometric authentication         │
    │ - Matches stored template        │
    │ - Cannot be bypassed             │
    └──────────────────────────────────┘
                    │
                    ▼ PASS
    
    Layer 2: GPS Accuracy Check
    ───────────────────────────
    ┌──────────────────────────────────┐
    │ GPS signal quality               │
    │ - Must be < 50 meters            │
    │ - Ensures reliable location      │
    └──────────────────────────────────┘
                    │
                    ▼ PASS
    
    Layer 3: Geofencing Validation
    ───────────────────────────────
    ┌──────────────────────────────────┐
    │ Physical location check          │
    │ - Must be ≤ 300 meters           │
    │ - Calculated using Haversine     │
    └──────────────────────────────────┘
                    │
                    ▼ PASS
    
    Layer 4: Duplicate Check
    ────────────────────────
    ┌──────────────────────────────────┐
    │ Prevent double clock-in          │
    │ - Check existing records         │
    │ - One clock-in per day           │
    └──────────────────────────────────┘
                    │
                    ▼ PASS
    
    Layer 5: Audit Trail
    ────────────────────
    ┌──────────────────────────────────┐
    │ Complete logging                 │
    │ - GPS coordinates stored         │
    │ - Timestamps recorded            │
    │ - All attempts logged            │
    └──────────────────────────────────┘
                    │
                    ▼
            ✅ CLOCK-IN ALLOWED
```

---

## Error Handling Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    ERROR HANDLING                               │
└─────────────────────────────────────────────────────────────────┘

    Error Type                  User Message                Action
    ──────────                  ────────────                ──────

    No GPS Permission    ──>    "Location permissions      Request
                                 are denied"               permission

    GPS Disabled         ──>    "Please enable GPS"        Guide to
                                                           settings

    Poor GPS Signal      ──>    "GPS accuracy too low.     Wait for
                                 Please wait for better    better
                                 signal."                  signal

    Outside Geofence     ──>    "You are 450 meters       Show
                                 away. Must be within      distance
                                 300 meters."

    No Site Coords       ──>    "No site coordinates      Contact
                                 found for class X"        admin

    Already Clocked In   ──>    "Already clocked in       Show
                                 today at 08:30"           time

    Fingerprint Fail     ──>    "Fingerprint does not     Try
                                 match!"                   again

    Network Error        ──>    "Saved locally (will      Queue
                                 sync when online)"        for sync
```

---

## Legend

```
✅ = Success / Pass
❌ = Failure / Denied
ℹ️ = Information
──> = Flow direction
│   = Vertical flow
├── = Branch point
▼   = Continue down
```
