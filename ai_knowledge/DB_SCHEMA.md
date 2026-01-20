# Database Schema - MongoDB Collections

## Collections Overview

### 1. **users** (User Model)
```javascript
{
  _id: ObjectId,
  name: String (required),
  email: String (required, unique),
  phone: String,
  role: String (enum: ["tenant", "landlord", "admin"], default: "tenant"),
  passwordHash: String (required),
  profilePicture: String (default: ""),
  isVerified: Boolean (default: false),
  verificationToken: String,
  resetPasswordToken: String,
  resetPasswordExpires: Date,
  fcmToken: String,
  createdAt: Date,
  updatedAt: Date
}
```

### 2. **properties** (Property Model)
```javascript
{
  _id: ObjectId,
  ownerId: ObjectId (ref: "User", required),
  title: String,
  description: String,
  type: String (required), // Dynamic - validated against PropertyType
  operation: String (enum: ["rent", "sale"]),
  price: Number,
  currency: String (default: "USD"),
  country: String,
  city: String,
  address: String,
  location: {
    type: "Point",
    coordinates: [Number] // [longitude, latitude]
  },
  area: Number,
  bedrooms: Number,
  bathrooms: Number,
  amenities: [String],
  images: [String],
  status: String (enum: ["available", "rented", "pending_approval"], default: "pending_approval"),
  verified: Boolean (default: false),
  createdAt: Date,
  updatedAt: Date
}
// Index: location (2dsphere)
```

### 3. **contracts** (Contract Model)
```javascript
{
  _id: ObjectId,
  propertyId: ObjectId (ref: "Property", optional),
  unitId: ObjectId (ref: "Unit", optional),
  tenantId: ObjectId (ref: "User", required),
  landlordId: ObjectId (ref: "User", required),
  startDate: Date (required),
  endDate: Date (required),
  rentAmount: Number (required),
  depositAmount: Number,
  paymentCycle: String (enum: ["monthly", "quarterly", "yearly"], default: "monthly"),
  status: String (enum: ["draft", "pending", "active", "expiring_soon", "expired", "terminated", "rented", "rejected"], default: "pending"),
  pdfUrl: String,
  attachments: [{
    url: String,
    name: String,
    uploadedAt: Date
  }],
  signatures: {
    landlord: {
      signed: Boolean (default: false),
      signedAt: Date
    },
    tenant: {
      signed: Boolean (default: false),
      signedAt: Date
    }
  },
  renewalCount: Number (default: 0),
  lastRenewedAt: Date,
  termination: {
    requestedBy: ObjectId (ref: "User"),
    reason: String,
    requestedAt: Date,
    approvedAt: Date
  },
  signedAt: Date,
  createdAt: Date,
  updatedAt: Date
}
```

**Contract System Details:**
- Contracts link properties/units to tenants and landlords
- Status flow: draft → pending → active → expired/terminated
- Electronic signatures required from both parties
- Automatic payment creation when contract becomes active
- Supports contract renewal and termination requests
- PDF generation for contract documents

### 4. **payments** (Payment Model)
```javascript
{
  _id: ObjectId,
  contractId: ObjectId (ref: "Contract", required),
  amount: Number (required),
  method: String (required), // "cash", "bank_transfer", etc.
  status: String (enum: ["pending", "completed", "failed"], default: "pending"),
  receiptUrl: String,
  paidAt: Date,
  date: Date,
  createdAt: Date,
  updatedAt: Date
}
```

### 5. **units** (Unit Model)
```javascript
{
  _id: ObjectId,
  propertyId: ObjectId (ref: "Property", required),
  unitNumber: String (required),
  floor: Number,
  area: Number,
  bedrooms: Number,
  bathrooms: Number,
  rent: Number,
  status: String (enum: ["available", "occupied", "maintenance"], default: "available"),
  amenities: [String],
  createdAt: Date,
  updatedAt: Date
}
// Index: { propertyId: 1, unitNumber: 1 } (unique)
```

