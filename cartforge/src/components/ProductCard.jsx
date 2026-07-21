import React from "react";
import {
  ArtBottle,
  ArtFruit,
  ArtCosmeticWand,
  ArtLipstick,
  ArtBread,
  ArtEarbuds,
  ArtGrain,
  ArtJar,
  NavIcon,
} from "./Icons.jsx";

const ART_MAP = {
  bottle: ArtBottle,
  fruit: ArtFruit,
  wand: ArtCosmeticWand,
  lipstick: ArtLipstick,
  bread: ArtBread,
  earbuds: ArtEarbuds,
  grain: ArtGrain,
  jar: ArtJar,
};

export default function ProductCard({ product, onAdd }) {
  const Art = ART_MAP[product.art] || ArtJar;

  return (
    <article className="product-card">
      <div className="product-media">
        <span className="forge-tag">
          <span className="rivet" />
          {product.category}
        </span>
        {product.isNew && (
          <span className="new-flag">
            <NavIcon.tag /> New
          </span>
        )}
        <Art />
      </div>
      <div className="product-body">
        <div className="product-name">{product.name}</div>
        <p className="product-desc">{product.desc}</p>
        <div className="product-footer">
          <span className="price">
            <NavIcon.flame className="flame" />₹{product.price}
          </span>
          <button
            className="icon-btn"
            type="button"
            aria-label={`Add ${product.name} to cart`}
            onClick={() => onAdd(product)}
          >
            <NavIcon.cart />
          </button>
        </div>
      </div>
    </article>
  );
}
