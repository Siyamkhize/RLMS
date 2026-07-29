# ARPL Toolkit Flutter Implementation Plan

## Objective
Create a Flutter page (`ArplToolkitViewerPage.dart`) that displays the complete ARPL Toolkit with all saved data, matching the structure and functionality of `mobile/arpl_toolkit_dynamic.php`.

---

## Page Structure

### Main Components
1. **Cover Page** - DHET logo, trade title, learner info
2. **Contents Page** - Navigation to all appendices
3. **Appendix A** - Application Form (prefilled)
4. **Appendix B** - Self-Evaluation (saved ratings 1-5)
5. **Appendix C** - Trade Curriculum (unit standards)
6. **Appendix D** - Practical Skills (saved yes/no)
7. **Appendix E** - Workplace Experience (saved ratings 1-5)
8. **Appendix F** - Assessment Evaluation Agreement
9. **Appendix G** - Appeals Form
10. **Appendix H** - Access Recommendation System

---

## Data Loading Architecture

### Backend API Endpoint
Create: `mobile/get_arpl_toolkit_data.php`

**Purpose:** Single API that returns ALL toolkit data for a learner

**Request:**
```json
{
  "learnerID": 20286,
  "classID": 123,
  "ofo_number": "671101"
}
```

**Response:**
```json
{
  "status": "success",
  "learner": {
    "LearnerID": 20286,
    "Name": "John",
    "Surname": "Doe",
    "IDNumber": "9001015800080",
    "Email": "john@example.com",
    ...
  },
  "facilitator": {
    "firstName": "Jane",
    "lastName": "Smith",
    "assessorNo": "ASS12345"
  },
  "class_info": {
    "className": "Electrician Class A",
    "siteName": "Training Site 1",
    ...
  },
  "appendixB": [
    {
      "activity_id": 1,
      "activity_name": "Safety",
      "competency_scale_id": 4,
      "comments": "Good understanding",
      "rating_date": "2026-07-01"
    }
  ],
  "appendixD": {
    "activity_1": "yes",
    "activity_2": "no",
    ...
  },
  "appendixE": [
    {
      "activity_id": 1,
      "activity_name": "OHS compliance",
      "competency_scale_id": 5,
      "comments": "Excellent",
      "rating_date": "2026-07-05"
    }
  ],
  "appendixH": {
    "items": [
      {
        "ACRID": 1,
        "assessment_item": "Knowledge Assessment"
      }
    ],
    "recommendation": {
      "knowledge_assessment": "Competent",
      "practical_assessment": "Competent",
      "workplace_observation": "Competent",
      "overall_result": "Recommended for trade test"
    },
    "gap_standards": [],
    "trade_test": {
      "recommended_date": "2026-07-08"
    }
  }
}
```

---

## Flutter Implementation

### File: `lib/ArplToolkitViewerPage.dart`

**Features:**
1. ✅ Loads all toolkit data via single API call
2. ✅ PageView with swipeable appendices
3. ✅ Table of contents with navigation
4. ✅ Print/PDF export button
5. ✅ Share functionality
6. ✅ Offline caching support

**Widgets Structure:**
```
ArplToolkitViewerPage (StatefulWidget)
├── AppBar (Title, Actions: Print, Share)
├── PageView.builder
│   ├── CoverPage
│   ├── ContentsPage
│   ├── AppendixAPage
│   ├── AppendixBPage (with saved ratings)
│   ├── AppendixCPage
│   ├── AppendixDPage (with saved yes/no)
│   ├── AppendixEPage (with saved ratings)
│   ├── AppendixFPage
│   ├── AppendixGPage
│   └── AppendixHPage (with recommendation)
└── BottomNavigationBar (Previous/Next)
```

---

## Key Features

### 1. Visual Styling
- **Saved ratings:** Green checkmarks with "Competent" badge
- **Saved comments:** Green italic text
- **Yes/No indicators:** Green check / Red cross
- **Professional layout:** Match PHP toolkit design

### 2. Navigation
- Swipe left/right between appendices
- Table of contents with direct navigation
- Bottom bar: "Previous" and "Next" buttons
- Page indicator dots

### 3. Export Options
- **Print to PDF:** Using `printing` package
- **Share PDF:** Using `share_plus` package
- **Save locally:** Store PDF in device

### 4. Offline Support
- Cache toolkit data in SQLite
- Load from cache when offline
- Sync indicator showing data freshness

---

## Data Models

