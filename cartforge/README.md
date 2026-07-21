# CartForge

A modern, industry-style e-commerce storefront UI — **frontend only**, no backend or database. Built with React + Vite.

## Features

- **Home** — hero banner, category/search/price filters, sortable product grid, 8 seeded products across 6 categories
- **Login / Register** — client-side form validation, demo auth (any valid email/password combo works), session persisted in `localStorage`
- **My Cart** — quantity editing, line removal, order summary, "Confirm Order" checkout flow
- **My Orders** — order history with items, totals, and status
- **Add Product** — form to add new items straight into the in-browser catalog

All data (cart, orders, catalog additions, session) is kept in the browser via React Context + `localStorage`. There is no server, API, or database — refreshing keeps your data, but it never leaves your machine.

## Getting started

```bash
npm install
npm start
```

The app opens automatically at **http://localhost:3000**.

## Tech stack

- React 18
- React Router 6
- Vite 5 (dev server + bundler)
- Plain CSS with a small design-token system (see `src/index.css`)

## Project structure

```
cartforge/
├── index.html
├── package.json
├── vite.config.js
└── src/
    ├── main.jsx
    ├── App.jsx
    ├── index.css
    ├── context/        # Auth + Cart state (React Context)
    ├── data/            # Seed product catalog
    ├── components/      # Navbar, ProductCard, Footer, icon set
    └── pages/            # Home, Login, Register, Cart, Orders, AddProduct
```

## Notes

- This is a demo/UI shell: authentication is not secure and is intended only to gate navigation for demonstration purposes.
- To connect a real backend later, replace the logic inside `src/context/AuthContext.jsx` and `src/context/CartContext.jsx` with API calls.
