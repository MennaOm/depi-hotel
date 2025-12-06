import { Router } from "express";
import { chatWithAi } from "../controllers/chatController.js";


const router=Router();

router.post("/", chatWithAi);

export default router