const express = require("express");
const { MongoClient } = require("mongodb");

const app = express();
const port = process.env.PORT || 3000;
const mongoUri = process.env.MONGO_URI || "mongodb://mongo:27017/shop";

let db;
let productsCollection;

const defaultProducts = [
  { name: "Laptop", price: 1200 },
  { name: "Phone", price: 800 }
];

async function connectMongo() {
  const client = new MongoClient(mongoUri);
  let attempt = 0;
  while (attempt < 30) {
    try {
      await client.connect();
      db = client.db();
      productsCollection = db.collection("products");
      const count = await productsCollection.countDocuments();
      if (count === 0) {
        await productsCollection.insertMany(defaultProducts);
      }
      return;
    } catch (err) {
      attempt += 1;
      await new Promise((resolve) => setTimeout(resolve, 2000));
    }
  }
  throw new Error("MongoDB connection failed");
}

function renderPage(products) {
  const items = products
    .map((p) => `<li>${p.name} $${p.price}</li>`)
    .join("");
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>E-Commerce Store</title>
  <style>
    body { font-family: Arial, sans-serif; max-width: 600px; margin: 40px auto; padding: 0 20px; }
    h1 { color: #1a1a2e; }
    ul { line-height: 1.8; font-size: 1.1rem; }
  </style>
</head>
<body>
  <h1>E-Commerce Store</h1>
  <ul>${items}</ul>
</body>
</html>`;
}

app.get("/api/health", (req, res) => {
  res.json({ status: "ok" });
});

app.get("/api/products", async (req, res) => {
  const products = await productsCollection.find({}).toArray();
  res.json(products);
});

app.get("/", async (req, res) => {
  const products = await productsCollection.find({}).toArray();
  res.type("html").send(renderPage(products));
});

connectMongo()
  .then(() => {
    app.listen(port, "0.0.0.0", () => {
      console.log(`Server listening on ${port}`);
    });
  })
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
