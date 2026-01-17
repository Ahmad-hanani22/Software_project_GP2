# Project Details - SHAQATI

## Basic Information

**Project Name:** SHAQATI  
**Type:** Real estate management application  
**Location:** Palestine  
**Primary Language:** Arabic  

## Roles in the System

The system contains **3 roles only**:

### 1. Admin (System Administrator)
- Full system management
- User and property management
- Approval of new properties
- Notification and complaint management
- Settings management

### 2. Landlord (Property Owner)
- Manage their properties
- Create and manage contracts
- Track payments and receipts
- Manage maintenance requests
- Manage expenses and deposits
- Invoices

### 3. Tenant (Renter)
- Search for properties
- Request rental contracts
- Track payments and dues
- Send maintenance requests
- Send complaints
- Chat with landlord

**⚠️ Important:** There are NO other roles such as:
- System Administrator
- Network Administrator
- Database Administrator
- Security Officer
- Application Developer
- User Experience Designer
- Quality Assurance Tester
- Documentation Specialist

These roles **DO NOT EXIST** in SHAQATI project.

## Main Features

### 1. Property Management
- Add/Edit/Delete properties
- Geographic search on map
- Multiple property types (apartment, villa, office, etc.)
- Two operations: rent or sale
- Admin approval required

### 2. Contract System
- Create contracts between landlord and tenant
- Track contract status (draft, pending, active, expired, terminated)
- Contract renewal
- Contract termination request
- Electronic signatures (both parties must sign)
- PDF document generation
- Contract attachments

**Contract Statuses:**
- `draft`: Draft contract (not submitted)
- `pending`: Pending approval from landlord
- `active`: Active contract (both parties signed)
- `expiring_soon`: Contract expiring soon
- `expired`: Contract expired
- `terminated`: Contract terminated
- `rented`: Rented (legacy compatibility)
- `rejected`: Contract rejected

**Contract Workflow:**
1. Tenant requests contract via API
2. Contract created with status `pending`
3. Landlord approves (status: `active`)
4. Both parties sign electronically
5. Contract becomes active when both signatures present
6. Payments automatically created when contract active

### 3. Payment System
- Record payments linked to contracts
- Electronic receipts
- Track payments and dues
- Multiple payment methods

### 4. Unit and Building Management
- Building management
- Unit management within buildings
- Link units to contracts

### 5. Maintenance System
- Maintenance requests from tenants
- Track maintenance status
- Assign technicians
- Upload problem photos

### 6. Complaint System
- Send complaints from tenants
- Classify complaints (financial, maintenance, behavior)
- Track complaint resolution

### 7. Chat and Notifications
- Direct chat between users
- Instant notifications (Firebase Cloud Messaging)
- System notifications

### 8. Smart System
- Personalized recommendations for users
- Behavior and preference analysis
- Recommendations based on search and view history

### 9. Financial System
- Expense management
- Deposit management
- Invoices
- Financial reports

## Main Screens

### Admin Screens
- admin_dashboard_screen.dart
- admin_user_management_screen.dart
- admin_property_management_screen.dart
- admin_contract_management_screen.dart
- admin_payments_transactions_screen.dart
- admin_maintenance_complaints_screen.dart
- admin_notifications_management_screen.dart
- admin_property_types_management_screen.dart
- admin_reviews_management_screen.dart
- admin_system_settings_screen.dart

### Landlord Screens
- landlord_dashboard_screen.dart
- landlord_property_management_screen.dart
- landlord_contracts_screen.dart
- landlord_payments_screen.dart
- landlord_maintenance_screen.dart
- landlord_report_screen.dart

### Tenant Screens
- tenant_dashboard_screen.dart
- tenant_contracts_screen.dart
- tenant_payments_screen.dart
- tenant_maintenance_screen.dart

### General Screens
- home_page.dart (Home page)
- login_screen.dart
- register_screen.dart
- property_details_screen.dart
- map_screen.dart
- chat_screen.dart
- chat_list_screen.dart
- ai_assistant_screen.dart
- smart_system_screen.dart
- expenses_management_screen.dart
- deposits_management_screen.dart
- invoices_screen.dart
- buildings_management_screen.dart
- units_management_screen.dart
- occupancy_history_screen.dart
- ownership_management_screen.dart
- property_history_screen.dart

## Technologies Used

### Frontend (Flutter)
- Flutter SDK 3.0+
- Provider for State Management
- Firebase (Notifications, Authentication)
- Google Maps / Flutter Map
- Socket.IO for real-time chat
- SharedPreferences for local storage

### Backend (Node.js)
- Express.js
- MongoDB (Mongoose)
- Socket.IO for real-time
- JWT for Authentication
- Firebase Admin SDK
- Cloudinary for images
- Ollama (Local LLM) for AI

## Database

### Main Collections
- users (Users)
- properties (Properties)
- contracts (Contracts)
- payments (Payments)
- units (Units)
- buildings (Buildings)
- maintenancerequests (Maintenance requests)
- complaints (Complaints)
- chats (Messages)
- notifications (Notifications)
- expenses (Expenses)
- deposits (Deposits)
- invoices (Invoices)
- propertytypes (Property types)

## Main API Endpoints

### Authentication
- POST /api/auth/register
- POST /api/auth/login

### Properties
- GET /api/properties
- GET /api/properties/:id
- POST /api/properties
- PUT /api/properties/:id
- DELETE /api/properties/:id

### Contracts
- GET /api/contracts
- POST /api/contracts
- POST /api/contracts/request
- PUT /api/contracts/:id
- POST /api/contracts/:id/sign
- POST /api/contracts/:id/renew
- POST /api/contracts/:id/terminate

### Payments
- GET /api/payments
- POST /api/payments
- PUT /api/payments/:id

### AI Assistant
- POST /api/ai/chat
- GET /api/ai/health

## Important Notes

1. All properties require Admin approval before appearing
2. Permissions are enforced in Backend via Middleware
3. Chat and notifications work via Socket.IO and Firebase FCM
4. Images are uploaded to Cloudinary
5. AI works locally via Ollama (Local LLM) - completely free
6. System uses only 3 roles: Admin, Landlord, Tenant
