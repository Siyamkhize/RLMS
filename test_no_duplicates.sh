#!/bin/bash
# Test script to verify no duplicate records are created

SERVER="https://tesing.mtltechnical.co.za/mobile"
LEARNER_ID="999"
CLASS_ID="TEST"
LAT="-26.123456"
LON="28.123456"
ACC="15.5"

echo "========================================="
echo "Testing No Duplicate Records"
echo "========================================="
echo ""

# Test 1: Clock-In
echo "Test 1: Clock-In"
echo "-----------------"
curl -s -X POST "$SERVER/clockin.php" \
  -d "clock_in=1" \
  -d "LearnerID=$LEARNER_ID" \
  -d "classID=$CLASS_ID" \
  -d "user_latitude=$LAT" \
  -d "user_longitude=$LON" \
  -d "user_accuracy=$ACC" \
  -d "isSynced=1"
echo ""
echo "Expected: 1 record created"
echo "Check database now: SELECT COUNT(*) FROM learner_clocking WHERE LearnerID=$LEARNER_ID AND clock_date=CURDATE();"
echo ""
read -p "Press Enter to continue to Test 2..."
echo ""

# Test 2: Clock-Out
echo "Test 2: Clock-Out"
echo "-----------------"
curl -s -X POST "$SERVER/clockout.php" \
  -d "clock_out=1" \
  -d "LearnerID=$LEARNER_ID" \
  -d "classID=$CLASS_ID" \
  -d "user_latitude=$LAT" \
  -d "user_longitude=$LON" \
  -d "user_accuracy=$ACC" \
  -d "isSynced=1"
echo ""
echo "Expected: SAME 1 record updated (not new record)"
echo "Check database now: SELECT COUNT(*) FROM learner_clocking WHERE LearnerID=$LEARNER_ID AND clock_date=CURDATE();"
echo ""
read -p "Press Enter to continue to Test 3..."
echo ""

# Test 3: Re-Sync (send clock-in again)
echo "Test 3: Re-Sync (Clock-In Again)"
echo "---------------------------------"
curl -s -X POST "$SERVER/clockin.php" \
  -d "clock_in=1" \
  -d "LearnerID=$LEARNER_ID" \
  -d "classID=$CLASS_ID" \
  -d "user_latitude=$LAT" \
  -d "user_longitude=$LON" \
  -d "user_accuracy=$ACC" \
  -d "isSynced=1"
echo ""
echo "Expected: SAME 1 record updated (not new record)"
echo "Check database now: SELECT COUNT(*) FROM learner_clocking WHERE LearnerID=$LEARNER_ID AND clock_date=CURDATE();"
echo ""

echo "========================================="
echo "Final Check"
echo "========================================="
echo "Run this query on your database:"
echo ""
echo "SELECT clocking_id, LearnerID, clock_date, clock_in_time, clock_out_time, synced"
echo "FROM learner_clocking"
echo "WHERE LearnerID=$LEARNER_ID AND clock_date=CURDATE();"
echo ""
echo "Expected: Only 1 row with both clock_in_time AND clock_out_time"
echo "========================================="
