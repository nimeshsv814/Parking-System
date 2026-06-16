const express = require("express");
const {
  getDemandPrediction,
  getPaymentRisk,
  getRecommendation,
} = require("../controllers/aiController");
const { authenticate } = require("../middleware/auth");

const router = express.Router();

router.get("/recommend-slot", authenticate, getRecommendation);
router.get("/demand-prediction", authenticate, getDemandPrediction);
router.get("/payment-risk/:bookingId", authenticate, getPaymentRisk);

module.exports = router;
