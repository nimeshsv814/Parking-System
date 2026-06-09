const { insertSlotsIfEmpty } = require("../models/Slot");

const ensureSeedSlots = async () => {
  const slots = [
    { slotId: "A-101", location: "North Deck - L1", price: 80, status: "available" },
    { slotId: "A-102", location: "North Deck - L1", price: 80, status: "available" },
    { slotId: "A-103", location: "North Deck - L1", price: 85, status: "available" },
    { slotId: "B-201", location: "East Wing - L2", price: 100, status: "available" },
    { slotId: "B-202", location: "East Wing - L2", price: 100, status: "blocked" },
    { slotId: "C-301", location: "Executive Zone - L3", price: 150, status: "available" },
    { slotId: "C-302", location: "Executive Zone - L3", price: 150, status: "occupied" },
    { slotId: "D-401", location: "Basement - L1", price: 60, status: "available" }
  ];

  const created = await insertSlotsIfEmpty(slots);
  if (created) {
    console.log("Parking seed slots created");
  }
};

module.exports = { ensureSeedSlots };

