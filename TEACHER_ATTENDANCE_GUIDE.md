# 📝 Teacher Attendance Screen - User Guide

## Overview
The Teacher Attendance Screen allows teachers to mark attendance for their classes in a grade book style interface similar to traditional attendance sheets.

## Features

### 🎯 **Core Functionality**
- **Class Selection**: Dropdown to select which class to take attendance for
- **Date Selection**: Pick any date for attendance (defaults to current date)
- **Student List**: Automatically loads all students when a class is selected
- **Attendance Marking**: Simple tap interface to mark students as Present, Absent, or Late
- **Save Function**: Saves all attendance data to the database
- **Visual Feedback**: Color-coded buttons for easy identification

### 🎨 **Design**
- **Pink Gradient Background**: Matches the grade book aesthetic you requested
- **Card-based Layout**: Clean, organized interface
- **Responsive Grid**: Works well on all screen sizes
- **Legend**: Clear explanation of attendance codes

## How to Use

### Step 1: Access the Screen
1. Open the app and go to the main dashboard
2. Look for the **"Attendance"** card with the attendance icon
3. Tap to open the Teacher Attendance Screen

### Step 2: Select Class and Date
1. **Choose Class**: Tap the dropdown under "Class:" and select your class
2. **Set Date**: Tap the date field to change if needed (defaults to today)
3. **Students Load**: The student list will automatically populate

### Step 3: Mark Attendance
For each student, tap one of the three buttons:
- **P** (Green) = Present
- **A** (Red) = Absent  
- **L** (Orange) = Late

### Step 4: Save Attendance
1. Mark attendance for all students
2. Tap the **Save** icon in the top-right corner
3. See confirmation message when saved successfully

## Attendance Codes

| Code | Color | Meaning | Description |
|------|-------|---------|-------------|
| **P** | 🟢 Green | Present | Student was in class |
| **A** | 🔴 Red | Absent | Student was not in class |
| **L** | 🟠 Orange | Late | Student arrived late |

## Database Structure

The screen creates/updates **Attendance** records with:
- **class**: Reference to the Class object
- **student**: Reference to the Student object
- **date**: Date of attendance (YYYY-MM-DD format)
- **status**: "P", "A", or "L"
- **takenBy**: Reference to the teacher who marked attendance

## Technical Features

### ✅ **Smart Loading**
- Loads existing attendance if already marked for the date
- Prevents duplicate records by updating existing ones
- Automatically orders students alphabetically

### ✅ **Error Handling**
- Shows error messages for network issues
- Validates that class and students exist
- Handles empty student lists gracefully

### ✅ **User Experience**
- Visual feedback when buttons are pressed
- Loading indicators during data operations
- Success/error notifications
- Responsive design for different screen sizes

## Requirements

### Database Prerequisites
1. **Classes**: Must have at least one Class in the database
2. **Students**: Students must be assigned to classes
3. **Teachers**: Teacher must be logged in

### Field Names
The screen looks for these fields in your database:
- **Class**: `classname` or `name`
- **Student**: `fullName` or `name`

## Navigation
- Access from: **Main Dashboard → Attendance Card**
- Back navigation: **Back arrow** in app bar
- Save: **Save icon** in app bar (only visible when students are loaded)

## Tips for Teachers

1. **Mark attendance daily** for accurate records
2. **Use the date picker** to mark attendance for previous days if needed
3. **Save frequently** to avoid losing data
4. **Check the legend** if you forget what the codes mean
5. **Look for color feedback** when marking attendance

This screen provides a modern, efficient way to handle classroom attendance while maintaining the familiar grade book interface that teachers are used to! 📚✅