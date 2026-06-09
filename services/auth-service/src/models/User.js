const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const {
  DynamoDBDocumentClient,
  GetCommand,
  PutCommand,
  ScanCommand,
} = require("@aws-sdk/lib-dynamodb");

const tableName = process.env.AUTH_USERS_TABLE || "smart-parking-users";
const client = DynamoDBDocumentClient.from(
  new DynamoDBClient({ region: process.env.AWS_REGION || "us-east-1" }),
  { marshallOptions: { removeUndefinedValues: true } }
);

const normalizeEmail = (email) => email.toLowerCase().trim();

const serializeUser = (user) => ({
  ...user,
  _id: user.userId,
  id: user.userId,
});

const findByEmail = async (email) => {
  const normalizedEmail = normalizeEmail(email);
  const response = await client.send(
    new GetCommand({
      TableName: tableName,
      Key: { userId: normalizedEmail },
    })
  );

  return response.Item ? serializeUser(response.Item) : null;
};

const createUser = async ({ name, email, password, role }) => {
  const normalizedEmail = normalizeEmail(email);
  const now = new Date().toISOString();
  const user = {
    userId: normalizedEmail,
    name,
    email: normalizedEmail,
    password,
    role,
    createdAt: now,
    updatedAt: now,
  };

  await client.send(
    new PutCommand({
      TableName: tableName,
      Item: user,
      ConditionExpression: "attribute_not_exists(userId)",
    })
  );

  return serializeUser(user);
};

const hasAnyUsers = async () => {
  const response = await client.send(
    new ScanCommand({
      TableName: tableName,
      Select: "COUNT",
      Limit: 1,
    })
  );

  return Number(response.Count || 0) > 0;
};

const insertUsersIfEmpty = async (users) => {
  if (await hasAnyUsers()) {
    return false;
  }

  for (const user of users) {
    await createUser(user);
  }

  return true;
};

module.exports = { createUser, findByEmail, insertUsersIfEmpty };
