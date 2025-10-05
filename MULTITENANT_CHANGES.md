# Multi-Tenant School System - Model Updates

## Overview
This document outlines the changes made to existing models and services to support multi-tenancy in the school management system. All models now include school pointer fields to enable data isolation between different schools.

## Models Updated

### 1. Student Model (`/lib/models/student.dart`)
**Added Fields:**
- `schoolId`: String? - The object ID of the school
- `schoolName`: String? - The name of the school (cached for display)

**Changes:**
- Updated constructor to include school fields
- Modified `fromParseObject` factory method to extract school information from Parse pointer

### 2. Teacher Model (`/lib/models/teacher.dart`)
**Added Fields:**
- `schoolId`: String? - The object ID of the school
- `schoolName`: String? - The name of the school (cached for display)

**Changes:**
- Updated constructor to include school fields
- Modified `fromParseObject` factory method to extract school information from Parse pointer

### 3. SchoolClass Model (`/lib/models/class_model.dart`)
**Added Fields:**
- `schoolId`: String? - The object ID of the school
- `schoolName`: String? - The name of the school (cached for display)

**Changes:**
- Updated constructor to include school fields
- Modified `fromParseObject` factory method to extract school information from Parse pointer

### 4. School Model (`/lib/models/school.dart`) - NEW
**Fields:**
- `objectId`: String - Unique identifier
- `schoolName`: String - Name of the school
- `schoolCode`: String - Unique code for the school
- `logo`: String? - URL to school logo
- `address`: String? - School address
- `phone`: String? - Contact phone
- `email`: String? - Contact email
- `website`: String? - School website
- `subscriptionPlan`: String - Subscription tier (basic, premium, enterprise)
- `maxUsers`: int - Maximum allowed users
- `currentUserCount`: int - Current user count
- `isActive`: bool - Whether school is active
- `createdAt`: DateTime? - Creation timestamp
- `ownerId`: String? - ID of the school owner

## Services Updated

### 1. AuthService (`/lib/services/auth_service.dart`)
**Changes:**
- Updated `signup` method to accept optional `schoolId` parameter
- Added school pointer setting during user registration

### 2. StudentService (`/lib/services/student_service.dart`)
**Changes:**
- Updated `createStudent` method to accept optional `schoolId` parameter
- Added school pointer setting during student creation
- Updated `fetchStudents` method to accept optional `schoolId` parameter for filtering (commented for now)

### 3. ClassService (`/lib/services/class_service.dart`)
**Changes:**
- Updated `createClass` method to accept optional `schoolId` parameter
- Added school pointer setting during class creation
- Updated `fetchClasses` method to accept optional `schoolId` parameter for filtering (commented for now)
- Updated `getClassList` method to accept optional `schoolId` parameter

### 4. SchoolService (`/lib/services/school_service.dart`) - NEW
**Methods:**
- `createSchool`: Create a new school
- `getSchoolById`: Retrieve school by ID
- `getSchoolByCode`: Retrieve school by unique code
- `updateSchool`: Update school information
- `getAllSchools`: Get all schools (admin function)
- `incrementUserCount`: Increase user count for a school
- `decrementUserCount`: Decrease user count for a school
- `canAddUser`: Check if school can add more users
- `isSchoolCodeUnique`: Validate school code uniqueness

## Screens Updated

### 1. AddTeacherInformationScreen (`/lib/screens/add_teacher_information_screen.dart`)
**Changes:**
- Added TODO comment for school pointer assignment
- Prepared for future school context integration

### 2. AddStudentInformationScreen (`/lib/screens/add_student_information_screen.dart`)
**Changes:**
- Added TODO comment for school pointer assignment
- Prepared for future school context integration

### 3. SignupPage (`/lib/screens/signup_page.dart`)
**Changes:**
- Added TODO comment for school pointer assignment during user signup
- Prepared for future school selection integration

## Parse Server Backend Schema

### New Table: School
```javascript
{
  "schoolName": "string",
  "schoolCode": "string", // unique
  "logo": "string",
  "address": "string", 
  "phone": "string",
  "email": "string",
  "website": "string",
  "subscriptionPlan": "string", // basic, premium, enterprise
  "maxUsers": "number",
  "currentUserCount": "number",
  "isActive": "boolean",
  "owner": "pointer to _User"
}
```

### Updated Tables:
All existing tables now need a `school` field:
- **_User** → add `school` (Pointer to School)
- **Teacher** → add `school` (Pointer to School)
- **Student** → add `school` (Pointer to School)
- **Class** → add `school` (Pointer to School)
- **ClassSubjectTeacher** → add `school` (Pointer to School)
- **Enrolment** → add `school` (Pointer to School)

## Data Migration Required

Before activating the multi-tenant filtering, you'll need to:

1. **Create School records** for existing data
2. **Update all existing records** to reference the appropriate school
3. **Set up Cloud Code** to enforce school-based data isolation
4. **Test thoroughly** to ensure data integrity

## Next Steps

1. **Implement School Registration Flow**
   - Create school registration screen
   - Add school selection during login

2. **Add School Context Management**
   - Create a global school context provider
   - Update all queries to use current school context

3. **Uncomment and Activate Filtering**
   - Remove TODO comments
   - Activate school-based filtering in all queries

4. **Implement Owner Dashboard**
   - User management for school owners
   - Subscription management
   - Analytics and reporting

## Security Considerations

- All queries must include school filtering to prevent data leakage
- Cloud Code should enforce school-based access control
- User permissions should be scoped to their school
- API endpoints should validate school access rights

## Notes

- All school pointer assignments are currently commented out with TODO markers
- This allows the app to continue functioning while preparing for multi-tenancy
- School filtering in queries is disabled until full implementation
- The system is backward compatible with existing single-tenant data