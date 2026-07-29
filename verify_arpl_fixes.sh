#!/bin/bash

# Verification script for ARPL Trade Display Fix
# Run this before rebuilding to verify all fixes are in place

echo "=========================================="
echo "ARPL TRADE DISPLAY FIX - VERIFICATION"
echo "=========================================="
echo ""

ERRORS=0
WARNINGS=0

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "Checking Dart files..."
echo ""

# Check 1: No more ?? '671101' patterns in ArplAssessor
if grep -q "?? '671101'" lib/ArplAssessorPage.dart 2>/dev/null; then
    echo -e "${RED}❌ FAIL${NC}: ArplAssessorPage still has ?? '671101' defaults"
    ((ERRORS++))
else
    echo -e "${GREEN}✅ PASS${NC}: ArplAssessorPage - no ?? '671101' defaults found"
fi

# Check 2: Verify 641201 in ArplAssessorPage _getTradeName
if grep -q "case '641201':" lib/ArplAssessorPage.dart 2>/dev/null; then
    echo -e "${GREEN}✅ PASS${NC}: ArplAssessorPage - has '641201' for Bricklayer"
else
    echo -e "${RED}❌ FAIL${NC}: ArplAssessorPage - missing '641201' mapping"
    ((ERRORS++))
fi

# Check 3: Verify 642601 in ArplAssessorPage _getTradeName
if grep -q "case '642601':" lib/ArplAssessorPage.dart 2>/dev/null; then
    echo -e "${GREEN}✅ PASS${NC}: ArplAssessorPage - has '642601' for Plumber"
else
    echo -e "${RED}❌ FAIL${NC}: ArplAssessorPage - missing '642601' mapping"
    ((ERRORS++))
fi

# Check 4: Verify ArplToolkitViewerPage has required ofoNumber
if grep -q "required this.ofoNumber" lib/ArplToolkitViewerPage.dart 2>/dev/null; then
    echo -e "${GREEN}✅ PASS${NC}: ArplToolkitViewerPage - ofoNumber is required"
else
    echo -e "${YELLOW}⚠️  WARNING${NC}: ArplToolkitViewerPage - ofoNumber might have default"
    ((WARNINGS++))
fi

# Check 5: Verify ArplAppendixEPage has required ofoNumber
if grep -q "required this.ofoNumber" lib/ArplAppendixEPage.dart 2>/dev/null; then
    echo -e "${GREEN}✅ PASS${NC}: ArplAppendixEPage - ofoNumber is required"
else
    echo -e "${YELLOW}⚠️  WARNING${NC}: ArplAppendixEPage - ofoNumber might have default"
    ((WARNINGS++))
fi

# Check 6: Check for remaining 671102 in Dart files (should only be comments)
DART_671102=$(grep -r "671102" lib/Arpl*.dart 2>/dev/null | grep -v "FIXED from" | grep -v "case '671102'" | wc -l)
if [ $DART_671102 -gt 0 ]; then
    echo -e "${YELLOW}⚠️  WARNING${NC}: Found $DART_671102 references to 671102 in Dart (should be in comments only)"
    ((WARNINGS++))
else
    echo -e "${GREEN}✅ PASS${NC}: No 671102 code references in Dart files"
fi

echo ""
echo "Checking PHP files..."
echo ""

# Check 7: Verify web/api/get_arpl_complete_data.php has correct mappings
if grep -q "'641201' => 'bricklaying'" web/api/get_arpl_complete_data.php 2>/dev/null; then
    echo -e "${GREEN}✅ PASS${NC}: get_arpl_complete_data.php - has '641201' mapping"
else
    echo -e "${RED}❌ FAIL${NC}: get_arpl_complete_data.php - missing '641201' mapping"
    ((ERRORS++))
fi

# Check 8: Verify get_arpl_complete_data.php doesn't default to 671101
if grep -q "return isset.*'electrician'" web/api/get_arpl_complete_data.php 2>/dev/null; then
    echo -e "${YELLOW}⚠️  WARNING${NC}: get_arpl_complete_data.php - might default to electrician"
    ((WARNINGS++))
else
    echo -e "${GREEN}✅ PASS${NC}: get_arpl_complete_data.php - no silent defaults"
fi

# Check 9: Verify mobile/save_arpl_appendix_f_assessment.php validation
if grep -q "OFO number is required" mobile/save_arpl_appendix_f_assessment.php 2>/dev/null; then
    echo -e "${GREEN}✅ PASS${NC}: save_arpl_appendix_f_assessment.php - has validation"
else
    echo -e "${YELLOW}⚠️  WARNING${NC}: save_arpl_appendix_f_assessment.php - validation might be missing"
    ((WARNINGS++))
fi

# Check 10: Verify mobile/arpl_toolkit_dynamic.php validation
if grep -q "trade_ofo parameter is required" mobile/arpl_toolkit_dynamic.php 2>/dev/null; then
    echo -e "${GREEN}✅ PASS${NC}: arpl_toolkit_dynamic.php - has validation"
else
    echo -e "${YELLOW}⚠️  WARNING${NC}: arpl_toolkit_dynamic.php - validation might be missing"
    ((WARNINGS++))
fi

echo ""
echo "=========================================="
echo "SUMMARY"
echo "=========================================="
echo -e "${GREEN}Errors: $ERRORS${NC}"
echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
echo ""

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ All critical fixes verified!${NC}"
    echo "Safe to proceed with rebuild."
    exit 0
else
    echo -e "${RED}❌ Found $ERRORS errors that need fixing!${NC}"
    exit 1
fi