### 6. **buildings** (Building Model)
```javascript
{
  _id: ObjectId,
  name: String (required),
  ownerId: ObjectId (ref: "User", required),
  address: String (required),
  city: String,
  country: String,
  location: {
    type: "Point",
    coordinates: [Number]
  },
  totalFloors: Number (default: 1),
  totalUnits: Number (default: 0),
  description: String,
  images: [String],
  amenities: [String],
  managementCompany: String,
  yearBuilt: Number,
  createdAt: Date,
  updatedAt: Date
}
// Index: location (2dsphere), ownerId
```

### 7. **maintenancerequests** (MaintenanceRequest Model)
```javascript
{
  _id: ObjectId,
  propertyId: ObjectId (ref: "Property", required),
  requestedBy: ObjectId (ref: "User", required),
  description: String (required),
  images: [String],
  status: String (enum: ["pending", "in_progress", "completed", "cancelled"], default: "pending"),
  technicianName: String,
  completedAt: Date,
  createdAt: Date,
  updatedAt: Date
}
```

### 8. **complaints** (Complaint Model)
```javascript
{
  _id: ObjectId,
  submittedBy: ObjectId (ref: "User", required),
  againstUserId: ObjectId (ref: "User", optional),
  description: String (required),
  category: String (enum: ["financial", "maintenance", "behavior"], required),
  status: String (enum: ["pending", "reviewing", "resolved", "rejected"], default: "pending"),
  attachments: [{
    url: String,
    name: String
  }],
  resolution: String,
  resolvedAt: Date,
  createdAt: Date,
  updatedAt: Date
}
```

### 9. **expenses** (Expense Model)
```javascript
{
  _id: ObjectId,
  propertyId: ObjectId (ref: "Property", optional),
  unitId: ObjectId (ref: "Unit", optional),
  type: String (required), // "maintenance", "utility", "tax", etc.
  amount: Number (required),
  description: String,
  date: Date (required),
  createdAt: Date,
  updatedAt: Date
}
```

### 10. **deposits** (Deposit Model)
```javascript
{
  _id: ObjectId,
  contractId: ObjectId (ref: "Contract", required),
  amount: Number (required),
  status: String (enum: ["pending", "held", "returned", "forfeited"], default: "pending"),
  returnedAt: Date,
  createdAt: Date,
  updatedAt: Date
}
```

### 11. **invoices** (Invoice Model)
```javascript
{
  _id: ObjectId,
  contractId: ObjectId (ref: "Contract", optional),
  invoiceNumber: String (required, unique),
  items: [{
    description: String,
    quantity: Number,
    unitPrice: Number,
    total: Number
  }],
  totalAmount: Number (required),
  status: String (enum: ["draft", "sent", "paid", "overdue"], default: "draft"),
  dueDate: Date,
  paidAt: Date,
  createdAt: Date,
  updatedAt: Date
}
```

### 12. **chats** (Chat Model)
```javascript
{
  _id: ObjectId,
  senderId: ObjectId (ref: "User", required),
  receiverId: ObjectId (ref: "User", required),
  message: String (required),
  attachments: [String],
  read: Boolean (default: false),
  readAt: Date,
  createdAt: Date,
  updatedAt: Date
}
```

### 13. **notifications** (Notification Model)
```javascript
{
  _id: ObjectId,
  recipientId: ObjectId (ref: "User", required),
  title: String (required),
  message: String (required),
  type: String (enum: ["system", "contract", "payment", "maintenance"], default: "system"),
  read: Boolean (default: false),
  readAt: Date,
  actorId: ObjectId (ref: "User"), // Who triggered the event
  entityType: String, // "property", "contract", etc.
  entityId: ObjectId, // ID of the entity
  link: String,
  createdAt: Date,
  updatedAt: Date
}
```

### 14. **propertytypes** (PropertyType Model)
```javascript
{
  _id: ObjectId,
  name: String (required, unique), // "apartment", "villa", etc.
  displayName: String (required),
  icon: String,
  description: String,
  order: Number (default: 0),
  isActive: Boolean (default: true),
  createdAt: Date,
  updatedAt: Date
}
// Index: isActive
```

