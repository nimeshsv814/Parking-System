const Slot = require("../models/Slot");

const DEFAULT_SLOT_PRICE = 50;

const getAffordablePrice = (price) => {
  const numericPrice = Number(price);
  return Number.isFinite(numericPrice) && numericPrice > 0 ? numericPrice : DEFAULT_SLOT_PRICE;
};

const normalizeSlotPrice = (slot) => ({ ...slot, price: getAffordablePrice(slot.price) });

const listSlots = async (_req, res) => {
  try {
    await Slot.repairZeroPrices(DEFAULT_SLOT_PRICE);
    const slots = await Slot.listSlots();
    return res.json(slots.map(normalizeSlotPrice));
  } catch (error) {
    return res.status(500).json({ message: "Failed to load slots", error: error.message });
  }
};

const listAvailableSlots = async (_req, res) => {
  try {
    await Slot.repairZeroPrices(DEFAULT_SLOT_PRICE);
    const slots = await Slot.listAvailableSlots();
    return res.json(slots.map(normalizeSlotPrice));
  } catch (error) {
    return res.status(500).json({ message: "Failed to load available slots", error: error.message });
  }
};

const createSlot = async (req, res) => {
  try {
    const { slotId, location, price } = req.body;
    if (!slotId || !location || Number.isNaN(Number(price))) {
      return res.status(400).json({ message: "slotId, location, and numeric price are required" });
    }

    const slot = await Slot.createSlot({
      slotId,
      location,
      price: getAffordablePrice(price),
      status: "available",
    });

    return res.status(201).json({ message: "Slot created", slot });
  } catch (error) {
    if (error.name === "ConditionalCheckFailedException") {
      return res.status(409).json({ message: "Slot already exists" });
    }
    return res.status(500).json({ message: "Failed to create slot", error: error.message });
  }
};

const updateSlotStatus = async (req, res) => {
  try {
    const { slotId } = req.params;
    const { status } = req.body;
    const allowedStatuses = ["available", "reserved", "occupied", "blocked"];

    if (!allowedStatuses.includes(status)) {
      return res.status(400).json({ message: "Invalid slot status" });
    }

    const slot = await Slot.updateSlotStatus(slotId, status);
    return res.json({ message: "Slot status updated", slot: normalizeSlotPrice(slot) });
  } catch (error) {
    if (error.name === "ConditionalCheckFailedException") {
      return res.status(404).json({ message: "Slot not found" });
    }
    return res.status(500).json({ message: "Failed to update slot", error: error.message });
  }
};

const getSlotInternal = async (req, res) => {
  try {
    await Slot.repairZeroPrices(DEFAULT_SLOT_PRICE);
    const slot = await Slot.getSlot(req.params.slotId);
    if (!slot) {
      return res.status(404).json({ message: "Slot not found" });
    }
    return res.json(normalizeSlotPrice(slot));
  } catch (error) {
    return res.status(500).json({ message: "Failed to load slot", error: error.message });
  }
};

const reserveSlotInternal = async (req, res) => {
  try {
    const { slotId } = req.params;
    const { bookingId } = req.body;
    const slot = await Slot.reserveSlot(slotId, bookingId);
    return res.json({ message: "Slot reserved", slot: normalizeSlotPrice(slot) });
  } catch (error) {
    if (error.name === "ConditionalCheckFailedException") {
      const slot = await Slot.getSlot(req.params.slotId);
      if (!slot) {
        return res.status(404).json({ message: "Slot not found" });
      }
      return res.status(409).json({ message: "Slot is not available" });
    }
    return res.status(500).json({ message: "Failed to reserve slot", error: error.message });
  }
};

const releaseSlotInternal = async (req, res) => {
  try {
    const slot = await Slot.releaseSlot(req.params.slotId);
    if (!slot) {
      return res.status(404).json({ message: "Slot not found" });
    }

    return res.json({ message: "Slot released", slot: normalizeSlotPrice(slot) });
  } catch (error) {
    return res.status(500).json({ message: "Failed to release slot", error: error.message });
  }
};

const occupySlotInternal = async (req, res) => {
  try {
    const slot = await Slot.occupySlot(req.params.slotId, req.body.bookingId);
    return res.json({ message: "Slot marked occupied", slot: normalizeSlotPrice(slot) });
  } catch (error) {
    if (error.name === "ConditionalCheckFailedException") {
      return res.status(404).json({ message: "Slot not found" });
    }
    return res.status(500).json({ message: "Failed to occupy slot", error: error.message });
  }
};

module.exports = {
  createSlot,
  getSlotInternal,
  listAvailableSlots,
  listSlots,
  occupySlotInternal,
  releaseSlotInternal,
  reserveSlotInternal,
  updateSlotStatus,
};
