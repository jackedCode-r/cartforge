import React, { createContext, useContext, useEffect, useState } from "react";
import { INITIAL_PRODUCTS } from "../data/products.js";

const CartContext = createContext(null);

const CART_KEY = "cartforge_cart";
const ORDERS_KEY = "cartforge_orders";
const PRODUCTS_KEY = "cartforge_products";

function loadJSON(key, fallback) {
  try {
    const raw = localStorage.getItem(key);
    return raw ? JSON.parse(raw) : fallback;
  } catch {
    return fallback;
  }
}

export function CartProvider({ children }) {
  const [products, setProducts] = useState(() => loadJSON(PRODUCTS_KEY, INITIAL_PRODUCTS));
  const [cart, setCart] = useState(() => loadJSON(CART_KEY, []));
  const [orders, setOrders] = useState(() => loadJSON(ORDERS_KEY, []));

  useEffect(() => localStorage.setItem(PRODUCTS_KEY, JSON.stringify(products)), [products]);
  useEffect(() => localStorage.setItem(CART_KEY, JSON.stringify(cart)), [cart]);
  useEffect(() => localStorage.setItem(ORDERS_KEY, JSON.stringify(orders)), [orders]);

  const addToCart = (product, qty = 1) => {
    setCart((prev) => {
      const existing = prev.find((line) => line.id === product.id);
      if (existing) {
        return prev.map((line) =>
          line.id === product.id ? { ...line, qty: line.qty + qty } : line
        );
      }
      return [...prev, { ...product, qty }];
    });
  };

  const updateQty = (id, qty) => {
    setCart((prev) =>
      prev.map((line) => (line.id === id ? { ...line, qty: Math.max(1, qty) } : line))
    );
  };

  const removeFromCart = (id) => setCart((prev) => prev.filter((line) => line.id !== id));

  const clearCart = () => setCart([]);

  const addProduct = (product) => {
    setProducts((prev) => [{ ...product, id: `p_${Date.now()}` }, ...prev]);
  };

  const placeOrder = () => {
    if (cart.length === 0) return null;
    const total = cart.reduce((sum, l) => sum + l.price * l.qty, 0);
    const order = {
      id: `CF-${Math.floor(100000 + Math.random() * 899999)}`,
      items: cart,
      total,
      placedAt: new Date().toISOString(),
      status: "Confirmed",
    };
    setOrders((prev) => [order, ...prev]);
    clearCart();
    return order;
  };

  const cartCount = cart.reduce((sum, l) => sum + l.qty, 0);
  const cartTotal = cart.reduce((sum, l) => sum + l.price * l.qty, 0);

  return (
    <CartContext.Provider
      value={{
        products,
        cart,
        orders,
        cartCount,
        cartTotal,
        addToCart,
        updateQty,
        removeFromCart,
        clearCart,
        addProduct,
        placeOrder,
      }}
    >
      {children}
    </CartContext.Provider>
  );
}

export function useCart() {
  const ctx = useContext(CartContext);
  if (!ctx) throw new Error("useCart must be used within CartProvider");
  return ctx;
}
