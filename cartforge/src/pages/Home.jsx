import React, { useMemo, useState } from "react";
import { useCart } from "../context/CartContext.jsx";
import { CATEGORIES } from "../data/products.js";
import ProductCard from "../components/ProductCard.jsx";
import { NavIcon } from "../components/Icons.jsx";

export default function Home() {
  const { products, addToCart } = useCart();
  const [category, setCategory] = useState("All Categories");
  const [search, setSearch] = useState("");
  const [maxPrice, setMaxPrice] = useState("");
  const [sortDesc, setSortDesc] = useState(true);

  const filtered = useMemo(() => {
    let list = [...products];
    if (category !== "All Categories") {
      list = list.filter((p) => p.category === category);
    }
    if (search.trim()) {
      list = list.filter((p) => p.name.toLowerCase().includes(search.trim().toLowerCase()));
    }
    if (maxPrice !== "" && !Number.isNaN(Number(maxPrice))) {
      list = list.filter((p) => p.price <= Number(maxPrice));
    }
    list.sort((a, b) => (sortDesc ? b.price - a.price : a.price - b.price));
    return list;
  }, [products, category, search, maxPrice, sortDesc]);

  return (
    <div className="container">
      <div className="hero">
        <div>
          <div className="hero-eyebrow">
            <NavIcon.flame /> Forged Deals, Daily
          </div>
          <h1>Discover Products</h1>
          <p>Find the best deals, tailored for you.</p>
        </div>
        <div className="hero-count">{filtered.length} products found</div>
      </div>

      <div className="filter-bar">
        <div className="field">
          <NavIcon.tag />
          <select value={category} onChange={(e) => setCategory(e.target.value)}>
            {CATEGORIES.map((c) => (
              <option key={c} value={c}>
                {c}
              </option>
            ))}
          </select>
        </div>
        <div className="field">
          <NavIcon.search />
          <input
            type="text"
            placeholder="Search by name..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
        <div className="field">
          <NavIcon.rupee />
          <input
            type="number"
            min="0"
            placeholder="Max price..."
            value={maxPrice}
            onChange={(e) => setMaxPrice(e.target.value)}
          />
        </div>
        <button className="btn btn-primary" type="button" onClick={() => setSortDesc((s) => !s)}>
          <NavIcon.sort /> {sortDesc ? "High to Low" : "Low to High"}
        </button>
        <button className="btn btn-ghost" type="button" onClick={() => { setCategory("All Categories"); setSearch(""); setMaxPrice(""); }}>
          Reset
        </button>
      </div>

      {filtered.length === 0 ? (
        <div className="empty-state">
          <div className="icon-wrap">
            <NavIcon.box style={{ margin: "0 auto", color: "var(--slate-soft)" }} />
          </div>
          <h3>No products match your filters</h3>
          <p>Try adjusting the category, search term, or price limit.</p>
        </div>
      ) : (
        <div className="product-grid">
          {filtered.map((p) => (
            <ProductCard key={p.id} product={p} onAdd={addToCart} />
          ))}
        </div>
      )}
    </div>
  );
}
