// routes/landlordDashboardRoutes.js
import express from 'express';
import { getLandlordDashboardStats } from '../controllers/landlordDashboardController.js';
import { protect, authorizeRoles } from '../Middleware/authMiddleware.js';

const router = express.Router();

router.get('/', protect, authorizeRoles('landlord'), getLandlordDashboardStats);

export default router;