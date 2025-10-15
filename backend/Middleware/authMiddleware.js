import jwt from "jsonwebtoken";
import User from "../models/User.js";

/* -----------------------------------------
 🔒 التحقق من التوكن (Authentication)
----------------------------------------- */
export const protect = async (req, res, next) => {
  try {
    let token;

    // استخراج التوكن من الهيدر Authorization
    if (req.headers.authorization?.startsWith("Bearer")) {
      token = req.headers.authorization.split(" ")[1];
    }

    // في حال عدم وجود توكن
    if (!token) {
      return res.status(401).json({
        message: "🚫 No token, authorization denied",
      });
    }

    // فك التوكن والتحقق من صحته
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // جلب المستخدم من قاعدة البيانات بدون كلمة المرور
    req.user = await User.findById(decoded.id).select("-passwordHash");

    if (!req.user) {
      return res.status(401).json({ message: "🚫 User not found" });
    }

    // تمرير للمرحلة التالية
    next();
  } catch (error) {
    console.error("❌ Auth error:", error);
    res.status(401).json({
      message: "❌ Token is not valid",
      error: error.message,
    });
  }
};

/* -----------------------------------------
   🧩 التحقق من صلاحيات الدور (Authorization)
----------------------------------------- */
// ✅ التحقق من صلاحيات الدور
export const authorizeRoles = (...roles) => {
  return (req, res, next) => {
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({
        message: "🚫 Access denied: insufficient permissions",
      });
    }
    next();
  };
};

/* -----------------------------------------
   🧍‍♂️ السماح فقط لصاحب الـ :userId أو الأدمن
----------------------------------------- */
export const permitSelfOrAdmin = (paramKey = "userId") => {
  return (req, res, next) => {
    // إذا المستخدم أدمن، مرّره فوراً
    if (req.user.role === "admin") return next();

    // التحقق من أن المستخدم يطلب بيانات نفسه
    if (String(req.user._id) === String(req.params[paramKey])) return next();

    // غير مسموح
    return res.status(403).json({
      message: "🚫 Access denied: self or admin only",
    });
  };
};
