# ARPL Toolkit Viewer - Integration Guide

**Date:** July 8, 2026  
**Purpose:** Step-by-step guide to integrate the ARPL Toolkit Viewer into existing pages

---

## 📋 Overview

The ARPL Toolkit Viewer (`ArplToolkitViewerPage.dart`) is now ready to be integrated into your app. This guide shows you exactly where and how to add "View Toolkit" buttons and icons.

---

## 🎯 Integration Points

### 1. ARPL Assessor Page - After Appendix H Save ⭐ PRIMARY

**Location:** `lib/ArplAssessorPage.dart` or specific ARPL appendix pages

**When to Show:** After successfully saving Appendix H (Access Recommendation)

**Implementation:**

```dart
import 'ArplToolkitViewerPage.dart'; // Add at top of file

// After Appendix H is successfully saved, show success message with toolkit button
Widget _buildSuccessState() {
  return Column(
    children: [
      // Success icon
      const Icon(
        Icons.check_circle,
        color: Colors.green,
        size: 64,
      ),
      const SizedBox(height: 16),
      const Text(
        'Appendix H Saved Successfully!',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.green,
        ),
      ),
      const SizedBox(height: 24),
      // Action buttons
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // View Complete Toolkit button
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.description),
                label: const Text('View Complete Toolkit'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ArplToolkitViewerPage(
                        learnerID: _currentLearnerID, // Your learner ID variable
                        classID: _currentClassID,     // Your class ID variable
                        ofoNumber: '671101',          // Or dynamic OFO code
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006341),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          // Continue to Next Learner button (optional)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next Learner'),
                onPressed: () {
                  Navigator.pop(context); // Go back to learner list
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF006341),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}
```

---

### 2. ARPL Learner List - Context Menu or Icon

**Location:** Where you display lists of ARPL learners

**Implementation Option A: Trailing Icon Button**

```dart
import 'ArplToolkitViewerPage.dart'; // Add at top of file

ListTile(
  leading: CircleAvatar(
    backgroundColor: const Color(0xFF006341),
    child: Text(
      learner.name[0].toUpperCase(),
      style: const TextStyle(color: Colors.white),
    ),
  ),
  title: Text(learner.fullName),
  subtitle: Text('ID: ${learner.idNumber}'),
  trailing: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Existing icons (if any)
      // ...
      
      // View Toolkit Icon
      IconButton(
        icon: const Icon(Icons.assignment),
        color: const Color(0xFF006341),
        tooltip: 'View ARPL Toolkit',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ArplToolkitViewerPage(
                learnerID: learner.learnerID,
                classID: learner.classID,
                ofoNumber: '671101', // Or from learner qualification
              ),
            ),
          );
        },
      ),
    ],
  ),
  onTap: () {
    // Your existing onTap handler
  },
)
```

**Implementation Option B: Long Press Context Menu**

```dart
import 'ArplToolkitViewerPage.dart'; // Add at top of file

GestureDetector(
  onLongPress: () {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.assignment, color: Color(0xFF006341)),
              title: const Text('View ARPL Toolkit'),
              onTap: () {
                Navigator.pop(context); // Close bottom sheet
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ArplToolkitViewerPage(
                      learnerID: learner.learnerID,
                      classID: learner.classID,
                      ofoNumber: '671101',
                    ),
                  ),
                );
              },
            ),
            // Other menu items...
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Details'),
              onTap: () {
                // Your edit handler
              },
            ),
          ],
        ),
      ),
    );
  },
  child: ListTile(
    // Your existing list tile
  ),
)
```

---

### 3. SDP Dashboard - Learner Card Icon

**Location:** `lib/sdp_learners_page.dart` or similar SDP pages

**Implementation:**