### `ArplToolkitData` Model
```dart
class ArplToolkitData {
  final LearnerDetails learner;
  final FacilitatorDetails facilitator;
  final ClassInfo classInfo;
  final List<AppendixBRating> appendixB;
  final AppendixDResponses appendixD;
  final List<AppendixERating> appendixE;
  final AppendixHData appendixH;
  
  factory ArplToolkitData.fromJson(Map<String, dynamic> json);
}
```

### `AppendixBRating` Model
```dart
class AppendixBRating {
  final int activityId;
  final String activityName;
  final int competencyScaleId;
  final String comments;
  final DateTime ratingDate;
  
  factory AppendixBRating.fromJson(Map<String, dynamic> json);
}
```

### Similar models for D, E, and H

---

## PDF Generation

### Using `pdf` and `printing` packages

**Features:**
- Multi-page PDF with all appendices
- Professional formatting matching PHP version
- Include learner photo if available
- Digital signatures if captured
- Watermark with provider name

**Code Structure:**
```dart
Future<pw.Document> generateToolkitPDF(ArplToolkitData data) async {
  final pdf = pw.Document();
  
  // Add cover page
  pdf.addPage(_buildCoverPage(data));
  
  // Add all appendices
  pdf.addPage(_buildAppendixB(data));
  pdf.addPage(_buildAppendixD(data));
  pdf.addPage(_buildAppendixE(data));
  pdf.addPage(_buildAppendixH(data));
  
  return pdf;
}
```

---

## Implementation Steps

### Phase 1: Backend API (30 mins)
1. ✅ Create `mobile/get_arpl_toolkit_data.php`
2. ✅ Consolidate all data loading queries
3. ✅ Return comprehensive JSON response
4. ✅ Test with learner 20286

### Phase 2: Data Models (20 mins)
1. ✅ Create `ArplToolkitData` model class
2. ✅ Create models for each appendix
3. ✅ Add JSON parsing methods
4. ✅ Add validation

### Phase 3: UI Pages (60 mins)
1. ✅ Create main `ArplToolkitViewerPage`
2. ✅ Build cover page widget
3. ✅ Build contents page widget
4. ✅ Build Appendix B page (with saved ratings)
5. ✅ Build Appendix D page (with yes/no)
6. ✅ Build Appendix E page (with ratings)
7. ✅ Build Appendix H page (with recommendation)

### Phase 4: PDF Generation (40 mins)
1. ✅ Add `pdf` and `printing` packages
2. ✅ Implement PDF generation methods
3. ✅ Add print button
4. ✅ Add share functionality

### Phase 5: Testing (20 mins)
1. ✅ Test with learner 20286
2. ✅ Verify all appendices display correctly
3. ✅ Test PDF generation
4. ✅ Test offline mode

**Total Estimated Time:** 2.5 - 3 hours

---

## Dependencies to Add

```yaml
dependencies:
  pdf: ^3.10.8
  printing: ^5.12.0
  share_plus: ^7.2.2
  path_provider: ^2.1.2
```

---

## Config.dart Updates

Add new endpoint:

```dart
class Config {
  // ... existing endpoints
  
  static String getArplToolkitDataUrl = 
    '${baseUrl}mobile/get_arpl_toolkit_data.php';
}
```

---

## Usage Flow

1. **From ARPL Assessor Page:**
   - After completing Appendix H (Access Recommendation)
   - Button: "View Complete Toolkit"
   - Opens `ArplToolkitViewerPage`

2. **From Learner List:**
   - Long-press on learner
   - Context menu: "View ARPL Toolkit"
   - Opens toolkit if data exists

3. **From SDP Dashboard:**
   - Learner card has "Toolkit" icon
   - Opens toolkit viewer

---

## Advantages Over PHP Version

1. ✅ **Native mobile experience** - Better UX on phones/tablets
2. ✅ **Offline support** - View toolkit without internet
3. ✅ **Better performance** - No web page loading
4. ✅ **Native PDF** - Better quality, faster generation
5. ✅ **Easy sharing** - Native share sheet
6. ✅ **Touch-optimized** - Swipe navigation, pinch-zoom

---

## Future Enhancements

1. **Digital Signatures:** Capture signatures on device
2. **Photo Integration:** Include learner/assessor photos
3. **Multi-language:** Support multiple languages
4. **Email Direct:** Send toolkit via email from app
5. **Version History:** View previous toolkit versions
6. **Comparison View:** Compare before/after ratings

---

**Status:** Ready for implementation  
**Priority:** High - Completes ARPL mobile workflow  
**Complexity:** Medium - Well-defined data structures
