# ARPL Application Form Data - Integration Guide

## Overview

The ARPL PDF generator now has complete application form data for learner 16389 (Lungisani Cele), including employment history, references, and qualifications. This guide shows how to integrate this data into the PDF template.

---

## Data Structure

### Available Data Variables

After loading, these PHP variables contain the application data:

```php
$arplApplication        // Main application record
$arplWorkExperience[]   // Array of work history (3 records)
$arplReferences[]       // Array of contacts (3 records)
$arplQualifications[]   // Array of qualifications (3 records)
```

### Application Record Fields

```php
$arplApplication['id']                      // 4
$arplApplication['id_number']               // 0208095509088
$arplApplication['first_name']              // Lungisani
$arplApplication['last_name']               // Cele
$arplApplication['date_of_birth']           // 1989-02-08
$arplApplication['gender']                  // Male
$arplApplication['email']                   // lungisani.cele@example.com
$arplApplication['phone']                   // 0790131055
$arplApplication['street_address']          // 123 Main Street
$arplApplication['city']                    // Johannesburg
$arplApplication['postal_code']             // 2000
$arplApplication['province']                // Gauteng
$arplApplication['trade_applied_for']       // Plumbing
$arplApplication['total_years_of_experience']  // 15
$arplApplication['highest_qualification']   // Grade 12
$arplApplication['application_status']      // Submitted
$arplApplication['eligibility_status']      // Eligible
$arplApplication['application_date']        // 2026-07-11
```

---

## Template Code Examples

### 1. Applicant Details Section

```html
<table class="ft">
  <tr>
    <td style="width:38%;"><b>Full Name</b></td>
    <td>
      <span class="prefilled">
        <?= htmlspecialchars($arplApplication['first_name'] . ' ' . $arplApplication['last_name']) ?>
      </span>
    </td>
  </tr>
  <tr>
    <td><b>ID Number</b></td>
    <td><span class="prefilled"><?= htmlspecialchars($arplApplication['id_number']) ?></span></td>
  </tr>
  <tr>
    <td><b>Date of Birth</b></td>
    <td><span class="prefilled"><?= date('d M Y', strtotime($arplApplication['date_of_birth'])) ?></span></td>
  </tr>
  <tr>
    <td><b>Gender</b></td>
    <td><span class="prefilled"><?= htmlspecialchars($arplApplication['gender']) ?></span></td>
  </tr>
  <tr>
    <td><b>Phone</b></td>
    <td><span class="prefilled"><?= htmlspecialchars($arplApplication['phone']) ?></span></td>
  </tr>
  <tr>
    <td><b>Email</b></td>
    <td><span class="prefilled"><?= htmlspecialchars($arplApplication['email']) ?></span></td>
  </tr>
</table>
```

### 2. Address Section

```html
<table class="ft">
  <tr>
    <td style="width:50%;"><b>Physical Address</b></td>
    <td style="width:50%;"><b>Postal Address</b></td>
  </tr>
  <tr>
    <td>
      <span class="prefilled">
        <?= htmlspecialchars($arplApplication['street_address']) ?><br>
        <?= htmlspecialchars($arplApplication['suburb'] ?? '') ?><br>
        <?= htmlspecialchars($arplApplication['city']) ?><br>
        <?= htmlspecialchars($arplApplication['postal_code']) ?>
      </span>
    </td>
    <td><input type="text" placeholder="Postal address"></td>
  </tr>
  <tr>
    <td><b>Province:</b> <?= htmlspecialchars($arplApplication['province']) ?></td>
    <td><input type="text" placeholder="Postal province"></td>
  </tr>
</table>
```

### 3. Employment History Table

```html
<p style="font-size:11pt;font-weight:bold;margin:10px 0 5px;">Employment History</p>
<table class="ft">
  <tr>
    <th class="l">Company</th>
    <th class="l">Position/Job Title</th>
    <th class="l">Period &amp; Duration</th>
    <th class="l">Type</th>
  </tr>
  <?php foreach ($arplWorkExperience as $work): ?>
  <tr>
    <td>
      <span class="prefilled">
        <?= htmlspecialchars($work['employer_name']) ?>
      </span>
    </td>
    <td>
      <span class="prefilled">
        <?= htmlspecialchars($work['job_title']) ?>
      </span>
    </td>
    <td>
      <span class="prefilled">
        <?= date('Y-m-d', strtotime($work['start_date'])) ?> 
        to 
        <?= $work['is_current_job'] ? 'Present' : date('Y-m-d', strtotime($work['end_date'])) ?>
        <br>
        (<?= $work['years_worked'] ?> years, <?= $work['months_worked'] ?> months)
      </span>
    </td>
    <td>
      <span class="prefilled">
        <?= htmlspecialchars($work['employment_type']) ?>
      </span>
    </td>
  </tr>
  <?php endforeach; ?>
</table>
```

### 4. References Section

