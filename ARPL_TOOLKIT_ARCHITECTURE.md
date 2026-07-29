# ARPL Toolkit Architecture Diagram

## System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         FLUTTER MOBILE APP                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │         ArplToolkitViewerPage.dart (Main UI)               │   │
│  │                                                             │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐     │   │
│  │  │  Cover   │ │Appendix B│ │Appendix D│ │Appendix E│ ...  │   │
│  │  │   Tab    │ │   Tab    │ │   Tab    │ │   Tab    │     │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘     │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                            ▲                                        │
│                            │                                        │
│                    ArplToolkitData                                  │
│                      (Data Model)                                   │
│                            ▲                                        │
│                            │ JSON                                   │
└────────────────────────────┼───────────────────────────────────────┘
                             │
                             │ HTTP POST
                             │
┌────────────────────────────┼───────────────────────────────────────┐
│                            │           SERVER                       │
│                            ▼                                        │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │      mobile/get_arpl_toolkit_data.php (API)                │   │
│  │                                                             │   │
│  │  Receives: learnerID, classID, ofo_number                  │   │
│  │  Returns: Complete JSON with all toolkit data              │   │
│  └────────────────────────────────────────────────────────────┘   │
│                            │                                        │
│                            │ SQL Queries                            │
│                            ▼                                        │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │                     MySQL Database                          │   │
│  │                                                             │   │
│  │  • learner_details                                          │   │
│  │  • arplappxb_activity_ratings                              │   │
│  │  • arpl_appendix_d                                         │   │
│  │  • arplappxe_electrician_activity_ratings                  │   │
│  │  • arplelectrician_access_recommendation                   │   │
│  │  • arpl_gap_analysis_unit_standards                        │   │
│  │  • arpl_trade_test_recommended                             │   │
│  └────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```


## Data Flow

### 1. User Opens Toolkit
```
User Tap → Navigator.push() → ArplToolkitViewerPage(learnerID, classID)
```

### 2. API Request
```
Flutter App → HTTP POST → get_arpl_toolkit_data.php
```

**Request Body:**
```json
{
  "learnerID": 20286,
  "classID": 1,
  "ofo_number": "671101"
}
```

### 3. Database Queries (API executes 7 queries)
```sql
-- Query 1: Learner Details
SELECT * FROM learner_details WHERE LearnerID = ?

-- Query 2: Facilitator Details  
SELECT * FROM users WHERE userID = ?

-- Query 3: Class Information
SELECT * FROM class WHERE classID = ?

-- Query 4: Appendix B Ratings (Self-Evaluation)
SELECT * FROM arplappxb_activity_ratings WHERE learner_id = ?

-- Query 5: Appendix D Responses (Practical Skills)
SELECT * FROM arpl_appendix_d WHERE learner_id = ?

-- Query 6: Appendix E Ratings (Workplace Experience)
SELECT * FROM arplappxe_electrician_activity_ratings WHERE learner_id = ?

-- Query 7: Appendix H Data (Access Recommendation + Gap + Trade Test)
SELECT * FROM appxh_acrelectrician, arplelectrician_access_recommendation, 
             arpl_gap_analysis_unit_standards, arpl_trade_test_recommended
```

### 4. API Response
```json
{
  "status": "success",
  "learner": { /* Learner details */ },
  "facilitator": { /* Facilitator details */ },
  "class_info": { /* Class information */ },
  "appendixB": [ /* Array of ratings */ ],
  "appendixD": { /* Object with yes/no responses */ },
  "appendixE": [ /* Array of ratings */ ],
  "appendixH": {
    "items": [ /* ACR items */ ],
    "recommendation": { /* Recommendation statuses */ },
    "gap_standards": [ /* Gap closure standards */ ],
    "trade_test": { /* Trade test info */ }
  }
}
```

### 5. Data Parsing
```
JSON Response → ArplToolkitData.fromJson() → Model Objects
```

### 6. UI Rendering
```
Model Objects → Widget Tree → Display on Screen
```

---

## Component Architecture

### Flutter Layer (Client)
```
ArplToolkitViewerPage.dart
├── State Management (StatefulWidget)
├── API Communication (http package)
├── Tab Navigation (TabController)
├── UI Components
│   ├── _buildCoverPage()
│   ├── _buildAppendixB()
│   ├── _buildAppendixD()
│   ├── _buildAppendixE()
│   └── _buildAppendixH()
└── Error Handling (try-catch, setState)