### 15. **userprofiles** (UserProfile Model - for smart analysis)
```javascript
{
  _id: ObjectId,
  userId: ObjectId (ref: "User", required, unique),
  budgetRange: {
    min: Number,
    max: Number,
    preferred: Number,
    currency: String (default: "USD"),
    confidence: Number (default: 0) // 0-100
  },
  preferredLocations: [{
    city: String,
    area: String,
    priority: Number (default: 1),
    lastSearched: Date
  }],
  preferredPropertyTypes: [{
    type: String,
    priority: Number (default: 1),
    lastSearched: Date
  }],
  rentalDurationPreference: {
    min: Number,
    max: Number,
    preferred: Number
  },
  priceSensitivity: String (enum: ["low", "medium", "high"], default: "medium"),
  qualityVsPrice: String (enum: ["quality", "balanced", "price"], default: "balanced"),
  userType: String (enum: ["student", "family", "employee", "investor", "unknown"], default: "unknown"),
  createdAt: Date,
  updatedAt: Date
}
```

### 16. **userbehaviors** (UserBehavior Model - for behavior tracking)
```javascript
{
  _id: ObjectId,
  userId: ObjectId (ref: "User", required),
  propertyViews: [{
    propertyId: ObjectId (ref: "Property"),
    viewCount: Number (default: 1),
    totalViewDuration: Number (default: 0),
    lastViewedAt: Date,
    firstViewedAt: Date
  }],
  favoriteProperties: [{
    propertyId: ObjectId (ref: "Property"),
    addedAt: Date
  }],
  searchHistory: [{
    query: String,
    filters: Object,
    resultsCount: Number,
    searchedAt: Date
  }],
  createdAt: Date,
  updatedAt: Date
}
// Indexes: userId, propertyViews.propertyId, favoriteProperties.propertyId
```

### 17. **systemsettings** (SystemSetting Model)
```javascript
{
  _id: ObjectId,
  key: String (required, unique),
  value: Mixed (required), // Can be String, Number, Boolean, Object
  type: String (required), // "string", "number", "boolean", "json"
  label: String (required),
  category: String (default: "General"),
  description: String,
  options: [String], // For select type variables
  createdAt: Date,
  updatedAt: Date
}
```

### 18. **reviews** (Review Model)
```javascript
{
  _id: ObjectId,
  propertyId: ObjectId (ref: "Property", required),
  userId: ObjectId (ref: "User", required),
  rating: Number (required, min: 1, max: 5),
  comment: String,
  createdAt: Date,
  updatedAt: Date
}
```

### 19. **occupancyhistory** (OccupancyHistory Model)
```javascript
{
  _id: ObjectId,
  unitId: ObjectId (ref: "Unit", required),
  tenantId: ObjectId (ref: "User", required),
  contractId: ObjectId (ref: "Contract", optional),
  from: Date (required),
  to: Date,
  createdAt: Date,
  updatedAt: Date
}
```

### 20. **ownerships** (Ownership Model)
```javascript
{
  _id: ObjectId,
  propertyId: ObjectId (ref: "Property", required),
  ownerId: ObjectId (ref: "User", required),
  percentage: Number (required, 0-100),
  isPrimary: Boolean (default: false), // Main owner
  notes: String,
  createdAt: Date,
  updatedAt: Date
}
// Index: { propertyId, ownerId } unique
// Validation: total percentage for a property cannot exceed 100%
```

### 21. **propertyhistories** (PropertyHistory Model)
```javascript
{
  _id: ObjectId,
  propertyId: ObjectId (ref: "Property", required),
  action: String (enum: [
    "created", "updated", "deleted",
    "status_changed", "price_changed",
    "verified", "unit_added", "unit_removed",
    "contract_added", "contract_removed"
  ]),
  performedBy: ObjectId (ref: "User", required),
  changes: Mixed,      // JSON with old/new values
  description: String, // Human readable description
  createdAt: Date,
  updatedAt: Date
}
// Indexes: { propertyId, createdAt }, { performedBy }
```

