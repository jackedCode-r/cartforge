import React from "react";
import { NavLink, useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext.jsx";
import { useCart } from "../context/CartContext.jsx";
import { LogoMark, NavIcon } from "./Icons.jsx";

export default function Navbar() {
  const { user, logout } = useAuth();
  const { cartCount } = useCart();
  const navigate = useNavigate();

  const linkClass = ({ isActive }) => `nav-link${isActive ? " active" : ""}`;

  const handleLogout = () => {
    logout();
    navigate("/");
  };

  return (
    <header className="navbar">
      <div className="container">
        <NavLink to="/" className="brand">
          <LogoMark />
          Cart<span className="mark">Forge</span>
        </NavLink>

        <nav className="nav-links">
          <NavLink to="/" className={linkClass} end>
            <NavIcon.home /> Home
          </NavLink>

          {user ? (
            <>
              <NavLink to="/mycart" className={linkClass}>
                <NavIcon.cart /> My Cart
                {cartCount > 0 && <span className="cart-badge">{cartCount}</span>}
              </NavLink>
              <NavLink to="/myorders" className={linkClass}>
                <NavIcon.orders /> My Orders
              </NavLink>
              <NavLink to="/add-product" className={linkClass}>
                <NavIcon.plus /> Add Product
              </NavLink>
              <button className="nav-link" onClick={handleLogout} type="button">
                <NavIcon.logout /> Logout
              </button>
            </>
          ) : (
            <>
              <NavLink to="/login" className={linkClass}>
                <NavIcon.login /> Login
              </NavLink>
              <NavLink to="/register" className="nav-link cta">
                <NavIcon.register /> Register
              </NavLink>
            </>
          )}
        </nav>
      </div>
    </header>
  );
}
