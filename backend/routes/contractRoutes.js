// routes/contractRoutes.js
import express from "express";
import {
  addContract,
  getAllContracts,
  getContractById,
  getContractsByUser,
  updateContract,
  deleteContract,
} from "../controllers/contractController.js";

import {
  protect,
  authorizeRoles,
  permitSelfOrAdmin,
} from "../Middleware/authMiddleware.js";
import { isContractPartyOrAdmin } from "../Middleware/ownership.js";

const router = express.Router();

router.get("/", protect, authorizeRoles("admin"), getAllContracts);


router.post(
  "/",
  protect,
  authorizeRoles("tenant", "landlord", "admin"),
  addContract
);

/* عرض عقد واحد (يخص المستأجر أو المالك أو الأدمن) */
router.get("/:id", protect, isContractPartyOrAdmin, getContractById);

/* عرض عقود مستخدم معيّن (المستخدم نفسه أو أدمن) */
router.get(
  "/user/:userId",
  protect,
  permitSelfOrAdmin("userId"),
  getContractsByUser
);

/* تحديث عقد (المالك أو الأدمن فقط) */
router.put(
  "/:id",
  protect,
  authorizeRoles("landlord", "admin"),
  isContractPartyOrAdmin,
  updateContract
);

/* حذف عقد (الأدمن فقط) */
router.delete("/:id", protect, authorizeRoles("admin"), deleteContract);

export default router;
