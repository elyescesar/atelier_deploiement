const express = require("express");
const path = require("path");
const { connectMongo, getProductsCollection, parseObjectId } = require("./db");
const { seedProducts } = require("./seed");

const app = express();
const port = process.env.PORT || 3000;

app.use(express.json());
app.use((req, res, next) => {
  if (req.path.startsWith("/api/")) {
    res.set("Cache-Control", "no-store");
  }
  next();
});
app.use(express.static(path.join(__dirname, "public")));

function validateProduct(body) {
  const name = typeof body.name === "string" ? body.name.trim() : "";
  const price = Number(body.price);
  const category = typeof body.category === "string" ? body.category.trim() : "General";
  const description = typeof body.description === "string" ? body.description.trim() : "";
  if (!name || Number.isNaN(price) || price < 0) {
    return null;
  }
  return { name, price, category, description };
}

app.get("/api/health", (req, res) => {
  res.json({ status: "ok" });
});

app.post("/api/seed", async (req, res) => {
  try {
    const result = await seedProducts(getProductsCollection());
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get("/api/products", async (req, res) => {
  try {
    const products = await getProductsCollection().find({}).sort({ createdAt: -1 }).toArray();
    res.json(products);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get("/api/products/:id", async (req, res) => {
  try {
    const id = parseObjectId(req.params.id);
    if (!id) {
      return res.status(400).json({ error: "Invalid product id" });
    }
    const product = await getProductsCollection().findOne({ _id: id });
    if (!product) {
      return res.status(404).json({ error: "Product not found" });
    }
    res.json(product);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post("/api/products", async (req, res) => {
  try {
    const data = validateProduct(req.body);
    if (!data) {
      return res.status(400).json({ error: "Invalid name or price" });
    }
    const now = new Date();
    const doc = { ...data, createdAt: now, updatedAt: now };
    const result = await getProductsCollection().insertOne(doc);
    const product = await getProductsCollection().findOne({ _id: result.insertedId });
    res.status(201).json(product);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put("/api/products/:id", async (req, res) => {
  try {
    const id = parseObjectId(req.params.id);
    if (!id) {
      return res.status(400).json({ error: "Invalid product id" });
    }
    const data = validateProduct(req.body);
    if (!data) {
      return res.status(400).json({ error: "Invalid name or price" });
    }
    const update = await getProductsCollection().updateOne(
      { _id: id },
      { $set: { ...data, updatedAt: new Date() } }
    );
    if (update.matchedCount === 0) {
      return res.status(404).json({ error: "Product not found" });
    }
    const product = await getProductsCollection().findOne({ _id: id });
    res.json(product);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete("/api/products/:id", async (req, res) => {
  try {
    const id = parseObjectId(req.params.id);
    if (!id) {
      return res.status(400).json({ error: "Invalid product id" });
    }
    const result = await getProductsCollection().deleteOne({ _id: id });
    if (result.deletedCount === 0) {
      return res.status(404).json({ error: "Product not found" });
    }
    res.json({ deleted: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get("/", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "index.html"));
});

connectMongo()
  .then(async () => {
    await seedProducts(getProductsCollection());
    app.listen(port, "0.0.0.0", () => {
      console.log(`Server listening on ${port}`);
    });
  })
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