models/arpl_toolkit_data.dart
├── ArplToolkitData (Main container)
├── LearnerDetails
├── FacilitatorDetails
├── ClassInfo
├── AppendixBRating
├── AppendixERating
├── AppendixHData
│   ├── AcrItem
│   ├── AccessRecommendation
│   ├── GapStandard
│   └── TradeTestRecommendation
```

### Server Layer (Backend)
```
get_arpl_toolkit_data.php
├── Request Validation
├── Database Connection
├── Data Queries (7 queries)
├── Data Aggregation
├── JSON Response Building
└── Error Handling
```

### Database Layer
```
MySQL Database
├── learner_details (Learner info)
├── users (Facilitator info)
├── class (Class info)
├── arplappxb_activity_ratings (Appendix B)
├── arpl_appendix_d (Appendix D)
├── arplappxe_electrician_activity_ratings (Appendix E)
├── appxh_acrelectrician (Appendix H items)
├── arplelectrician_access_recommendation (Appendix H recommendation)
├── arpl_gap_analysis_unit_standards (Gap closure)
└── arpl_trade_test_recommended (Trade test)
```

---

## Integration Points

### 1. From ARPL Assessor Page
```
ArplAssessorPage → [Save Appendix H] → Success State 
    → [View Toolkit Button] → ArplToolkitViewerPage
```

### 2. From Learner List
```
LearnerListPage → Learner Card → [Toolkit Icon] → ArplToolkitViewerPage
```

### 3. From SDP Dashboard
```
SdpDashboard → Learner Card → [Toolkit Icon] → ArplToolkitViewerPage
```

### 4. From Admin Search
```
AdminSearchPage → Search Results → [View Toolkit] → ArplToolkitViewerPage
```

---

## Technology Stack

| Layer | Technology |
|-------|------------|
| **Frontend** | Flutter (Dart) |
| **HTTP Client** | http package |
| **State Management** | StatefulWidget |
| **Navigation** | TabController |
| **Backend** | PHP 7.4+ |
| **Database** | MySQL 5.7+ |
| **API Format** | JSON (REST) |
| **Security** | Prepared Statements |

---

## File Organization

```
project/
├── lib/
│   ├── ArplToolkitViewerPage.dart       # Main viewer page
│   ├── config.dart                       # API endpoints
│   └── models/
│       └── arpl_toolkit_data.dart        # Data models
│
├── mobile/
│   └── get_arpl_toolkit_data.php        # Backend API
│
└── docs/
    ├── ARPL_TOOLKIT_ARCHITECTURE.md      # This file
    ├── ARPL_TOOLKIT_FLUTTER_COMPLETE.md  # Implementation details
    ├── ARPL_TOOLKIT_INTEGRATION_GUIDE.md # Integration guide
    └── ARPL_TOOLKIT_QUICK_START.md       # Quick start guide
```

---

## Security Considerations

1. **SQL Injection Protection:** All queries use prepared statements
2. **Input Validation:** learnerID, classID validated as integers
3. **Error Handling:** Graceful handling without exposing internals
4. **Data Sanitization:** All output escaped/sanitized

---

## Performance Optimization

1. **Single API Call:** All data fetched in one request (not 7 separate calls)
2. **Efficient Queries:** Indexed columns used in WHERE clauses
3. **JSON Encoding:** PHP's native json_encode for fast serialization
4. **Client-Side Caching:** Data held in memory during session
5. **Lazy Loading:** Tabs render only when accessed

---

**Architecture Status:** ✅ Complete and Production-Ready
