const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const {
  DynamoDBDocumentClient,
  GetCommand,
  PutCommand,
  ScanCommand,
  UpdateCommand,
} = require("@aws-sdk/lib-dynamodb");

const tableName = process.env.PARKING_SLOTS_TABLE || "smart-parking-slots";
const client = DynamoDBDocumentClient.from(
  new DynamoDBClient({ region: process.env.AWS_REGION || "us-east-1" }),
  { marshallOptions: { removeUndefinedValues: true } }
);

const scanAll = async () => {
  const items = [];
  let ExclusiveStartKey;

  do {
    const response = await client.send(
      new ScanCommand({
        TableName: tableName,
        ExclusiveStartKey,
      })
    );
    items.push(...(response.Items || []));
    ExclusiveStartKey = response.LastEvaluatedKey;
  } while (ExclusiveStartKey);

  return items;
};

const sortSlots = (slots) =>
  [...slots].sort((left, right) => {
    const locationCompare = String(left.location || "").localeCompare(String(right.location || ""));
    return locationCompare || String(left.slotId || "").localeCompare(String(right.slotId || ""));
  });

const listSlots = async () => sortSlots(await scanAll());

const listAvailableSlots = async () => {
  const slots = await scanAll();
  return sortSlots(slots.filter((slot) => slot.status === "available"));
};

const getSlot = async (slotId) => {
  const response = await client.send(
    new GetCommand({
      TableName: tableName,
      Key: { slotId },
    })
  );

  return response.Item || null;
};

const createSlot = async (slot) => {
  const now = new Date().toISOString();
  const item = { ...slot, createdAt: now, updatedAt: now };

  await client.send(
    new PutCommand({
      TableName: tableName,
      Item: item,
      ConditionExpression: "attribute_not_exists(slotId)",
    })
  );

  return item;
};

const updateSlotStatus = async (slotId, status) => {
  const now = new Date().toISOString();
  const removeBooking = status === "available" || status === "blocked";
  const response = await client.send(
    new UpdateCommand({
      TableName: tableName,
      Key: { slotId },
      UpdateExpression: removeBooking
        ? "SET #status = :status, updatedAt = :updatedAt REMOVE bookingId"
        : "SET #status = :status, updatedAt = :updatedAt",
      ConditionExpression: "attribute_exists(slotId)",
      ExpressionAttributeNames: { "#status": "status" },
      ExpressionAttributeValues: { ":status": status, ":updatedAt": now },
      ReturnValues: "ALL_NEW",
    })
  );

  return response.Attributes;
};

const reserveSlot = async (slotId, bookingId) => {
  const now = new Date().toISOString();
  const response = await client.send(
    new UpdateCommand({
      TableName: tableName,
      Key: { slotId },
      UpdateExpression: "SET #status = :reserved, bookingId = :bookingId, updatedAt = :updatedAt",
      ConditionExpression: "attribute_exists(slotId) AND #status = :available",
      ExpressionAttributeNames: { "#status": "status" },
      ExpressionAttributeValues: {
        ":available": "available",
        ":reserved": "reserved",
        ":bookingId": bookingId || null,
        ":updatedAt": now,
      },
      ReturnValues: "ALL_NEW",
    })
  );

  return response.Attributes;
};

const releaseSlot = async (slotId) => {
  const slot = await getSlot(slotId);
  if (!slot) {
    return null;
  }
  if (slot.status === "blocked") {
    return slot;
  }

  return updateSlotStatus(slotId, "available");
};

const occupySlot = async (slotId, bookingId) => {
  const now = new Date().toISOString();
  const response = await client.send(
    new UpdateCommand({
      TableName: tableName,
      Key: { slotId },
      UpdateExpression: "SET #status = :status, bookingId = :bookingId, updatedAt = :updatedAt",
      ConditionExpression: "attribute_exists(slotId)",
      ExpressionAttributeNames: { "#status": "status" },
      ExpressionAttributeValues: {
        ":status": "occupied",
        ":bookingId": bookingId || null,
        ":updatedAt": now,
      },
      ReturnValues: "ALL_NEW",
    })
  );

  return response.Attributes;
};

const repairZeroPrices = async (fallbackPrice) => {
  const slots = await scanAll();
  for (const slot of slots) {
    const numericPrice = Number(slot.price);
    if (!Number.isFinite(numericPrice) || numericPrice <= 0) {
      await client.send(
        new UpdateCommand({
          TableName: tableName,
          Key: { slotId: slot.slotId },
          UpdateExpression: "SET price = :price, updatedAt = :updatedAt",
          ExpressionAttributeValues: {
            ":price": fallbackPrice,
            ":updatedAt": new Date().toISOString(),
          },
        })
      );
    }
  }
};

const hasAnySlots = async () => {
  const response = await client.send(
    new ScanCommand({
      TableName: tableName,
      Select: "COUNT",
      Limit: 1,
    })
  );

  return Number(response.Count || 0) > 0;
};

const insertSlotsIfEmpty = async (slots) => {
  if (await hasAnySlots()) {
    return false;
  }

  for (const slot of slots) {
    await createSlot(slot);
  }

  return true;
};

module.exports = {
  createSlot,
  getSlot,
  insertSlotsIfEmpty,
  listAvailableSlots,
  listSlots,
  occupySlot,
  releaseSlot,
  repairZeroPrices,
  reserveSlot,
  updateSlotStatus,
};
