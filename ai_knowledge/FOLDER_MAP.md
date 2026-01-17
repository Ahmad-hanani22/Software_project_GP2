# File Map - SHAQATI Project Structure

## Backend Structure

```
backend/
├── server.js                    # Main entry point
├── package.json                 # Dependencies
│
├── config/                      # Configuration
│   ├── firebase.js             # Firebase Admin SDK
│   └── serviceAccountKey.json  # Firebase Service Account
│
├── controllers/                 # Business Logic
│   ├── propertyController.js
│   ├── contractController.js
│   ├── paymentController.js
│   ├── userController.js
│   ├── maintenanceController.js
│   ├── complaintController.js
│   ├── chatController.js
│   ├── notificationController.js
│   ├── adminController.js
│   ├── adminDashboardController.js
│   ├── landlordDashboardController.js
│   ├── smartSystemController.js
│   ├── unitController.js
│   ├── expenseController.js
│   ├── depositController.js
│   ├── invoiceController.js
│   ├── buildingController.js
│   ├── aiController.js
│   └── ... (others)
│
├── models/                      # Mongoose Schemas
│   ├── User.js                 # Users (tenant, landlord, admin)
│   ├── Property.js             # Properties
│   ├── Contract.js             # Contracts
│   ├── Payment.js              # Payments
│   ├── Unit.js                 # Units
│   ├── Building.js             # Buildings
│   ├── MaintenanceRequest.js   # Maintenance requests
│   ├── Complaint.js            # Complaints
│   ├── Chat.js                 # Messages
│   ├── Notification.js         # Notifications
│   ├── Expense.js              # Expenses
│   ├── Deposit.js              # Deposits
│   ├── Invoice.js              # Invoices
│   ├── PropertyType.js         # Property types
│   ├── UserProfile.js          # Smart user profiles
│   ├── UserBehavior.js         # User behavior analysis
│   ├── OccupancyHistory.js     # Occupancy history
│   └── ... (others)
│
├── routes/                      # API Routes
│   ├── propertyRoutes.js       # /api/properties
│   ├── contractRoutes.js       # /api/contracts
│   ├── paymentRoutes.js        # /api/payments
│   ├── userRoutes.js           # /api/users
│   ├── authRoutes.js           # /api/auth
│   ├── maintenanceRoutes.js    # /api/maintenance
│   ├── complaintRoutes.js      # /api/complaints
│   ├── chatRoutes.js           # /api/chats
│   ├── notificationRoutes.js   # /api/notifications
│   ├── adminRoutes.js          # /api/admins
│   ├── adminDashboardRoutes.js # /api/admin/dashboard
│   ├── landlordDashboardRoutes.js # /api/landlord/dashboard
│   ├── smartSystemRoutes.js    # /api/smart-system
│   ├── unitRoutes.js           # /api/units
│   ├── expenseRoutes.js        # /api/expenses
│   ├── depositRoutes.js        # /api/deposits
│   ├── invoiceRoutes.js        # /api/invoices
│   ├── buildingRoutes.js       # /api/buildings
│   ├── uploadRoutes.js         # /api/upload
│   ├── aiRoutes.js             # /api/ai
│   └── ... (others)
│
├── Middleware/                  # Middleware Functions
│   ├── authMiddleware.js       # protect, authorizeRoles
│   ├── ownership.js            # ownsPropertyOrAdmin
│   ├── rateLimiter.js          # Rate limiting
│   └── uploadMiddleware.js     # File upload
│
└── utils/                       # Utilities
    ├── localAI.js              # Ollama integration
    ├── sendNotification.js     # Send notifications
    ├── seedPropertyTypes.js    # Seed data
    ├── emailService.js         # Email service
    ├── fcmService.js           # Firebase Cloud Messaging
    ├── cloudinary.js           # Cloudinary integration
    └── contractReminderService.js # Contract reminders
```

## Flutter Structure

```
flutter_application_1/
├── lib/
│   ├── main.dart               # Entry point
│   │
│   ├── screens/                # Main screens
│   │   ├── home_page.dart      # Home page
│   │   ├── login_screen.dart
│   │   ├── register_screen.dart
│   │   ├── property_details_screen.dart
│   │   ├── map_screen.dart
│   │   │
│   │   ├── admin_dashboard_screen.dart
│   │   ├── landlord_dashboard_screen.dart
│   │   ├── tenant_dashboard_screen.dart
│   │   │
│   │   ├── contract screens...
│   │   ├── payment screens...
│   │   ├── maintenance screens...
│   │   ├── ai_assistant_screen.dart
│   │   ├── smart_system_screen.dart
│   │   ├── expenses_management_screen.dart
│   │   └── ... (others)
│   │
│   ├── services/               # API Services
│   │   ├── api_service.dart    # Main API service
│   │   ├── ai_service.dart     # AI service
│   │   ├── smart_system_service.dart
│   │   └── firebase_notification_service.dart
│   │
│   ├── widgets/                # Reusable Widgets
│   │   ├── floating_smart_button.dart
│   │   └── ... (others)
│   │
│   ├── utils/                  # Utilities
│   │   ├── app_theme_settings.dart
│   │   ├── app_localizations.dart
│   │   └── constants.dart      # AppConstants (baseUrl)
│   │
│   └── models/                 # Data Models (if any)
│
├── assets/                     # Assets
│   └── images/
│
└── pubspec.yaml                # Dependencies
```

## Important Files for Quick Understanding

### Backend
- `server.js` - Server start + Routes registration
- `controllers/propertyController.js` - Example Controller
- `models/Property.js` - Example Model
- `routes/propertyRoutes.js` - Example Routes
- `Middleware/authMiddleware.js` - Authentication logic
- `controllers/contractController.js` - Contract management
- `models/Contract.js` - Contract schema with all statuses
- `controllers/aiController.js` - AI Assistant logic
- `utils/localAI.js` - Ollama integration

### Flutter
- `lib/main.dart` - App entry point + Theme
- `lib/screens/home_page.dart` - Home page (largest file)
- `lib/services/api_service.dart` - All API calls
- `lib/utils/constants.dart` - Base URL configuration
- `lib/screens/ai_assistant_screen.dart` - AI Assistant UI
- `lib/services/ai_service.dart` - AI service integration

## Contract System Files

### Backend
- `models/Contract.js` - Contract schema with statuses, signatures, termination
- `controllers/contractController.js` - Contract CRUD, signing, renewal, termination
- `routes/contractRoutes.js` - Contract API endpoints

### Flutter
- `lib/screens/tenant_contracts_screen.dart` - Tenant contract management
- `lib/screens/landlord_contracts_screen.dart` - Landlord contract management
- `lib/screens/admin_contract_management_screen.dart` - Admin contract management
- `lib/screens/contract_details_screen.dart` - Contract details view
- `lib/screens/contract_pdf_preview_screen.dart` - PDF preview
