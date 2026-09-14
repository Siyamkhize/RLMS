/**
 * Person Registration Form - Google Apps Script Backend
 * This script handles form submissions and saves data to Google Sheets
 * 
 * SETUP INSTRUCTIONS:
 * 1. Create a new Google Sheets document
 * 2. Go to Extensions > Apps Script
 * 3. Copy this code into the script editor
 * 4. Update the SHEET_NAME constant if needed
 * 5. Deploy as Web App (Deploy > New deployment > Web app)
 * 6. Set "Execute as" to "Me"
 * 7. Set "Who has access" to "Anyone"
 * 8. Click Deploy and copy the web app URL
 * 9. Update the HTML form to use this URL
 */

// Configuration
const SHEET_NAME = 'People'; // Sheet name must match Excel template
const NOTIFICATION_EMAIL = 'your-email@example.com'; // Change this to receive notifications

/**
 * Serve the HTML form
 */
function doGet() {
  return HtmlService.createHtmlOutputFromFile('person_registration_form')
    .setTitle('Person Registration Form')
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
}

/**
 * Initialize the spreadsheet with headers matching the Excel template
 */
function initializeSheet() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sheet = ss.getSheetByName(SHEET_NAME);
  
  if (!sheet) {
    sheet = ss.insertSheet(SHEET_NAME);
  }
  
  // Check if headers already exist
  if (sheet.getLastRow() === 0) {
    const headers = [
      'Title', 'FirstName', 'MiddleName', 'Surname', 'MaidenName', 'Initials',
      'IDNo', 'AlternateIDType', 'DateofBirth', 'Gender', 'Equity', 'HighestEducation',
      'CurrentOccupation', 'YearsInOccupation', 'Experience', 'Disability', 'HomeLanguage',
      'Nationality', 'CitizenResidentialStatus', 'CommunicationMethod', 'PersonStatus',
      'SocioEconomicStatus', 'StatusEffectiveDate', 'StatusReason', 'TelephoneNumber',
      'CellPhoneNumber', 'FaxNumber', 'EMail', 'PhysicalAddressLine1', 'PhysicalAddressLine2',
      'PhysicalAddressLine3', 'PhysicalCode', 'PhysicalMunicipality', 'PhysicalUrbanRural',
      'PhysicalProvince', 'PostalAddressLine1', 'PostalAddressLine2', 'PostalAddressLine3',
      'PostalCode', 'PostalMunicipality', 'PostalUrbanRural', 'PostalProvince',
      'ProviderSDLNumber', 'LastSchoolEmis', 'SchoolYear', 'STATSSAAreaCode',
      'POPIActStatus', 'POPIActStatusDate', 'SubmissionTimestamp', 'RegistrationID'
    ];
    
    // Set headers
    sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
    
    // Format header row
    const headerRange = sheet.getRange(1, 1, 1, headers.length);
    headerRange.setBackground('#667eea');
    headerRange.setFontColor('#ffffff');
    headerRange.setFontWeight('bold');
    headerRange.setHorizontalAlignment('center');
    
    // Freeze header row
    sheet.setFrozenRows(1);
    
    // Auto-resize columns
    for (let i = 1; i <= headers.length; i++) {
      sheet.autoResizeColumn(i);
    }
    
    Logger.log('Sheet initialized successfully');
  }
  
  return sheet;
}

/**
 * Main function to handle form submission
 */
