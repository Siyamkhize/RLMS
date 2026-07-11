# ARPL PDF Generation - Testing Guide

**Date**: July 11, 2026  
**Status**: Ready for Testing  
**Version**: 2.0 - Format Fixes Complete

---

## Quick Start

### Test URL (Frontend)
```
http://localhost/rlmss/web/generate_pdf.php?learnerID=20286&ofo_code=671101
```

### Test via API (cURL)
```bash
curl -X POST http://localhost/rlmss/web/api/generate_arpl_pdf.php \
  -H "Content-Type: application/json" \
  -d '{
    "learnerID": 20286,
    "ofo_code": "671101"
  }'
```

---

## Test Cases

### Test Case 1: Electrician (Learner 20286)
**Expected**: ✅ PASS - Cover page visible, all appendices formatted

```
Learner ID: 20286
Trade: Electrician
OFO Code: 671101
Theory Activities: 22 (should display in Appendix B)
Workplace Activities: 14 (should display in Appendix E)
```

**What to Check**:
- ✅ Page 1 (Cover Page) - Visible with learner info and gradient background
- ✅ Page 2 - Checklist visible
- ✅ Page 3 - Learner information table
- ✅ Pages 4-6 - Supporting documents section
- ✅ Pages 7-8 - Appendix B with theory competency grid
- ✅ Pages 9-10 - Appendix E with workplace activities grid
- ✅ Page 11 - Appendix H with ACR decision form
- ✅ Pages 12-20 - All appendices with proper table formatting
- ✅ Pages 21-24 - Evidence and conclusion sections

**Expected Output**:
```json
{
  "status": "success",
  "file": "ARPL_Portfolio_20286_[timestamp].html",
  "learnerID": 20286,
  "message": "PDF generated successfully"
}
```

---

### Test Case 2: Bricklaying (Learner with OFO 641201)
**Expected**: ✅ PASS - Format matches, uses bricklaying-specific tables

```
Find a learner with OFO 641201 and test:
http://localhost/rlmss/web/generate_pdf.php?learnerID=[ID]&ofo_code=641201
```

**What to Check**:
- ✅ Cover page shows "Bricklaying" as trade name
- ✅ Appendices query `arplappxb_bricklaying_*` tables
- ✅ All formats still match mobile app

---

### Test Case 3: Plumbing (Learner with OFO 642601)
**Expected**: ✅ PASS - Format matches, uses plumbing-specific tables

```
Find a learner with OFO 642601 and test:
http://localhost/rlmss/web/generate_pdf.php?learnerID=[ID]&ofo_code=642601
```

**What to Check**:
- ✅ Cover page shows "Plumbing" as trade name
- ✅ Appendices query `arplappxb_plumbing_*` tables
- ✅ All formats match mobile app

---

## Visual Verification Checklist

### Cover Page (Page 1)
- [ ] Purple gradient background visible
- [ ] "ARPL PORTFOLIO" title centered
- [ ] "Recognition of Prior Learning" subtitle visible
- [ ] Trade name in large text
- [ ] OFO code displayed
- [ ] Learner information box visible
  - [ ] Name and surname
  - [ ] Learner ID
  - [ ] ID Number
  - [ ] Portfolio Generated date
- [ ] Footer text visible at bottom
- [ ] Page fully renders (not cut off)

### Appendix A - Application Form (Page 12)
- [ ] Header table with Document/Trade/Test Centre info
- [ ] Applicant details section filled
- [ ] Physical/Postal address two-column layout
- [ ] Contact details table
- [ ] Employment status checkboxes visible
- [ ] Employment history table with rows
- [ ] Signature line for candidate

### Appendix B - Theory Self-Evaluation (Pages 7-8)
- [ ] Competency proficiency scale table (1-5)
- [ ] Theory knowledge grid with 7 knowledge areas
- [ ] Checkboxes (☐) for rating selections
- [ ] 1-5 rating columns visible
- [ ] Signature and date fields

### Appendix D - Practical Skills (Page 12)
- [ ] All 22 activities listed
- [ ] Two-column layout (1-11, 12-22)
- [ ] Checkboxes for rating each activity
- [ ] Professional spacing

### Appendix E - Workplace Experience (Pages 9-10)
- [ ] 8 workplace activities listed
- [ ] 1-5 rating grid with checkboxes
- [ ] Activities: Planning, Materials, Tools, Quality, Safety, Communication, Problem Solving, Work Completion
- [ ] Supervisor comments section
- [ ] Supervisor signature block

### Appendix F - Assessment Agreement (Page 13)
- [ ] 5 assessment components listed
- [ ] Acknowledged/Not Acknowledged columns
- [ ] Checkboxes for each
- [ ] Learner declaration text
- [ ] Learner signature section
- [ ] Assessor acknowledgement section

