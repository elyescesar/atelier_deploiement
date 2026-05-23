const { MongoClient, ObjectId } = require("mongodb");

function buildMongoUri() {
  if (process.env.MONGO_URI) {
    return process.env.MONGO_URI;
  }
  const user = process.env.MONGO_USERNAME || "admin";
  const pass = encodeURIComponent(process.env.MONGO_PASSWORD || "");
  const host = process.env.MONGO_HOST || "mongo";
  const db = process.env.MONGO_DB || "shop";
  if (pass) {
    return `mongodb://${user}:${pass}@${host}:27017/${db}?authSource=admin`;
  }
  return `mongodb://${host}:27017/${db}`;
}

let client;
let db;
let productsCollection;

async function connectMongo() {
  const uri = buildMongoUri();
  client = new MongoClient(uri);
  let attempt = 0;
  while (attempt < 30) {
    try {
      await client.connect();
      db = client.db();
      productsCollection = db.collection("products");
      return productsCollection;
    } catch (err) {
      attempt += 1;
      await new Promise((resolve) => setTimeout(resolve, 2000));
    }
  }
  throw new Error("MongoDB connection failed");
}

function getProductsCollection() {
  return productsCollection;
}

function parseObjectId(id) {
  if (!ObjectId.isValid(id)) {
    return null;
  }
  return new ObjectId(id);
}

module.exports = {
  connectMongo,
  getProductsCollection,
  parseObjectId,
  ObjectId
};