### 22. **propertyanalytics** (PropertyAnalytics Model)
```javascript
{
  _id: ObjectId,
  propertyId: ObjectId (ref: "Property", required, unique),

  // View statistics
  viewStats: {
    totalViews: Number,
    uniqueViews: Number,
    averageViewDuration: Number, // seconds
    lastViewedAt: Date
  },

  // Favorites
  favoriteStats: {
    totalFavorites: Number,
    uniqueUsers: Number
  },

  // Price analysis
  priceAnalysis: {
    currentPrice: Number,
    averageMarketPrice: Number,
    priceVsMarket: Number, // % difference
    isOverpriced: Boolean,
    isUnderpriced: Boolean,
    priceHistory: [{ price: Number, date: Date }]
  },

  // Trust score
  trustScore: {
    score: Number, // 0-100
    factors: {
      ownerRating: Number,
      complaintCount: Number,
      maintenanceCount: Number,
      averageResponseTime: Number,
      reviewRating: Number,
      verified: Boolean,
      contractStability: Number
    },
    lastCalculated: Date
  },

  // Maintenance analysis
  maintenanceAnalysis: {
    totalRequests: Number,
    resolvedCount: Number,
    pendingCount: Number,
    averageResolutionTime: Number,
    maintenanceLevel: String, // "low" | "medium" | "high"
    recurringIssues: [String]
  },

  // Occupancy analysis
  occupancyAnalysis: {
    totalOccupancyDays: Number,
    averageOccupancyDuration: Number,
    vacancyRate: Number,
    lastOccupiedAt: Date,
    lastVacantAt: Date,
    occupancyHistory: [{ from: Date, to: Date, duration: Number }]
  },

  // Demand level
  demandLevel: {
    type: String, // "low" | "medium" | "high" | "very_high"
    factors: {
      viewCount: Number,
      favoriteCount: Number,
      inquiryCount: Number,
      searchFrequency: Number
    },
    lastCalculated: Date
  },

  // Cost analysis
  costAnalysis: {
    monthlyOperatingCost: Number,
    averageExpenses: Number,
    expenseBreakdown: {
      maintenance: Number,
      tax: Number,
      utility: Number,
      management: Number,
      insurance: Number,
      other: Number
    }
  },

  // Recommendation score
  recommendationScore: {
    score: Number, // 0-100
    factors: {
      priceValue: Number,
      trustScore: Number,
      maintenanceLevel: Number,
      demandLevel: Number,
      locationScore: Number
    },
    lastCalculated: Date
  },

  // Market comparison
  marketComparison: {
    similarPropertiesCount: Number,
    averagePrice: Number,
    averageRating: Number,
    position: String // "below_average" | "average" | "above_average"
  },

  alerts: [{
    type: String, // e.g. "price_drop", "high_demand", "low_trust"
    message: String,
    createdAt: Date,
    isRead: Boolean
  }],

  lastUpdated: Date,
  createdAt: Date,
  updatedAt: Date
}
// Indexes: propertyId, trustScore.score, recommendationScore.score, demandLevel
```

## Relationships

- **User** ←→ **Property** (one-to-many: ownerId)
- **Property** ←→ **Contract** (one-to-many: propertyId)
- **Unit** ←→ **Contract** (one-to-many: unitId)
- **Contract** ←→ **Payment** (one-to-many: contractId)
- **Contract** ←→ **Deposit** (one-to-many: contractId)
- **Contract** ←→ **Invoice** (one-to-many: contractId)
- **Building** ←→ **Unit** (one-to-many: propertyId)
- **Property** ←→ **MaintenanceRequest** (one-to-many: propertyId)
- **User** ←→ **Chat** (many-to-many: senderId, receiverId)
- **Property** ←→ **Review** (one-to-many: propertyId)
- **Property** ←→ **Ownership** (one-to-many: propertyId, multiple owners with percentages)
- **Property** ←→ **PropertyHistory** (one-to-many: timeline of changes)
- **Property** ←→ **PropertyAnalytics** (one-to-one: analytics document per property)

## Indexes

- `properties.location` - 2dsphere (for geographic search)
- `buildings.location` - 2dsphere
- `units.{propertyId, unitNumber}` - unique composite
- `userprofiles.userId` - unique
- `userbehaviors.userId` - index
- `propertytypes.isActive` - index