```dart
import 'ArplToolkitViewerPage.dart'; // Add at top of file

Card(
  margin: const EdgeInsets.all(8.0),
  elevation: 2,
  child: Padding(
    padding: const EdgeInsets.all(12.0),
    child: Row(
      children: [
        // Learner Avatar
        CircleAvatar(
          radius: 30,
          backgroundColor: const Color(0xFF006341),
          child: Text(
            learner.name[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        
        // Learner Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                learner.fullName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'ID: ${learner.idNumber}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              if (learner.qualification != null)
                Text(
                  learner.qualification!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
            ],
          ),
        ),
        
        // Toolkit Icon Button
        Column(
          children: [
            IconButton(
              icon: const Icon(Icons.description_outlined),
              color: const Color(0xFF006341),
              iconSize: 28,
              tooltip: 'View Toolkit',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ArplToolkitViewerPage(
                      learnerID: learner.learnerID,
                      classID: learner.classID,
                      ofoNumber: learner.ofoCode ?? '671101',
                    ),
                  ),
                );
              },
            ),
            const Text(
              'Toolkit',
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFF006341),
              ),
            ),
          ],
        ),
      ],
    ),
  ),
)
```

---

### 4. Admin Search Results

**Location:** `lib/admin.dart` - Search results for learners

**Implementation:**

```dart
import 'ArplToolkitViewerPage.dart'; // Add at top of file

// In search results list
ExpansionTile(
  title: Text(learner.fullName),
  subtitle: Text('ID: ${learner.idNumber} | ${learner.qualification}'),
  children: [
    // Existing detail rows...
    
    // Add Toolkit Button
    Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Existing buttons...
          
          // View Toolkit button (only for ARPL learners)
          if (learner.pathwayType?.toUpperCase() == 'ARPL')
            ElevatedButton.icon(
              icon: const Icon(Icons.assignment, size: 18),
              label: const Text('View Toolkit'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ArplToolkitViewerPage(
                      learnerID: learner.learnerID,
                      classID: learner.classID,
                      ofoNumber: learner.ofoCode ?? '671101',
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006341),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
        ],
      ),
    ),
  ],
)
```

---

## 🔍 Conditional Display Logic

**Show Toolkit Button Only for ARPL Learners:**

```dart
// Helper method to check if learner is in ARPL pathway
bool _isArplLearner(Learner learner) {
  // Check pathway type
  if (learner.pathwayType?.toUpperCase().contains('ARPL') == true) {
    return true;
  }
  
  // Check qualification name
  if (learner.qualification?.toUpperCase().contains('ARPL') == true) {
    return true;
  }
  
  // Check OFO code (ARPL trades typically have specific OFO codes)
  final arplOfoCodes = ['671101', '671201', '671301']; // Add all ARPL OFO codes
  if (learner.ofoCode != null && arplOfoCodes.contains(learner.ofoCode)) {
    return true;
  }
  
  return false;
}

// Usage
if (_isArplLearner(learner))
  ElevatedButton.icon(
    icon: const Icon(Icons.assignment),
    label: const Text('View Toolkit'),
    onPressed: () {
      // Navigate to toolkit
    },
  )
```

---

## 📊 Testing Integration

### Test Checklist

1. **From ARPL Assessor Page:**
   - [ ] Complete Appendix H for test learner 20286
   - [ ] Verify "View Toolkit" button appears
   - [ ] Tap button and verify toolkit opens
   - [ ] Verify all data displays correctly
   - [ ] Use back button to return to assessor page

2. **From Learner List:**
   - [ ] Find learner 20286 in list
   - [ ] Tap toolkit icon
   - [ ] Verify toolkit opens with correct data
   - [ ] Return to list and try with different learner

3. **From SDP Dashboard:**
   - [ ] Find ARPL learner card
   - [ ] Tap toolkit icon
   - [ ] Verify correct learner's toolkit displays

4. **From Admin Search:**
   - [ ] Search for learner 20286
   - [ ] Expand search result
   - [ ] Tap "View Toolkit" button
   - [ ] Verify toolkit displays

---

## 🎨 Visual Consistency

### Button Styling Guide

**Primary Action Button (after save):**
```dart
ElevatedButton.styleFrom(
  backgroundColor: const Color(0xFF006341), // RLMS Green
  foregroundColor: Colors.white,
  padding: const EdgeInsets.symmetric(
    horizontal: 24,
    vertical: 12,
  ),
  textStyle: const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  ),
)
```

