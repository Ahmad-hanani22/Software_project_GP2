# API Routes - SHAQATI Backend

## Base URL
- **Development**: `http://localhost:3000/api`
- **Production**: `https://shaqati-backend.onrender.com/api`

## Authentication
All protected routes require Header:
```
Authorization: Bearer <JWT_TOKEN>
```

---

## 🔐 Authentication Routes
**Base**: `/api/auth`

- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login (returns token)

---

## 👤 User Routes
**Base**: `/api/users`

- `GET /api/users/me` - Current user information (protected)
- `GET /api/users/chat-list` - User list for chat (protected)
- `GET /api/users/admins` - Admin list (protected)
- `PUT /api/users/profile` - Update profile (protected)
- `PUT /api/users/:userId/fcm-token` - Update FCM Token (protected)

---

## 🏠 Property Routes
**Base**: `/api/properties`

- `GET /api/properties` - Get all properties (public)
  - Query params: `type`, `operation`, `city`, `minPrice`, `maxPrice`
- `GET /api/properties/:id` - Get specific property (public)
- `GET /api/properties/owner/:ownerId` - Properties of specific owner (protected)
- `POST /api/properties` - Add new property (landlord/admin only)
- `PUT /api/properties/:id` - Update property (property owner/admin only)
- `DELETE /api/properties/:id` - Delete property (property owner/admin only)

---

## 📄 Contract Routes
**Base**: `/api/contracts`

**Contract System Overview:**
The contract system manages rental agreements between landlords and tenants. Contracts link properties/units to users and track the entire rental lifecycle.

**Contract Statuses:**
- `draft`: Draft contract (not submitted)
- `pending`: Pending approval from landlord
- `active`: Active contract (both parties signed)
- `expiring_soon`: Contract expiring soon
- `expired`: Contract expired
- `terminated`: Contract terminated
- `rented`: Rented (legacy compatibility)
- `rejected`: Contract rejected

**Contract Features:**
- Property and Unit linking
- Start and end dates
- Rent amount and deposit amount
- Payment cycle (monthly, quarterly, yearly)
- Electronic signatures (landlord and tenant)
- Termination requests
- Contract renewal
- PDF document generation
- Contract attachments

**Endpoints:**
- `GET /api/contracts` - Get all contracts (protected)
- `GET /api/contracts/:contractId` - Get specific contract (protected)
- `GET /api/contracts/user/:userId` - Get user contracts (protected)
- `POST /api/contracts` - Create contract (protected)
- `POST /api/contracts/request` - Request new contract (protected) - Tenant requests rental
- `PUT /api/contracts/:contractId` - Update contract (protected) - Used for approval/status changes
- `POST /api/contracts/:contractId/sign` - Sign contract (protected) - Electronic signature
- `POST /api/contracts/:contractId/renew` - Renew contract (protected)
- `POST /api/contracts/:contractId/terminate` - Request contract termination (protected)
- `GET /api/contracts/:contractId/statistics` - Contract statistics (protected)

**Contract Workflow:**
1. Tenant requests contract via `POST /api/contracts/request`
2. Contract created with status `pending`
3. Landlord approves via `PUT /api/contracts/:contractId` (status: `active`)
4. Both parties sign via `POST /api/contracts/:contractId/sign`
5. Contract becomes active when both signatures are present
6. Payments are automatically created when contract becomes active

---

## 💳 Payment Routes
**Base**: `/api/payments`

- `GET /api/payments` - Get all payments (protected)
- `GET /api/payments/user/:userId` - Get user payments (protected)
- `GET /api/payments/contract/:contractId` - Get contract payments (protected)
- `POST /api/payments` - Add payment (protected)
- `PUT /api/payments/:paymentId` - Update payment (protected)
- `DELETE /api/payments/:paymentId` - Delete payment (protected)

---

## 🔧 Maintenance Routes
**Base**: `/api/maintenance`

- `GET /api/maintenance` - Get all maintenance requests (protected)
- `GET /api/maintenance/property/:propertyId` - Get property maintenance requests (protected)
- `GET /api/maintenance/tenant/:tenantId` - Get tenant maintenance requests (protected)
- `POST /api/maintenance` - Create maintenance request (protected)
- `PUT /api/maintenance/:id` - Update maintenance status (protected)
- `PUT /api/maintenance/:id/assign` - Assign technician (protected)
- `DELETE /api/maintenance/:id` - Delete maintenance request (protected)

---

## 🏢 Unit Routes
**Base**: `/api/units`

- `GET /api/units` - Get all units (protected)
  - Query params: `propertyId`, `status`
- `GET /api/units/:id` - Get specific unit (protected)
- `GET /api/units/property/:propertyId` - Get property units (protected)
- `POST /api/units` - Add unit (protected)
- `PUT /api/units/:id` - Update unit (protected)
- `DELETE /api/units/:id` - Delete unit (protected)
- `GET /api/units/:id/stats` - Unit statistics (protected)

