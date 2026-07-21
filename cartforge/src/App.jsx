import React from "react";
import { Routes, Route } from "react-router-dom";
import Navbar from "./components/Navbar.jsx";
import Footer from "./components/Footer.jsx";
import Home from "./pages/Home.jsx";
import Login from "./pages/Login.jsx";
import Register from "./pages/Register.jsx";
import Cart from "./pages/Cart.jsx";
import Orders from "./pages/Orders.jsx";
import AddProduct from "./pages/AddProduct.jsx";

export default function App() {
  return (
    <>
      <Navbar />
      <main style={{ flex: 1, width: "100%" }}>
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/login" element={<Login />} />
          <Route path="/register" element={<Register />} />
          <Route path="/mycart" element={<Cart />} />
          <Route path="/myorders" element={<Orders />} />
          <Route path="/add-product" element={<AddProduct />} />
        </Routes>
      </main>
      <Footer />
    </>
  );
}
