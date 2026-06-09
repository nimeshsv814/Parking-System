require("dotenv").config();
const express = require("express");
const cors = require("cors");
const morgan = require("morgan");
const slotRoutes = require("./routes/slotRoutes");
const { ensureSeedSlots } = require("./scripts/seed");

const app = express();

app.use(cors({ origin: process.env.CORS_ORIGIN || "*" }));
app.use(express.json());
app.use(morgan("dev"));
app.use("/", slotRoutes);

const start = async () => {
  try {
    const port = process.env.PORT || 4002;
    app.listen(port, () => {
      console.log(`Parking service listening on port ${port}`);
    });
    ensureSeedSlots().catch((error) => {
      console.error("Parking seed failed", error);
    });
  } catch (error) {
    console.error("Parking service failed to start", error);
    process.exit(1);
  }
};

start();

