import { Router } from "express";
import upload from "../middleware/uploadMiddleware.js";
import { protect } from "../middleware/authMiddleware.js";
import { bookEvent, checkEventAvailability, createEvent, deleteBookedEvent, deleteEvent, getEvent, getEvents, getUserEventBookings, updateEvent } from "../controllers/eventController.js";


const router=Router();
router.post("/", upload.array("images", 5), protect,createEvent);
router.get("/", getEvents);
router.get("/bookings",protect,getUserEventBookings)
router.get("/:id",  getEvent);
router.delete("/:id", protect, deleteEvent);
router.put("/:id", protect, updateEvent);
router.post("/book/:id", protect, bookEvent);
router.delete("/cancel/:id", protect, deleteBookedEvent);
router.post("/check-availability", checkEventAvailability);


export default router;