import jwt from "jsonwebtoken";
import User from "../models/User.js";


export const protect = async (req, res, next) => {
  try {
    let token;

    if (req.headers.authorization?.startsWith("Bearer")) {
      token = req.headers.authorization.split(" ")[1];
    }

    if (!token) {
      return res.status(401).json({
        message: "🚫 No token, authorization denied",
      });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);

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


export const permitSelfOrAdmin = (paramKey = "userId") => {
  return (req, res, next) => {
    if (req.user.role === "admin") return next();

    if (String(req.user._id) === String(req.params[paramKey])) return next();

    return res.status(403).json({
      message: "🚫 Access denied: self or admin only",
    });
  };
};
