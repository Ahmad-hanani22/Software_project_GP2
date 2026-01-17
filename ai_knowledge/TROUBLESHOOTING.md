# Troubleshooting - SHAQATI Project

## Common Problems and Solutions

### 1. Connection Problems

#### Backend Not Running
**Symptoms:**
- "Connection refused" error
- Cannot login

**Solution:**
1. Ensure Backend is running: `cd backend && npm start`
2. Check PORT (default: 3000)
3. Check MongoDB connection
4. Check `.env` file

#### Flutter Cannot Connect to Backend
**Symptoms:**
- "Failed to connect" error
- Timeout errors

**Solution:**
1. Check `AppConstants.baseUrl` in `constants.dart`
2. For Android Emulator: use `http://10.0.2.2:3000`
3. For iOS Simulator: use `http://localhost:3000`
4. For Device: use actual device IP

### 2. Authentication Problems

#### Token Expired
**Symptoms:**
- 401 Unauthorized error
- Automatic logout

**Solution:**
1. Login again
2. Check JWT expiration in Backend
3. Check `authMiddleware.js`

#### Cannot Login
**Symptoms:**
- "Invalid credentials" error
- "User not found" error

**Solution:**
1. Check email and password
2. Verify user exists in MongoDB
3. Check `bcryptjs` hashing

### 3. Property Problems

#### Properties Not Showing
**Symptoms:**
- Empty list
- Error fetching properties

**Solution:**
1. Check `status: "available"` in Property
2. For Admin: check approval (`status: "pending_approval"`)
3. Check `propertyController.js`
4. Check Filters in search

#### Cannot Add Property
**Symptoms:**
- 403 Forbidden error
- "Unauthorized" error

**Solution:**
1. Ensure user is `landlord` or `admin`
2. Check `authMiddleware.js` and `ownership.js`
3. Check all required fields

### 4. Contract Problems

#### Cannot Create Contract
**Symptoms:**
- Error creating contract
- "Property not available" error

**Solution:**
1. Check property `status: "available"`
2. Check dates (startDate < endDate)
3. Check no active contract exists for property
4. Check `contractController.js`

**Contract Status Flow:**
- `draft` → `pending` → `active` → `expired`/`terminated`
- Both parties must sign for contract to become `active`
- Check `signatures.landlord.signed` and `signatures.tenant.signed`

#### Contract Not Showing
**Symptoms:**
- Empty contract list
- Error fetching contracts

**Solution:**
1. Check `contractRoutes.js`
2. Check User ID in Token
3. Check Filters (status, userId)

### 5. Payment Problems

#### Cannot Add Payment
**Symptoms:**
- Error adding payment
- "Contract not found" error

**Solution:**
1. Check contract exists
2. Check `contractId` is correct
3. Check `paymentController.js`

### 6. Maintenance Problems

#### Maintenance Request Not Sending
**Symptoms:**
- Error sending request
- "Property not found" error

**Solution:**
1. Check `propertyId` is correct
2. Check user is `tenant` for property
3. Check `maintenanceController.js`

### 7. AI Assistant Problems

#### Ollama Not Running
**Symptoms:**
- "Ollama is not running" error
- "ECONNREFUSED" error

**Solution:**
1. Start Ollama: `ollama serve`
2. Pull model: `ollama pull llama2`
3. Check `OLLAMA_BASE_URL` in `.env`

#### AI Answers Generally
**Symptoms:**
- General answers not related to project
- Not using knowledge files

**Solution:**
1. Check `loadKnowledgeFiles()` in `aiController.js`
2. Check `ai_knowledge/` files exist
3. Check System Prompt (must be strict)
4. Check `temperature` (should be low: 0.1)
5. Check Post-validation is working

### 8. Database Problems

#### MongoDB Connection Error
**Symptoms:**
- "MongoServerError" error
- "Connection timeout" error

**Solution:**
1. Check MongoDB URI in `.env`
2. Check MongoDB is running
3. Check Network/Firewall
4. Check Credentials

#### Data Not Saving
**Symptoms:**
- Records not created
- Save error

**Solution:**
1. Check Mongoose Models
2. Check Validation Rules
3. Check Required Fields
4. Check Console Logs

### 9. Image Problems

#### Images Not Uploading
**Symptoms:**
- Upload error
- "Cloudinary error"

**Solution:**
1. Check Cloudinary credentials in `.env`
2. Check `cloudinary.js`
3. Check File Size (Max size)
4. Check File Format

### 10. Notification Problems

#### Notifications Not Arriving
**Symptoms:**
- No notifications
- FCM error

**Solution:**
1. Check Firebase configuration
2. Check `fcmToken` in User
3. Check `fcmService.js`
4. Check Firebase Console

## General Debugging Steps

1. **Check Console Logs** in Backend and Flutter
2. **Check Network Tab** in Browser/DevTools
3. **Check MongoDB** using MongoDB Compass
4. **Check `.env`** - all variables present
5. **Check Dependencies** - `npm install` and `flutter pub get`
6. **Check Ports** - no conflicts
7. **Check CORS** in Backend

## Important Files for Debugging

- `backend/server.js` - Entry point
- `backend/controllers/*.js` - Business logic
- `flutter_application_1/lib/services/api_service.dart` - API calls
- `flutter_application_1/lib/utils/constants.dart` - Configuration

## General Tips

1. Use `console.log()` frequently in Backend
2. Use `print()` in Flutter
3. Check Status Codes in Responses
4. Check Error Messages in detail
5. Use Postman/Insomnia to test APIs directly