```html
<p style="font-size:11pt;font-weight:bold;margin:10px 0 5px;">References</p>
<table class="ft">
  <tr>
    <th class="l">Name</th>
    <th class="l">Position</th>
    <th class="l">Company</th>
    <th class="l">Phone</th>
    <th class="l">Email</th>
  </tr>
  <?php foreach ($arplReferences as $ref): ?>
  <tr>
    <td>
      <span class="prefilled">
        <?= htmlspecialchars($ref['reference_name'] . ' ' . $ref['reference_surname']) ?>
      </span>
    </td>
    <td>
      <span class="prefilled">
        <?= htmlspecialchars($ref['job_position']) ?>
      </span>
    </td>
    <td>
      <span class="prefilled">
        <?= htmlspecialchars($ref['company_name']) ?>
      </span>
    </td>
    <td>
      <span class="prefilled">
        <?= htmlspecialchars($ref['reference_phone']) ?>
      </span>
    </td>
    <td>
      <span class="prefilled">
        <?= htmlspecialchars($ref['reference_email']) ?>
      </span>
    </td>
  </tr>
  <?php endforeach; ?>
</table>
```

### 5. Qualifications Section

```html
<p style="font-size:11pt;font-weight:bold;margin:10px 0 5px;">Qualifications</p>
<table class="ft">
  <tr>
    <th class="l">Qualification</th>
    <th class="l">Level</th>
    <th class="l">Institution</th>
    <th>Year</th>
    <th>Status</th>
  </tr>
  <?php foreach ($arplQualifications as $qual): ?>
  <tr>
    <td>
      <span class="prefilled">
        <?= htmlspecialchars($qual['qualification_name']) ?>
      </span>
    </td>
    <td>
      <span class="prefilled">
        <?= htmlspecialchars($qual['qualification_level']) ?>
      </span>
    </td>
    <td>
      <span class="prefilled">
        <?= htmlspecialchars($qual['institution_name']) ?>
      </span>
    </td>
    <td class="c">
      <span class="prefilled">
        <?= $qual['year_obtained'] ?>
      </span>
    </td>
    <td class="c">
      <span class="prefilled">
        <?= $qual['is_primary'] ? '<b>Primary</b>' : 'Supporting' ?>
      </span>
    </td>
  </tr>
  <?php endforeach; ?>
</table>
```

### 6. Employment Status Summary

```html
<p style="font-size:11pt;font-weight:bold;margin:10px 0 5px;">Employment Status:</p>
<table class="ft">
  <tr>
    <td style="width:38%;"><b>Total Years of Experience</b></td>
    <td>
      <span class="prefilled">
        <?= $arplApplication['total_years_of_experience'] ?> years
      </span>
    </td>
  </tr>
  <tr>
    <td><b>Highest Qualification</b></td>
    <td>
      <span class="prefilled">
        <?= htmlspecialchars($arplApplication['highest_qualification']) ?>
      </span>
    </td>
  </tr>
  <tr>
    <td><b>Trade Applied For</b></td>
    <td>
      <span class="prefilled">
        <?= htmlspecialchars($arplApplication['trade_applied_for']) ?>
      </span>
    </td>
  </tr>
  <tr>
    <td><b>Application Status</b></td>
    <td>
      <span class="prefilled">
        <?= htmlspecialchars($arplApplication['application_status']) ?>
      </span>
    </td>
  </tr>
</table>
```

---

## Complete Application Form Example

### Minimal Integration Example

