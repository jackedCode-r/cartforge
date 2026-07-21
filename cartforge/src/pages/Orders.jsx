import React from "react";
import { useNavigate } from "react-router-dom";
import { useCart } from "../context/CartContext.jsx";
import { NavIcon } from "../components/Icons.jsx";

export default function Orders() {
  const { orders } = useCart();
  const navigate = useNavigate();

  return (
    <div className="container">
      <div className="page-head">
        <h2>
          <NavIcon.orders /> My Orders <span className="count">({orders.length})</span>
        </h2>
      </div>

      {orders.length === 0 ? (
        <div className="empty-state">
          <div className="icon-wrap">
            <NavIcon.box style={{ margin: "0 auto", color: "var(--slate-soft)" }} />
          </div>
          <h3>No orders yet</h3>
          <p>Orders you confirm from your cart will show up here.</p>
          <button className="btn btn-primary" style={{ marginTop: 16 }} onClick={() => navigate("/")}>
            Start shopping
          </button>
        </div>
      ) : (
        <div style={{ paddingBottom: 48 }}>
          {orders.map((order) => (
            <div className="order-card" key={order.id}>
              <div className="order-top">
                <div>
                  <div className="order-id">{order.id}</div>
                  <div style={{ fontSize: "0.78rem", color: "var(--slate-soft)" }}>
                    {new Date(order.placedAt).toLocaleString()}
                  </div>
                </div>
                <span className="order-status">{order.status}</span>
              </div>
              <div className="order-items">
                {order.items.map((item) => (
                  <span className="order-item-chip" key={item.id}>
                    {item.name} × {item.qty}
                  </span>
                ))}
              </div>
              <div className="order-total">
                <span>Total</span>
                <span>₹{order.total}</span>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
