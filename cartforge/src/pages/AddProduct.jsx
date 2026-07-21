import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useCart } from "../context/CartContext.jsx";
import { CATEGORIES } from "../data/products.js";
import { NavIcon } from "../components/Icons.jsx";

const ART_BY_CATEGORY = {
  Groceries: "jar",
  Fruits: "fruit",
  Cosmetics: "lipstick",
  Beverages: "bottle",
  Bakery: "bread",
  Electronics: "earbuds",
};

export default function AddProduct() {
  const { addProduct } = useCart();
  const navigate = useNavigate();
  const [form, setForm] = useState({
    name: "",
    category: "Groceries",
    price: "",
    desc: "",
  });
  const [errors, setErrors] = useState({});
  const [saved, setSaved] = useState(false);

  const validate = () => {
    const e = {};
    if (form.name.trim().length < 2) e.name = "Enter a product name.";
    if (!form.price || Number(form.price) <= 0) e.price = "Enter a valid price.";
    if (form.desc.trim().length < 4) e.desc = "Add a short description.";
    return e;
  };

  const handleSubmit = (ev) => {
    ev.preventDefault();
    const e = validate();
    setErrors(e);
    if (Object.keys(e).length === 0) {
      addProduct({
        name: form.name.trim(),
        category: form.category,
        price: Number(form.price),
        desc: form.desc.trim(),
        art: ART_BY_CATEGORY[form.category] || "jar",
        isNew: true,
      });
      setSaved(true);
      setTimeout(() => navigate("/"), 800);
    }
  };

  return (
    <div className="container">
      <div className="form-card">
        <h2 style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 4 }}>
          <NavIcon.plus /> Add Product
        </h2>
        <p style={{ color: "var(--slate-soft)", fontSize: "0.88rem", margin: "0 0 20px" }}>
          List a new item in the CartForge catalog. This is a frontend-only demo — nothing is sent to a server.
        </p>

        {saved && <div className="banner banner-success">Product added! Redirecting to the catalog…</div>}

        <form onSubmit={handleSubmit} noValidate>
          <div className="form-grid">
            <div className="form-group full">
              <label htmlFor="pname">Product name</label>
              <input
                id="pname"
                type="text"
                placeholder="e.g. Dark Roast Coffee Beans"
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
              />
              {errors.name && <div className="form-error">{errors.name}</div>}
            </div>

            <div className="form-group">
              <label htmlFor="pcat">Category</label>
              <select
                id="pcat"
                value={form.category}
                onChange={(e) => setForm({ ...form, category: e.target.value })}
              >
                {CATEGORIES.filter((c) => c !== "All Categories").map((c) => (
                  <option key={c} value={c}>
                    {c}
                  </option>
                ))}
              </select>
            </div>

            <div className="form-group">
              <label htmlFor="pprice">Price (₹)</label>
              <input
                id="pprice"
                type="number"
                min="0"
                placeholder="299"
                value={form.price}
                onChange={(e) => setForm({ ...form, price: e.target.value })}
              />
              {errors.price && <div className="form-error">{errors.price}</div>}
            </div>

            <div className="form-group full">
              <label htmlFor="pdesc">Description</label>
              <textarea
                id="pdesc"
                placeholder="A short, honest description of the product."
                value={form.desc}
                onChange={(e) => setForm({ ...form, desc: e.target.value })}
              />
              {errors.desc && <div className="form-error">{errors.desc}</div>}
            </div>
          </div>

          <button className="btn btn-primary btn-block" type="submit" style={{ marginTop: 6 }}>
            Add to catalog
          </button>
        </form>
      </div>
    </div>
  );
}