---

## 🏗️ Building Routes
**Base**: `/api/buildings`

- `GET /api/buildings` - Get all buildings (protected)
- `GET /api/buildings/:id` - Get specific building (protected)
- `POST /api/buildings` - Add building (protected)
- `PUT /api/buildings/:id` - Update building (protected)
- `DELETE /api/buildings/:id` - Delete building (protected)

---

## 💰 Expense Routes
**Base**: `/api/expenses`

- `GET /api/expenses` - Get all expenses (protected)
  - Query params: `propertyId`, `unitId`, `type`, `startDate`, `endDate`
- `POST /api/expenses` - Add expense (protected)
- `PUT /api/expenses/:id` - Update expense (protected)
- `DELETE /api/expenses/:id` - Delete expense (protected)
- `GET /api/expenses/stats` - Expense statistics (protected)

---

## 💵 Deposit Routes
**Base**: `/api/deposits`

- `GET /api/deposits` - Get all deposits (protected)
- `GET /api/deposits/contract/:contractId` - Get contract deposits (protected)
- `POST /api/deposits` - Add deposit (protected)
- `PUT /api/deposits/:id` - Update deposit (protected)

---

## 📋 Invoice Routes
**Base**: `/api/invoices`

- `GET /api/invoices` - Get all invoices (protected)
  - Query param: `contractId`
- `GET /api/invoices/:id` - Get specific invoice (protected)
- `POST /api/invoices` - Create invoice (protected)
- `PUT /api/invoices/:id` - Update invoice (protected)

---

## 📢 Complaint Routes
**Base**: `/api/complaints`

- `GET /api/complaints` - Get all complaints (admin only)
- `POST /api/complaints` - Send complaint (protected)
- `PUT /api/complaints/:id/status` - Update complaint status (admin only)
- `DELETE /api/complaints/:id` - Delete complaint (protected)
- `POST /api/complaints/upload-attachment` - Upload complaint attachment (protected)

---

## 💬 Chat Routes
**Base**: `/api/chats`

- `GET /api/chats/user/:userId` - Get user conversations (protected)
- `GET /api/chats/:userId/:otherUserId` - Get conversation between users (protected)
- `POST /api/chats` - Send message (protected)
- `PUT /api/chats/read` - Mark messages as read (protected)

---

## 🔔 Notification Routes
**Base**: `/api/notifications`

- `GET /api/notifications` - Get all notifications (admin only)
- `GET /api/notifications/user/:userId` - Get user notifications (protected)
- `POST /api/notifications` - Create notification (admin only)
- `POST /api/notifications/direct` - Direct notification (protected)
- `PUT /api/notifications/:id/read` - Mark notification as read (protected)

---

## 🧠 Smart System Routes
**Base**: `/api/smart-system`

- `GET /api/smart-system/recommendations` - Smart recommendations (protected)
  - Query params: `limit`

---

## 👨‍💼 Admin Routes
**Base**: `/api/admins` (admin only)

- `GET /api/admins/users` - Get all users
- `POST /api/admins/users` - Add user
- `PUT /api/admins/users/:id` - Update user
- `DELETE /api/admins/users/:id` - Delete user

---

## 📊 Dashboard Routes

### Admin Dashboard
**Base**: `/api/admin/dashboard`

- `GET /api/admin/dashboard` - Admin statistics (admin only)

### Landlord Dashboard
**Base**: `/api/landlord/dashboard`

- `GET /api/landlord/dashboard` - Landlord statistics (landlord only)

---

## ⚙️ Settings Routes
**Base**: `/api/admin/settings` (admin only)

- `GET /api/admin/settings` - Get all settings
- `PUT /api/admin/settings/:key` - Update setting

---

## 📤 Upload Routes
**Base**: `/api/upload`

- `POST /api/upload` - Upload file/image (protected)
  - Form data: `image` (file)

---

## 🔑 Password Routes
**Base**: `/api/password`

- `POST /api/password/forgot-password` - Request reset code
- `POST /api/password/reset-password` - Reset password

---

## 📍 Property Types Routes
**Base**: `/api/property-types`

- `GET /api/property-types` - Get all property types (public)
  - Query param: `activeOnly=true`
- `POST /api/property-types` - Create type (admin only)
- `PUT /api/property-types/:id` - Update type (admin only)
- `DELETE /api/property-types/:id` - Delete type (admin only)
- `PATCH /api/property-types/:id/toggle` - Toggle type (admin only)

---

## 🤖 AI Routes
**Base**: `/api/ai`

- `POST /api/ai/chat` - Chat with AI (protected)
- `GET /api/ai/health` - Check AI service health (public)
