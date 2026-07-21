import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useCart } from "../context/CartContext.jsx";
import { NavIcon } from "../components/Icons.jsx";

export default function Cart() {
  const { cart, cartCount, cartTotal, updateQty, removeFromCart, placeOrder } = useCart();
  const navigate = useNavigate();
  const [justPlaced, setJustPlaced] = useState(false);

  const handleConfirm = () => {
    const order = placeOrder();
    if (order) {
      setJustPlaced(true);
      setTimeout(() => navigate("/myorders"), 900);
    }
  };

  return (
    <div className="container">
      <div className="page-head">
        <h2>
          <NavIcon.cart /> My Cart <span className="count">({cartCount} items)</span>
        </h2>
      </div>

      {justPlaced && <div className="banner banner-success">Order confirmed! Redirecting to your orders…</div>}

      {cart.length === 0 ? (
        <div className="empty-state">
          <div className="icon-wrap">
            <NavIcon.box style={{ margin: "0 auto", color: "var(--slate-soft)" }} />
          </div>
          <h3>Your cart is empty</h3>
          <p>Browse the catalog and add something you like.</p>
          <button className="btn btn-primary" style={{ marginTop: 16 }} onClick={() => navigate("/")}>
            Continue shopping
          </button>
        </div>
      ) : (
        <div className="cart-layout">
          <div>
            {cart.map((line) => (
              <div className="cart-line" key={line.id}>
                <div className="cart-line-media">
                  <NavIcon.box style={{ color: "var(--slate-soft)", width: 34, height: 34 }} />
                </div>
                <div className="cart-line-info">
                  <span className="cat-chip">{line.category}</span>
                  <h4>{line.name}</h4>
                  <p>{line.desc}</p>
                  <div className="cart-line-price">₹{line.price}</div>
                </div>
                <div className="cart-line-actions">
                  <input
                    className="qty-input"
                    type="number"
                    min="1"
                    value={line.qty}
                    onChange={(e) => updateQty(line.id, Number(e.target.value))}
                    aria-label={`Quantity for ${line.name}`}
                  />
                  <button className="btn btn-danger btn-sm" onClick={() => removeFromCart(line.id)} type="button">
                    Remove
                  </button>
                </div>
              </div>
            ))}
          </div>

          <div className="summary-card">
            <h3>
              <NavIcon.orders /> Order Summary
            </h3>
            <div className="summary-row">
              <span>Items ({cartCount})</span>
              <span>₹{cartTotal}</span>
            </div>
            <div className="summary-row">
              <span>Delivery</span>
              <span className="free">FREE</span>
            </div>
            <div className="summary-total">
              <span>Total</span>
              <span>₹{cartTotal}</span>
            </div>
            <button className="btn btn-primary btn-block" onClick={handleConfirm} type="button">
              Confirm Order →
            </button>
            <div className="summary-note">🔒 Secure & encrypted checkout</div>
          </div>
        </div>
      )}
    </div>
  );
}
