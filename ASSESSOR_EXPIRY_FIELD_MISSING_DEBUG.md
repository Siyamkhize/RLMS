# Assessor Expiry Date Field Missing - Debug Guide

## 🔍 **Issue**: Field Not Showing Up

The assessor certificate expiry date field is not visible in the form.

## 🧪 **Debug Steps to Check**

### Step 1: Check Edit Mode
**The field only shows when in EDIT MODE**

1. **Open FacilitatorProfile page**
2. **Tap the EDIT button** (pencil icon in the top-right corner)
3. **Look for the field** in the "Contact Information" section

**Expected**: Field should appear after "Assessor Number" field

### Step 2: Check Debug Logs
Look for these messages in Flutter console:

```
[PROFILE] Building date picker field: Assessor Certificate Expiry Date, isEditing: true, controller value: "..."
```

**If you DON'T see this log**: The field is not being rendered at all
**If you DO see this log**: The field is being built but might be hidden

### Step 3: Look for Yellow Background
I've added a **bright yellow background** to the field temporarily for testing.

**Expected**: You should see a yellow box with the date picker field inside

### Step 4: Check Field Position
The field should appear in this order:
1. Phone Number
2. ID Number  
3. Assessor Number
4. **→ Assessor Certificate Expiry Date** ← Should be here
5. (End of Contact Information section)

## 🔧 **Possible Issues & Solutions**

### Issue 1: Not in Edit Mode
**Symptom**: Field not visible at all
**Solution**: Tap the edit button (pencil icon) first

### Issue 2: Form Validation Error
**Symptom**: Field exists but form won't render
**Solution**: Check Flutter console for validation errors

### Issue 3: Controller Issue
**Symptom**: Field renders but doesn't work
**Solution**: Check debug logs for controller values

### Issue 4: Layout Issue
**Symptom**: Field is there but pushed off screen
**Solution**: Scroll down in the Contact Information section

## 🎯 **Quick Test**

1. **Open the app**
2. **Go to FacilitatorProfile**
3. **Tap EDIT button** (pencil icon)
4. **Scroll to Contact Information section**
5. **Look for YELLOW background** (temporary test color)
6. **Check Flutter console** for debug messages

## 📱 **Expected Appearance**

When working correctly, you should see:

```
Contact Information
├── Phone Number: [text field]
├── ID Number: [text field]  
├── Assessor Number: [text field]
└── Assessor Certificate Expiry Date: [YELLOW date picker field] ← This one
```

## 🚨 **If Still Not Visible**

If the field is still not showing up after checking edit mode:

1. **Hot restart** the Flutter app
2. **Check for any error messages** in console
3. **Try scrolling down** in the form
4. **Look for the yellow background** (temporary test indicator)

## 📋 **Debug Checklist**

- [ ] Tapped edit button (pencil icon)
- [ ] Scrolled through Contact Information section
- [ ] Looked for yellow background color
- [ ] Checked Flutter console for debug logs
- [ ] Tried hot restart
- [ ] No error messages in console

The field should be there with a bright yellow background for easy identification. If you still can't see it, there might be a deeper layout or rendering issue.