### Appendix G - Appeals Form (Page 14)
- [ ] Appeal status checkboxes
- [ ] Appeal date field
- [ ] Grounds for appeal text area
- [ ] Assessor response section
- [ ] Learner feedback section
- [ ] Signature and date fields

### Appendix H - ACR Decision Form (Page 11)
- [ ] Learner information summary
- [ ] ACR Decision: Approved/Conditionally Approved/Not Approved checkboxes
- [ ] Competency level 1-5 options
- [ ] Recommendation: Certification/Gap Closure/Reject options
- [ ] Assessor remarks section
- [ ] Assessor certification with signature

### Appendix I - Statement of Results (Page 14)
- [ ] Assessment results table with Pass/Fail checkboxes
- [ ] Mark/Rating column
- [ ] Overall result section
- [ ] Competency rating 1-5 scale
- [ ] Assessor certification section

---

## Format Validation

### Mobile App Format Matching
- [ ] All appendices use tables (not paragraphs)
- [ ] Prefilled fields have background color
- [ ] Checkboxes (☐) used for selections
- [ ] Professional spacing and alignment
- [ ] Same hierarchy as mobile app
- [ ] Two-column layouts where appropriate

### CSS Rendering
- [ ] Cover page gradient visible
- [ ] All borders and lines render correctly
- [ ] Font sizes consistent
- [ ] Page breaks work properly
- [ ] Print layout looks professional

### Data Population
- [ ] Learner name and ID filled correctly
- [ ] Trade name matches OFO code
- [ ] Trade-specific data appears (if available in DB)
- [ ] Dates formatted correctly
- [ ] All HTML properly escaped (no encoding issues)

---

## Troubleshooting

### Issue: Cover Page Not Visible
**Solution**: Already fixed in v2.0
- Changed CSS from `display: flex` to `display: block`
- Removed problematic `margin-top/bottom: auto`
- Used explicit height and positioning

### Issue: Appendix Data Not Displaying
**Likely Cause**: Database tables don't have data for learner
**Solution**: 
- Check if `arpl_appendix_a`, `arpl_appendix_c`, etc. have records for learner
- Check if trade-specific tables exist: `arplappxb_[trade]_activities`

### Issue: Trade Not Recognized
**Likely Cause**: OFO code not in supported list
**Solution**: 
Supported trades:
- 671101 = Electrician
- 641201 = Bricklaying
- 642601 = Plumbing
- 651302 = Welding

### Issue: PDF File Not Created
**Likely Cause**: Missing `/web/pdfs` directory
**Solution**: System creates directory automatically, but check permissions

---

## Performance Notes

- **Generation Time**: 2-5 seconds (depending on database query speed)
- **File Size**: ~500KB-1MB (HTML file)
- **Browser**: Any modern browser can view/print as PDF
- **Print Quality**: 300 DPI recommended for printing

---

## Browser Print to PDF

After opening the PDF HTML file:

1. **Chrome/Edge**:
   - Press `Ctrl+P`
   - Select "Save as PDF"
   - Choose location and save

2. **Firefox**:
   - Press `Ctrl+P`
   - Change printer to "Print to File"
   - Save as PDF

3. **Safari**:
   - Press `Cmd+P`
   - Click "PDF" dropdown
   - Select "Save as PDF"

---

## Validation Checklist

After testing all cases, verify:

- [ ] Cover page is visible and properly formatted
- [ ] All 24 pages render correctly
- [ ] Appendices match mobile app format exactly
- [ ] All three trades work (Electrician, Bricklaying, Plumbing)
- [ ] No HTML encoding issues
- [ ] Database queries don't error
- [ ] File is created in `/web/pdfs` directory
- [ ] File can be downloaded and printed
- [ ] Signature lines are present for handwritten entries
- [ ] All form elements are visible and properly spaced
- [ ] Professional appearance for assessor review

---

## Expected Results

✅ **Success**: 
- PDF generates in 2-5 seconds
- Cover page fully visible
- All appendices formatted professionally
- 24 pages complete
- Matches mobile app format exactly
- Ready for assessor to print and use for evaluation

❌ **Failure**: 
- Cover page not visible
- Appendices show as plain text
- Missing pages
- Formatting doesn't match mobile app
- Database errors in logs

---

## Next Steps After Testing

1. ✅ Verify all test cases pass
2. ✅ Check file browser viewing
3. ✅ Test printing to actual PDF (wkhtmltopdf integration optional)
4. ✅ Verify with assessors that format matches expectations
5. ✅ Deploy to production if all tests pass

---

**Status**: READY FOR TESTING ✅  
**Date**: July 11, 2026
