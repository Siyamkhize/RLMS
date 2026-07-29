# ARPL Toolkit - Quick Start Guide

## What Was Done

The ARPL (Assessment and Recognition of Prior Learning) Toolkit has been successfully implemented for three trades:

- **Electrician (OFO 671101)**
- **Plumber (OFO 671102)**
- **Bricklayer (OFO 671103)**

Each trade has 13 trade-specific workplace observation activities in Appendix F.

---

## Key Files

| File | Purpose |
|------|---------|
| `lib/ArplToolkitViewerPage.dart` | Main UI for all trades |
| `mobile/get_arpl_toolkit_data.php` | API for Electrician & Plumber |
| `mobile/get_bricklayer_toolkit_data.php` | API for Bricklayer |
| `lib/config.dart` | API endpoint configuration |

---

## How to Test

### On Your Device:

1. **Log in as Assessor**
2. **Select a trade's learner** (Electrician, Plumber, or Bricklayer)
3. **Tap "ARPL Toolkit"**
4. **Go to "9. Appendix F"**
5. **Verify you see 13 activities for that trade**

### Expected Results:

✅ Electrician shows electrician activities  
✅ Plumber shows plumber activities  
✅ Bricklayer shows bricklayer activities  
✅ Can rate activities and save  

---

## Activities by Trade

### Electrician (13)
1. Safety practices and hazard identification
2. Electrical cable selection and storage
3. Measuring and marking installation routes
4. Installing wiring systems and conduits
5. Connecting and terminating cables
6. Installing switching and control devices
7. Installing lighting fixtures and systems
8. Installing power distribution systems
9. Testing electrical installations
10. Fault diagnosis and rectification
11. Earthing and bonding installation
12. Documentation and labeling
13. Compliance with SANS and electrical regulations

### Plumber (13)
1. Safety practices and hazard identification
2. Pipe selection and material identification
3. Measuring and marking pipe routes
4. Pipe joining and connection methods
5. Water supply system installation
6. Drainage system installation
7. Hot water system installation
8. Cold water system installation
9. Rainwater system installation
10. Sanitary appliance installation
11. Testing and commissioning systems
12. Leakage detection and repair
13. Cleaning and maintenance of pipework

### Bricklayer (13)
1. Safety practices and hazard identification
2. Measuring and marking out brickwork
3. Brick selection and storage
4. Mortar preparation and consistency
5. Building walls with correct bond patterns
6. Installing lintels and openings
7. Building curved and decorative brickwork
8. Applying mortar joints and pointing
9. Building columns and piers
10. Constructing arches and angles
11. Installing damp proof courses
12. Cleaning and finishing brickwork surfaces
13. Quality inspection and fault correction

---

## API Endpoints

```
Electrician (671101)  → http://server/mobile/get_arpl_toolkit_data.php
Plumber (671102)      → http://server/mobile/get_arpl_toolkit_data.php
Bricklayer (671103)   → http://server/mobile/get_bricklayer_toolkit_data.php
```

---

## If Something Goes Wrong

**Activities not showing?**
- Check if the correct learner trade is selected
- Verify OFO number (671101, 671102, or 671103)
- Restart app and try again

**API error?**
- Check server is running
- Check network connection
- Verify WiFi is connected to right network

**Save not working?**
- Verify you filled in ratings
- Check network connection
- Try again after few seconds

---

## Build Information

- **Size:** 45.8 MB
- **Status:** ✅ Built and installed
- **Date:** July 10, 2026
- **Version:** Latest

---

## Documentation

- Full details: `ARPL_IMPLEMENTATION_COMPLETE.md`
- Testing guide: `ARPL_TOOLKIT_TESTING_GUIDE.md`