function submitRegistration(formData) {
  try {
    // Get or create the sheet
    const sheet = initializeSheet();
    
    // Generate unique registration ID
    const registrationId = 'REG-' + new Date().getTime();
    
    // Prepare row data in the same order as headers
    const rowData = [
      formData.title || '',
      formData.firstName || '',
      formData.middleName || '',
      formData.surname || '',
      formData.maidenName || '',
      formData.initials || '',
      formData.idNo || '',
      formData.alternateIDType || '',
      formData.dateOfBirth || '',
      formData.gender || '',
      formData.equity || '',
      formData.highestEducation || '',
      formData.currentOccupation || '',
      formData.yearsInOccupation || '',
      formData.experience || '',
      formData.disability || '',
      formData.homeLanguage || '',
      formData.nationality || '',
      formData.citizenResidentialStatus || '',
      formData.communicationMethod || '',
      formData.personStatus || '',
      formData.socioEconomicStatus || '',
      formData.statusEffectiveDate || '',
      formData.statusReason || '',
      formData.telephoneNumber || '',
      formData.cellPhoneNumber || '',
      formData.faxNumber || '',
      formData.email || '',
      formData.physicalAddressLine1 || '',
      formData.physicalAddressLine2 || '',
      formData.physicalAddressLine3 || '',
      formData.physicalCode || '',
      formData.physicalMunicipality || '',
      formData.physicalUrbanRural || '',
      formData.physicalProvince || '',
      formData.postalAddressLine1 || '',
      formData.postalAddressLine2 || '',
      formData.postalAddressLine3 || '',
      formData.postalCode || '',
      formData.postalMunicipality || '',
      formData.postalUrbanRural || '',
      formData.postalProvince || '',
      formData.providerSDLNumber || '',
      formData.lastSchoolEmis || '',
      formData.schoolYear || '',
      formData.statsSAAreaCode || '',
      formData.popiActStatus || '',
      formData.popiActStatusDate || '',
      formData.timestamp || new Date().toISOString(),
      registrationId
    ];
    
    // Append data to sheet
    sheet.appendRow(rowData);
    
    // Get the row number that was just added
    const lastRow = sheet.getLastRow();
    
    // Format the new row
    const dataRange = sheet.getRange(lastRow, 1, 1, rowData.length);
    dataRange.setHorizontalAlignment('left');
    
    // Alternate row colors for better readability
    if (lastRow % 2 === 0) {
      dataRange.setBackground('#f8f9fa');
    }
    
    // Send notification email (optional)
    sendNotificationEmail(formData, registrationId);
    
    // Log the submission
    Logger.log('Registration submitted successfully: ' + registrationId);
    
    // Return success response
    return {
      success: true,
      message: 'Registration submitted successfully',
      id: registrationId,
      row: lastRow
    };
    
  } catch (error) {
    Logger.log('Error submitting registration: ' + error.toString());
    throw new Error('Failed to submit registration: ' + error.message);
  }
}

/**
 * Send email notification when a new registration is submitted
 */
function sendNotificationEmail(formData, registrationId) {
  try {
    if (!NOTIFICATION_EMAIL || NOTIFICATION_EMAIL === 'your-email@example.com') {
      return; // Skip if email not configured
    }
    
    const subject = 'New Person Registration: ' + formData.firstName + ' ' + formData.surname;
    
    const body = `
A new person registration has been submitted.

Registration Details:
=====================
Registration ID: ${registrationId}

Personal Information:
--------------------
Name: ${formData.title} ${formData.firstName} ${formData.middleName} ${formData.surname}
ID Number: ${formData.idNo}
Date of Birth: ${formData.dateOfBirth}
Gender: ${formData.gender}
Nationality: ${formData.nationality}

Contact Information:
-------------------
Email: ${formData.email}
Cell Phone: ${formData.cellPhoneNumber}
Telephone: ${formData.telephoneNumber}

Address:
--------
Physical: ${formData.physicalAddressLine1}, ${formData.physicalAddressLine2}, ${formData.physicalAddressLine3}
Municipality: ${formData.physicalMunicipality}
Province: ${formData.physicalProvince}

Education & Employment:
----------------------
Highest Education: ${formData.highestEducation}
Current Occupation: ${formData.currentOccupation}
Years in Occupation: ${formData.yearsInOccupation}

POPI Act:
---------
Status: ${formData.popiActStatus}
Date: ${formData.popiActStatusDate}

Submission Time: ${formData.timestamp}

View the complete registration in the spreadsheet:
${SpreadsheetApp.getActiveSpreadsheet().getUrl()}
    `;
    
    MailApp.sendEmail(NOTIFICATION_EMAIL, subject, body);
    Logger.log('Notification email sent to: ' + NOTIFICATION_EMAIL);
    
  } catch (error) {
    Logger.log('Error sending notification email: ' + error.toString());
    // Don't throw error - email failure shouldn't stop registration
  }
}