```html
<!-- APPENDIX A: APPLICATION FORM -->
<div class="pb">
<table class="dht">
  <tr><td><b>Document</b><br>ARPLTOOLKIT</td>
      <td><b>Trade</b><br><?= htmlspecialchars($tradeName) ?></td>
      <td><b>Test Centre</b><br><?= htmlspecialchars($ctx['provider_name'] ?? '') ?></td></tr>
</table>

<div class="sec-title">1. Appendix A: Application Form
  <span style="font-size:10pt;font-weight:normal;color:#555;">
    — <?= htmlspecialchars($arplApplication['first_name'] . ' ' . $arplApplication['last_name']) ?>
  </span>
</div>

<!-- APPLICANT DETAILS -->
<div class="sec-sub">Applicant Details</div>
<table class="ft">
  <tr><td style="width:38%;"><b>Name</b></td>
      <td><span class="prefilled">
        <?= htmlspecialchars($arplApplication['first_name'] . ' ' . $arplApplication['last_name']) ?>
      </span></td></tr>
  <tr><td><b>ID Number</b></td>
      <td><span class="prefilled">
        <?= htmlspecialchars($arplApplication['id_number']) ?>
      </span></td></tr>
  <tr><td><b>Date of Birth</b></td>
      <td><span class="prefilled">
        <?= date('d M Y', strtotime($arplApplication['date_of_birth'])) ?>
      </span></td></tr>
  <tr><td><b>Gender</b></td>
      <td><span class="prefilled">
        <?= htmlspecialchars($arplApplication['gender']) ?>
      </span></td></tr>
  <tr><td><b>Phone</b></td>
      <td><span class="prefilled">
        <?= htmlspecialchars($arplApplication['phone']) ?>
      </span></td></tr>
  <tr><td><b>Email</b></td>
      <td><span class="prefilled">
        <?= htmlspecialchars($arplApplication['email']) ?>
      </span></td></tr>
</table>

<!-- EMPLOYMENT HISTORY -->
<div class="sec-sub" style="margin-top:15px;">Employment History</div>
<table class="ft">
  <tr><th class="l" style="width:35%;">Company</th>
      <th class="l" style="width:25%;">Position</th>
      <th class="l" style="width:25%;">Period</th>
      <th class="l" style="width:15%;">Type</th></tr>
  <?php foreach ($arplWorkExperience as $work): ?>
  <tr><td><span class="prefilled"><?= htmlspecialchars($work['employer_name']) ?></span></td>
      <td><span class="prefilled"><?= htmlspecialchars($work['job_title']) ?></span></td>
      <td><span class="prefilled"><?= date('Y', strtotime($work['start_date'])) ?> - 
        <?= $work['is_current_job'] ? 'Present' : date('Y', strtotime($work['end_date'])) ?></span></td>
      <td><span class="prefilled"><?= htmlspecialchars($work['employment_type']) ?></span></td></tr>
  <?php endforeach; ?>
</table>

<!-- REFERENCES -->
<div class="sec-sub" style="margin-top:15px;">References</div>
<table class="ft">
  <tr><th class="l">Name</th>
      <th class="l">Position</th>
      <th class="l">Company</th>
      <th class="l">Phone</th></tr>
  <?php foreach ($arplReferences as $ref): ?>
  <tr><td><span class="prefilled"><?= htmlspecialchars($ref['reference_name'] . ' ' . $ref['reference_surname']) ?></span></td>
      <td><span class="prefilled"><?= htmlspecialchars($ref['job_position']) ?></span></td>
      <td><span class="prefilled"><?= htmlspecialchars($ref['company_name']) ?></span></td>
      <td><span class="prefilled"><?= htmlspecialchars($ref['reference_phone']) ?></span></td></tr>
  <?php endforeach; ?>
</table>

<!-- QUALIFICATIONS -->
<div class="sec-sub" style="margin-top:15px;">Qualifications</div>
<table class="ft">
  <tr><th class="l" style="width:40%;">Qualification</th>
      <th class="l" style="width:25%;">Institution</th>
      <th style="width:15%;">Year</th>
      <th style="width:20%;">Level</th></tr>
  <?php foreach ($arplQualifications as $qual): ?>
  <tr><td><span class="prefilled"><?= htmlspecialchars($qual['qualification_name']) ?></span></td>
      <td><span class="prefilled"><?= htmlspecialchars($qual['institution_name']) ?></span></td>
      <td class="c"><span class="prefilled"><?= $qual['year_obtained'] ?></span></td>
      <td class="c"><span class="prefilled"><?= $qual['is_primary'] ? '<b>Primary</b>' : 'Supp.' ?></span></td></tr>
  <?php endforeach; ?>
</table>

</div><!-- end appendix a -->
```

---

## Data Validation & Null Safety

### Recommended Safe Rendering

```php
<!-- Safe rendering with null checks -->
<?php 
$name = $arplApplication['first_name'] ?? '' . ' ' . $arplApplication['last_name'] ?? '';
$phone = $arplApplication['phone'] ?? 'N/A';
$email = $arplApplication['email'] ?? 'N/A';
?>

<span class="prefilled"><?= htmlspecialchars($name) ?></span>
<span class="prefilled"><?= htmlspecialchars($phone) ?></span>
<span class="prefilled"><?= htmlspecialchars($email) ?></span>
```

### Handling Empty Arrays

```php
<!-- Check if work experience exists -->
<?php if (!empty($arplWorkExperience)): ?>
  <table class="ft">
    <!-- Work experience table -->
  </table>
<?php else: ?>
  <p><em>No work experience records available</em></p>
<?php endif; ?>
```

---

## Testing Checklist

- [ ] Application details display correctly
- [ ] Employment history shows 3 entries
- [ ] References show all 3 contacts
- [ ] Qualifications list shows all education
- [ ] All prefilled data is visible
- [ ] Date formatting is correct
- [ ] Phone/email show correctly
- [ ] Current job shows "Present" for end date
- [ ] No HTML errors in output
- [ ] PDF renders without issues

---

## Files References

- **Template**: `C:\projects\rlmss\web\arpl_toolkit_dynamic2.php`
- **Implementation**: `C:\projects\rlmss\web\arpl_pdf.php`
- **Production**: `C:\xampp\htdocs\web\web\web\arpl_pdf.php`
- **Population Script**: `C:\projects\rlmss\populate_arpl_v3_for_learner_16389.php`

---

## Summary

✅ All ARPL v3 application data is loaded and available  
✅ Template examples provided for all sections  
✅ Data safely integrated with null checks  
✅ Ready for PDF rendering  

**Integrate these code examples into your PDF template to display complete application form data!**

