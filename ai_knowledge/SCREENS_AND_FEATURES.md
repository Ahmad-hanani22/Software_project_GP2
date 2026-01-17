# Screens and Features - SHAQATI Flutter App

## Overview of Screens

### 1. Authentication Screens
- **login_screen.dart**: User login
- **register_screen.dart**: New user registration

### 2. Main Screens
- **home_page.dart**: Home page (largest file)
- **property_details_screen.dart**: Property details
- **map_screen.dart**: Map and properties

### 3. Dashboard Screens
- **admin_dashboard_screen.dart**: Admin dashboard
- **landlord_dashboard_screen.dart**: Landlord dashboard
- **tenant_dashboard_screen.dart**: Tenant dashboard

### 4. Contract Screens
- **tenant_contracts_screen.dart**: Tenant contracts view
- **landlord_contracts_screen.dart**: Landlord contracts view
- **admin_contract_management_screen.dart**: Admin contract management
- **contract_details_screen.dart**: Contract details view
- **contract_pdf_preview_screen.dart**: PDF preview

### 5. Payment Screens
- **tenant_payments_screen.dart**: Tenant payments
- **tenant_payment_screen.dart**: Single payment view
- **landlord_payments_screen.dart**: Landlord payments
- **payment_receipt_screen.dart**: Payment receipt

### 6. Maintenance Screens
- **tenant_maintenance_screen.dart**: Tenant maintenance requests
- **landlord_maintenance_screen.dart**: Landlord maintenance management
- **admin_maintenance_complaints_screen.dart**: Admin maintenance/complaints

### 7. Complaint Screens
- Complaint functionality integrated in admin_maintenance_complaints_screen.dart

### 8. Chat Screens
- **chat_screen.dart**: Direct chat
- **chat_list_screen.dart**: Chat list

### 9. Notification Screens
- Notification functionality integrated in dashboards

### 10. AI and Smart System Screens
- **ai_assistant_screen.dart**: AI Assistant
- **smart_system_screen.dart**: Smart System (1519 lines - largest screen file)

### 11. Financial Management Screens
- **expenses_management_screen.dart**: Expense management (2884 lines - largest file)
- **invoices_screen.dart**: Invoices
- **deposits_management_screen.dart**: Deposit management

### 12. Property Management Screens
- **all_properties_screen.dart**: All properties list
- **properties_by_type_screen.dart**: Properties by type
- **property_details_screen.dart**: Property details
- **property_history_screen.dart**: Property history
- **property_selection_screen.dart**: Property selection

### 13. Building and Unit Screens
- **buildings_management_screen.dart**: Building management
- **units_management_screen.dart**: Unit management
- **occupancy_history_screen.dart**: Occupancy history
- **ownership_management_screen.dart**: Ownership management

### 14. Admin Management Screens
- **admin_user_management_screen.dart**: User management
- **admin_property_management_screen.dart**: Property management
- **admin_payments_transactions_screen.dart**: Payments/transactions
- **admin_property_types_management_screen.dart**: Property types
- **admin_reviews_management_screen.dart**: Reviews management
- **admin_system_settings_screen.dart**: System settings
- **admin_notifications_management_screen.dart**: Notifications management

### 15. Other Screens
- **buy_screen.dart**: Buy properties
- **sell_screen.dart**: Sell properties
- **rent_screen.dart**: Rent properties
- **lifestyle_screen.dart**: Lifestyle services
- **service_pages.dart**: Service pages
- **my_home_screen.dart**: My home
- **forgot_password_screen.dart**: Password reset
- **MapSelectionScreen.dart**: Map selection

## Main Features by Role

### Admin (System Administrator)
- Manage all users
- Approve properties
- Manage complaints
- Comprehensive statistics
- Manage settings
- Manage property types
- Manage reviews

### Landlord (Property Owner)
- Manage their properties
- Create and manage contracts
- Track payments
- Manage maintenance requests
- Manage expenses and deposits
- Invoices
- Reports

### Tenant (Renter)
- Search for properties
- Request rental contracts
- Track payments
- Send maintenance requests
- Send complaints
- Chat with landlord

## Technologies Used in Flutter

- **State Management**: Provider
- **HTTP**: http package
- **Local Storage**: SharedPreferences
- **Maps**: Google Maps / Flutter Map
- **Real-time**: Socket.IO
- **Notifications**: Firebase Cloud Messaging
- **Image Upload**: Cloudinary

## File Structure

```
flutter_application_1/lib/
├── screens/          # 52 files - All screens
├── services/         # 6 files - API Services
├── widgets/          # 2 files - Reusable Widgets
├── utils/            # 2 files - Utilities
└── constants.dart   # AppConstants (baseUrl)
```

## Most Important Files

1. **expenses_management_screen.dart** (2884 lines) - Largest file
2. **smart_system_screen.dart** (1519 lines)
3. **home_page.dart** - Home page
4. **api_service.dart** - All API calls