/**
 * Get registration statistics
 */
function getRegistrationStats() {
  try {
    const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_NAME);
    if (!sheet) {
      return { error: 'Sheet not found' };
    }
    
    const lastRow = sheet.getLastRow();
    const totalRegistrations = lastRow > 1 ? lastRow - 1 : 0; // Exclude header
    
    return {
      success: true,
      totalRegistrations: totalRegistrations,
      lastUpdate: new Date().toISOString()
    };
    
  } catch (error) {
    Logger.log('Error getting stats: ' + error.toString());
    return { error: error.message };
  }
}

/**
 * Search for a registration by ID Number
 */
function searchByIdNumber(idNumber) {
  try {
    const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_NAME);
    if (!sheet) {
      return { error: 'Sheet not found' };
    }
    
    const data = sheet.getDataRange().getValues();
    const headers = data[0];
    const idColIndex = headers.indexOf('IDNo');
    
    if (idColIndex === -1) {
      return { error: 'ID Number column not found' };
    }
    
    // Search for matching ID
    for (let i = 1; i < data.length; i++) {
      if (data[i][idColIndex] === idNumber) {
        // Found a match, return the record
        const record = {};
        headers.forEach((header, index) => {
          record[header] = data[i][index];
        });
        return {
          success: true,
          found: true,
          record: record,
          row: i + 1
        };
      }
    }
    
    return {
      success: true,
      found: false,
      message: 'No registration found with ID Number: ' + idNumber
    };
    
  } catch (error) {
    Logger.log('Error searching: ' + error.toString());
    return { error: error.message };
  }
}

/**
 * Export data to match PersonUpload_Template_V3 format
 */
function exportToTemplateFormat() {
  try {
    const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_NAME);
    if (!sheet) {
      return { error: 'Sheet not found' };
    }
    
    // Get all data
    const data = sheet.getDataRange().getValues();
    
    // Create new sheet for export
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    let exportSheet = ss.getSheetByName('Export_Template');
    
    if (exportSheet) {
      ss.deleteSheet(exportSheet);
    }
    
    exportSheet = ss.insertSheet('Export_Template');
    
    // Copy data to export sheet (excluding timestamp and registration ID columns)
    const excludeColumns = ['SubmissionTimestamp', 'RegistrationID'];
    const headers = data[0];
    const exportHeaders = [];
    const exportIndices = [];
    
    headers.forEach((header, index) => {
      if (!excludeColumns.includes(header)) {
        exportHeaders.push(header);
        exportIndices.push(index);
      }
    });
    
    // Set headers in export sheet
    exportSheet.getRange(1, 1, 1, exportHeaders.length).setValues([exportHeaders]);
    
    // Copy data rows
    for (let i = 1; i < data.length; i++) {
      const exportRow = exportIndices.map(index => data[i][index]);
      exportSheet.getRange(i + 1, 1, 1, exportRow.length).setValues([exportRow]);
    }
    
    // Format export sheet
    const headerRange = exportSheet.getRange(1, 1, 1, exportHeaders.length);
    headerRange.setBackground('#4472C4');
    headerRange.setFontColor('#ffffff');
    headerRange.setFontWeight('bold');
    
    return {
      success: true,
      message: 'Export sheet created successfully',
      sheetName: 'Export_Template',
      recordCount: data.length - 1
    };
    
  } catch (error) {
    Logger.log('Error exporting: ' + error.toString());
    return { error: error.message };
  }
}
