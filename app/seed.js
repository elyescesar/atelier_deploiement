const defaultProducts = [
  {
    name: "Laptop",
    price: 1200,
    category: "Electronics",
    description: "Lightweight laptop for work and study."
  },
  {
    name: "Phone",
    price: 800,
    category: "Electronics",
    description: "Fast smartphone with a great camera."
  },
  {
    name: "Headphones",
    price: 150,
    category: "Audio",
    description: "Wireless noise-cancelling headphones."
  },
  {
    name: "Keyboard",
    price: 90,
    category: "Accessories",
    description: "Mechanical keyboard with RGB backlight."
  }
];

async function seedProducts(collection) {
  const count = await collection.countDocuments();
  if (count > 0) {
    return { seeded: false, count };
  }
  const now = new Date();
  const docs = defaultProducts.map((product) => ({
    ...product,
    createdAt: now,
    updatedAt: now
  }));
  await collection.insertMany(docs);
  return { seeded: true, count: docs.length };
}

module.exports = { seedProducts, defaultProducts };
