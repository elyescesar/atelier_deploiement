const productsEl = document.getElementById("products");
const emptyState = document.getElementById("empty-state");
const productCount = document.getElementById("product-count");
const formPanel = document.getElementById("form-panel");
const formTitle = document.getElementById("form-title");
const productForm = document.getElementById("product-form");
const productIdInput = document.getElementById("product-id");
const nameInput = document.getElementById("name");
const priceInput = document.getElementById("price");
const categoryInput = document.getElementById("category");
const descriptionInput = document.getElementById("description");
const cardTemplate = document.getElementById("card-template");

async function api(path, options = {}) {
  const response = await fetch(path, {
    headers: { "Content-Type": "application/json" },
    ...options
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(data.error || "Request failed");
  }
  return data;
}

function formatPrice(value) {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    maximumFractionDigits: 0
  }).format(value);
}

function showForm(editProduct = null) {
  formPanel.classList.remove("hidden");
  if (editProduct) {
    formTitle.textContent = "Edit product";
    productIdInput.value = editProduct._id;
    nameInput.value = editProduct.name;
    priceInput.value = editProduct.price;
    categoryInput.value = editProduct.category || "";
    descriptionInput.value = editProduct.description || "";
  } else {
    formTitle.textContent = "Add product";
    productIdInput.value = "";
    productForm.reset();
  }
  nameInput.focus();
}

function hideForm() {
  formPanel.classList.add("hidden");
  productForm.reset();
  productIdInput.value = "";
}

function renderProducts(products) {
  productsEl.innerHTML = "";
  productCount.textContent = `${products.length} item${products.length === 1 ? "" : "s"}`;
  emptyState.classList.toggle("hidden", products.length > 0);

  products.forEach((product) => {
    const node = cardTemplate.content.cloneNode(true);
    const card = node.querySelector(".card");
    node.querySelector(".tag").textContent = product.category || "General";
    node.querySelector(".card-title").textContent = product.name;
    node.querySelector(".card-desc").textContent = product.description || "No description.";
    node.querySelector(".card-price").textContent = formatPrice(product.price);

    node.querySelector(".edit").addEventListener("click", () => showForm(product));
    node.querySelector(".delete").addEventListener("click", async () => {
      if (!confirm(`Delete ${product.name}?`)) {
        return;
      }
      await api(`/api/products/${product._id}`, { method: "DELETE" });
      await loadProducts();
    });

    productsEl.appendChild(node);
  });
}

async function loadProducts() {
  const products = await api("/api/products");
  renderProducts(products);
}

productForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const payload = {
    name: nameInput.value,
    price: Number(priceInput.value),
    category: categoryInput.value,
    description: descriptionInput.value
  };
  const id = productIdInput.value;
  if (id) {
    await api(`/api/products/${id}`, {
      method: "PUT",
      body: JSON.stringify(payload)
    });
  } else {
    await api("/api/products", {
      method: "POST",
      body: JSON.stringify(payload)
    });
  }
  hideForm();
  await loadProducts();
});

document.getElementById("btn-new").addEventListener("click", () => showForm());
document.getElementById("btn-cancel").addEventListener("click", hideForm);

loadProducts().catch((err) => {
  emptyState.textContent = err.message;
  emptyState.classList.remove("hidden");
});