**Icon Button (in lists):**
```dart
IconButton(
  icon: const Icon(Icons.assignment), // or Icons.description_outlined
  color: const Color(0xFF006341),
  iconSize: 24,
  tooltip: 'View ARPL Toolkit',
  onPressed: () { /* ... */ },
)
```

**Text Button (secondary action):**
```dart
TextButton.icon(
  icon: const Icon(Icons.assignment),
  label: const Text('View Toolkit'),
  style: TextButton.styleFrom(
    foregroundColor: const Color(0xFF006341),
  ),
  onPressed: () { /* ... */ },
)
```

---

## 🚨 Error Handling

### Handle Missing Data Gracefully

```dart
// Before navigating to toolkit
void _openToolkit(int learnerID, int classID, String? ofoCode) {
  // Validate required data
  if (learnerID <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invalid learner ID'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }
  
  if (classID <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invalid class ID'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }
  
  // Navigate to toolkit
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ArplToolkitViewerPage(
        learnerID: learnerID,
        classID: classID,
        ofoNumber: ofoCode ?? '671101', // Default to Electrician
      ),
    ),
  );
}
```

---

## 📱 User Experience Tips

### 1. Add Loading Indicator for Navigation
```dart
void _openToolkitWithLoading(int learnerID, int classID, String ofoCode) async {
  // Show loading
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(
      child: CircularProgressIndicator(),
    ),
  );
  
  // Small delay to show user something is happening
  await Future.delayed(const Duration(milliseconds: 300));
  
  // Close loading
  Navigator.pop(context);
  
  // Navigate to toolkit
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ArplToolkitViewerPage(
        learnerID: learnerID,
        classID: classID,
        ofoNumber: ofoCode,
      ),
    ),
  );
}
```

### 2. Add Confirmation Before Navigation (Optional)
```dart
void _confirmOpenToolkit(int learnerID, int classID, String ofoCode) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('View ARPL Toolkit'),
      content: const Text(
        'This will display the complete ARPL toolkit with all saved assessments.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context); // Close dialog
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ArplToolkitViewerPage(
                  learnerID: learnerID,
                  classID: classID,
                  ofoNumber: ofoCode,
                ),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF006341),
          ),
          child: const Text('View Toolkit'),
        ),
      ],
    ),
  );
}
```

---

## 🔧 Quick Reference

### Minimum Required Parameters
```dart
ArplToolkitViewerPage(
  learnerID: 20286,          // Required: Learner's ID
  classID: 1,                // Required: Class ID
  ofoNumber: '671101',       // Optional: Defaults to 671101 (Electrician)
)
```

### Common Icon Options
- `Icons.assignment` - Clipboard with lines (professional)
- `Icons.description` - Document icon (formal)
- `Icons.description_outlined` - Outlined document (subtle)
- `Icons.article` - Article/paper icon (modern)
- `Icons.library_books` - Books icon (educational)

### Color Palette
- **RLMS Green:** `Color(0xFF006341)` - Primary brand color
- **Success Green:** `Colors.green` - Positive actions
- **Warning Amber:** `Colors.amber` - Cautions
- **Error Red:** `Colors.red` - Errors, negative responses

---

## ✅ Integration Checklist

- [ ] Import `ArplToolkitViewerPage.dart` in target file
- [ ] Add button/icon in appropriate location
- [ ] Pass correct `learnerID` parameter
- [ ] Pass correct `classID` parameter
- [ ] Pass correct `ofoNumber` (or use default)
- [ ] Test navigation works
- [ ] Test back button returns correctly
- [ ] Verify data displays properly
- [ ] Check error handling works
- [ ] Test with multiple learners
- [ ] Verify conditional display (ARPL only)

---

## 🎉 You're Ready!

The ARPL Toolkit Viewer is now fully integrated and ready to use. Follow the examples above to add access points throughout your app.

**Need Help?**
- Check `ARPL_TOOLKIT_FLUTTER_COMPLETE.md` for full documentation
- Test with learner ID 20286 (has complete saved data)
- Verify API endpoint is accessible: `AppConfig.getArplToolkitDataUrl`

---

**Happy Integrating! 🚀**
