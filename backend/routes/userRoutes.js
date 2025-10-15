import express from "express";
import { registerUser, loginUser } from "../controllers/userController.js";

const router = express.Router();

// مسار التسجيل
router.post("/register", registerUser);

// مسار تسجيل الدخول
router.post("/login", loginUser);

export default router;
