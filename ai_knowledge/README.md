# SHAQATI - Real Estate Management System

## Overview

**SHAQATI** is a comprehensive real estate management application built with **Flutter** (Frontend) and **Node.js/Express** (Backend) with **MongoDB** database.

## Roles

The system supports three types of users:

1. **Admin (System Administrator)**
   - Full system management
   - User and property management
   - Approval of new properties
   - Notification and complaint management

2. **Landlord (Property Owner)**
   - Manage their properties
   - Create and manage contracts
   - Track payments and receipts
   - Manage maintenance requests

3. **Tenant (Renter)**
   - Search for properties
   - Request rental contracts
   - Track payments and dues
   - Send maintenance requests
   - Send complaints

## Main Features

### 1. Property Management
- Add/Edit/Delete properties
- Geographic search on map
- Multiple property types (apartment, villa, office, etc.)
- Two operations: rent or sale

### 2. Contract System
- Create contracts between landlord and tenant
- Track contract status (active, expired, terminated, pending)
- Contract renewal
- Contract termination request
- Electronic signatures
- PDF contract generation
- Contract attachments

**Contract Statuses:**
- `draft`: Draft contract
- `pending`: Pending approval
- `active`: Active contract
- `expiring_soon`: Expiring soon
- `expired`: Expired contract
- `terminated`: Terminated contract
- `rented`: Rented (legacy compatibility)
- `rejected`: Rejected contract

**Contract Features:**
- Property and Unit linking
- Start and end dates
- Rent amount and deposit amount
- Payment cycle (monthly, quarterly, yearly)
- Electronic signatures (landlord and tenant)
- Termination requests
- Contract renewal tracking
- PDF document generation

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

## Technologies Used

### Frontend (Flutter)
- Flutter SDK 3.0+
- Provider for State Management
- Firebase (Notifications, Authentication)
- Google Maps / Flutter Map
- Socket.IO for real-time chat

### Backend (Node.js)
- Express.js
- MongoDB (Mongoose)
- Socket.IO for real-time
- JWT for Authentication
- Firebase Admin SDK
- Cloudinary for images
- Ollama (Local LLM) for AI

## General Structure

```
SHAQATI/
├── backend/          # Node.js/Express Backend
│   ├── controllers/  # Business logic
│   ├── models/       # Mongoose Models
│   ├── routes/       # API Routes
│   ├── Middleware/   # Authentication, Authorization
│   └── utils/        # Utilities
│
└── flutter_application_1/  # Flutter App
    ├── lib/
    │   ├── screens/   # Screens
    │   ├── services/  # API Services
    │   ├── widgets/   # Reusable Widgets
    │   └── models/    # Data Models
```

## API Base URL

- **Development**: `http://localhost:3000/api` (or `http://10.0.2.2:3000/api` for Android Emulator)
- **Production**: `https://shaqati-backend.onrender.com/api`

## Authentication

The system uses **JWT (JSON Web Tokens)** for authentication:
- Token is sent in Header: `Authorization: Bearer <token>`
- Token is stored in `SharedPreferences` in Flutter
- Token contains: userId, role

## Important Notes

- All properties require Admin approval before appearing (status: pending_approval)
- Permissions are enforced in Backend via Middleware
- Chat and notifications work via Socket.IO and Firebase FCM
- Images are uploaded to Cloudinary
- AI works locally via Ollama (Local LLM) - completely free

## AI Assistant & Knowledge Base (ai_knowledge)

- This folder (`ai_knowledge/`) is the **single source of truth** for project documentation used by the AI.
- The backend (`aiController.js`) reads all these files using `loadKnowledgeFiles()` and injects them into the AI `system` prompt.
- The strict RAG endpoint `/api/ai/chat` is allowed to answer **only** from these files and must mention the file names.
- The unified assistant `/api/ai/assistant` also uses these files (in Arabic) in addition to a **live snapshot from MongoDB**.

### How AI sees this README

- Understands project name, roles, technologies, and main features.
- Knows that there are only 3 roles: Admin, Landlord, Tenant.
- Knows that properties require admin approval (`status: "pending_approval"`).
- Uses this file as a high-level overview to explain the system to new users.

### AI + Database Integration (High Level)

- The assistant reads a **live snapshot** from MongoDB at every call:
  - Total users, properties, contracts, payments, buildings, units, expenses, deposits, invoices, maintenance requests, complaints, notifications, reviews.
  - User-specific stats: number of contracts, payments, late payments, maintenance requests, complaints, notifications, chats.
- This snapshot is passed to the AI in the prompt so it can:
  - Answer questions like:
    - "كم عدد العقود عندي؟"
    - "هل عندي دفعات متأخرة؟"
    - "كم عدد العقارات في النظام؟"
  - Combine documentation (from this README and other files) with **real data** from MongoDB.

For deeper technical details, see:
- `DB_SCHEMA.md` for collections and relationships.
- `API_ROUTES.md` for all backend endpoints.
- `PROJECT_DETAILS.md` for features by role.
