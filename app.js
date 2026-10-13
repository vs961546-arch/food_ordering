/* Food Ordering and Delivery System - frontend logic.
 * Talks to the Flask backend on the same origin (no CORS needed).
 * The frontend never touches the database and never sees any
 * password - it only calls the HTTP API. */

let menuItems = [];                 // last menu loaded from the API
const cart = new Map();             // item_id -> { item_id, name, price, quantity }

// ---------------------------------------------------------------- menu
async function loadMenu() {
  const response = await fetch("/api/food");
  menuItems = await response.json();
  renderMenu();
}

function renderMenu() {
  const menu = document.getElementById("menu");
  menu.innerHTML = "";
  for (const item of menuItems) {
    const card = document.createElement("div");
    card.className = "dish" + (item.is_available ? "" : " unavailable");

    const img = document.createElement("img");
    img.src = item.image;
    img.alt = item.name;
    img.loading = "lazy";

    const name = document.createElement("h3");
    name.textContent = item.name;

    const price = document.createElement("span");
    price.className = "price";
    price.textContent = "₹" + item.price.toFixed(2);   // rupee sign

    const button = document.createElement("button");
    if (item.is_available) {
      button.textContent = "Add to cart";
      button.dataset.add = item.item_id;
    } else {
      button.textContent = "Sold out";
      button.disabled = true;
    }

    card.append(img, name, price, button);
    menu.appendChild(card);
  }
}

// One delegated listener for every "Add to cart" button
document.getElementById("menu").addEventListener("click", (event) => {
  const button = event.target.closest("button[data-add]");
  if (!button) return;
  const item = menuItems.find((i) => i.item_id === Number(button.dataset.add));
  if (item) addToCart(item);
});

// ---------------------------------------------------------------- cart
function addToCart(item) {
  const inCart = cart.get(item.item_id);
  if (inCart) {
    inCart.quantity += 1;
  } else {
    cart.set(item.item_id, { ...item, quantity: 1 });
  }
  renderCart();
}

function setQuantity(itemId, quantity) {
  if (quantity <= 0) {
    cart.delete(itemId);
  } else {
    cart.get(itemId).quantity = quantity;
  }
  renderCart();
}

function renderCart() {
  const list = document.getElementById("cart");
  list.innerHTML = "";
  let total = 0;
  for (const item of cart.values()) {
    total += item.price * item.quantity;

    const li = document.createElement("li");

    const info = document.createElement("span");
    info.textContent =
      item.name + " × " + item.quantity + " - ₹" +
      (item.price * item.quantity).toFixed(2);

    const controls = document.createElement("span");
    controls.className = "qty";
    const minus = document.createElement("button");
    minus.textContent = "−";
    minus.addEventListener("click", () => setQuantity(item.item_id, item.quantity - 1));
    const plus = document.createElement("button");
    plus.textContent = "+";
    plus.addEventListener("click", () => setQuantity(item.item_id, item.quantity + 1));
    controls.append(minus, plus);

    li.append(info, controls);
    list.appendChild(li);
  }
  document.getElementById("cart-total").textContent =
    "Total: ₹" + total.toFixed(2);
}

// ------------------------------------------------------------ checkout
document.getElementById("checkout-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  if (cart.size === 0) {
    showMessage("Your cart is empty.", true);
    return;
  }

  const order = {
    customer: {
      name: document.getElementById("cust-name").value.trim(),
      phone: document.getElementById("cust-phone").value.trim(),
      email: document.getElementById("cust-email").value.trim(),
      address: document.getElementById("cust-address").value.trim(),
    },
    items: [...cart.values()].map((item) => ({
      item_id: item.item_id,
      quantity: item.quantity,
    })),
  };

  const button = document.getElementById("place-order");
  button.disabled = true;
  try {
    const response = await fetch("/api/orders", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(order),
    });
    const data = await response.json();
    if (!response.ok) {
      showMessage("Could not place order: " + (data.error || response.status), true);
    } else {
      showMessage("Order #" + data.order_id + " placed! Total: ₹" +
                  data.total_amount.toFixed(2));
      cart.clear();
      renderCart();
      event.target.reset();
    }
  } catch (err) {
    showMessage("Cannot reach the server: " + err, true);
  } finally {
    button.disabled = false;
  }
});

// -------------------------------------------------------- order lookup
async function lookupOrder() {
  const id = document.getElementById("lookup-id").value;
  const result = document.getElementById("lookup-result");
  if (!id) return;
  const response = await fetch("/api/orders/" + id);
  const data = await response.json();
  if (!response.ok) {
    result.textContent = "Error: " + (data.error || response.status);
  } else {
    result.textContent =
      "Order #" + data.order_id + " - " + data.status + "\n" +
      "Customer: " + data.customer_name + "\n" +
      "Date: " + data.order_date + "\n" +
      data.items.map((i) =>
        i.food_name + " × " + i.quantity + " - ₹" + i.subtotal.toFixed(2)
      ).join("\n") +
      "\nTotal: ₹" + data.total_amount.toFixed(2);
  }
}
document.getElementById("lookup-btn").addEventListener("click", lookupOrder);

// ------------------------------------------------------------- helpers
function showMessage(text, isError) {
  const box = document.getElementById("message");
  box.textContent = text;
  box.className = "message" + (isError ? " error" : "");
  box.hidden = false;
  setTimeout(() => { box.hidden = true; }, 4000);
}

// ---------------------------------------------------------------- start
loadMenu();
