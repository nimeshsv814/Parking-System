require("dotenv").config();
const express = require("express");
const cors = require("cors");
const morgan = require("morgan");
const bookingRoutes = require("./routes/bookingRoutes");

const app = express();

app.use(cors({ origin: process.env.CORS_ORIGIN || "*" }));
app.use(express.json());
app.use(morgan("dev"));
app.use("/", bookingRoutes);

const start = async () => {
  try {
    const port = process.env.PORT || 4003;
    app.listen(port, () => {
      console.log(`Booking service listening on port ${port}`);
    });
  } catch (error) {
    console.error("Booking service failed to start", error);
    process.exit(1);
  }
};

start();

