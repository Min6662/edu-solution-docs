# QR Code Validation Testing Guide

## Current Implementation

The QR scanner now validates that a teacher has a scheduled class at the current time before accepting the QR scan.

### Validation Flow:
1. ✅ Get teacher ID from current user
2. ✅ Extract class ID from QR code
3. ✅ Get current day and time
4. ✅ Query Schedule table for: teacher + class + day match
5. ✅ Check if current time falls within class time window
   - Accepts scans from 5 minutes BEFORE to 55 minutes AFTER class start time
   - Example: If class is at 10:00, accepts scans from 9:55 to 10:55

### Expected Behaviors:

#### ✅ SHOULD ACCEPT:
- Scanning during scheduled class time
- Scanning up to 55 minutes into the class (1 hour class window)
- Example: Class scheduled at 09:00 → accepts 08:55 to 09:55

#### ❌ SHOULD REJECT:
- Class not found in system
- Teacher doesn't teach this class
- Class is scheduled on different day
- Current time is outside the class time window (before 5 min before or after 55 min after)
- No schedule at all

## Debug Output Format

When scanning, you'll see console logs like:

```
Teacher ID: aGSB3GcE5W
Class Code: kaAvNdHPis
Current Day: Thu, Time: 9:52
Class ID from QR: kaAvNdHPis
✅ Using Class: Class Name (ID: kaAvNdHPis)

=== SCHEDULE QUERY DEBUG ===
Teacher Pointer ID: aGSB3GcE5W
Class Pointer ID: kaAvNdHPis
Current Day: Thu

Schedule query success: true
Schedule query results count: 1
Schedule #0:
  - Teacher: aGSB3GcE5W
  - Class: kaAvNdHPis
  - Day: Thu
  - TimeSlot: 09:00
  - Subject: Islamic Studies

=== TIME SLOT MATCHING ===
Checking time slot: 09:00 for subject: Islamic Studies
Scheduled time: 09:00 = 540 min
Current time: 09:52 = 592 min
Time difference: 52 minutes
Checking range: -5 to 55 (5 min before to 55 min after)
✅ MATCH! Valid class time for Islamic Studies!
✅ Class found: Class Name - Islamic Studies at 09:00
```

## Troubleshooting

### Problem: "❌ No schedule found"
**Possible Causes:**
1. Teacher doesn't have this class in their Schedule
2. Day mismatch (check if day format is correct: Mon, Tue, etc.)
3. Class ID from QR doesn't match Schedule table

**Check:**
- Verify Schedule table has entries for this teacher + class + day
- Confirm day format is short name (Mon, Tue, Wed, Thu, Fri, Sat, Sun)

### Problem: "❌ Time outside valid window"
**Possible Cause:**
- Current time is more than 55 minutes into the class
- Current time is before the class time

**Example:**
- Scheduled: 09:00
- Valid window: 08:55 to 09:55
- Current: 10:00 → REJECTED (outside window)
- Current: 09:30 → ACCEPTED (within window)

### Problem: Logs not showing
**Solution:**
- Check iPhone console in Xcode
- Or use `flutter logs` command in a separate terminal

## Test Cases

### Test 1: Valid Class Time
- Time: During scheduled class time
- Expected: ✅ Accept QR, show class name and subject

### Test 2: Too Late (After 55 minutes)
- Class at 09:00, scan at 10:00
- Expected: ❌ Reject, show "No class at this time"

### Test 3: Wrong Day
- Class on Monday, scan on Thursday
- Expected: ❌ Reject, show "No schedule found"

### Test 4: Teacher Doesn't Teach Class
- Scan a class this teacher doesn't teach
- Expected: ❌ Reject, show "No schedule found"

## Next Steps

1. Build and deploy to iPhone
2. Scan QR code and check console logs
3. Share the debug output for analysis
4. Adjust validation rules if needed
