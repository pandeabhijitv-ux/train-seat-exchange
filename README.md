# Train Seat Exchange 🚆

A lightweight, browser-based application that lets train passengers view seat availability across multiple coaches and swap seats with each other in real time.

## Features

| Feature | Details |
|---|---|
| Multi-coach view | Three coaches (A, B, C) with 10 rows × 4 seats each |
| Seat states | Available (green), Booked (blue), Selected (amber), Exchange target (red) |
| Book a seat | Click any available seat to instantly reserve it |
| Exchange seats | Select two booked seats and confirm the swap |
| Exchange log | Timestamped history of all bookings and exchanges |

## Getting started

No build step or server required — the app is pure HTML/CSS/JavaScript.

```bash
# Open directly in your browser
open index.html
# or with a simple local server
npx serve .
```

## Project structure

```
.
├── index.html   # App shell and markup
├── styles.css   # All styles (CSS custom properties, responsive)
└── app.js       # Data model, seat logic, DOM rendering
```

## How seat exchange works

1. **Select your seat** – click a booked (blue) seat.  The seat turns amber to show it is selected.
2. **Pick a target** – click another booked seat in the same coach.  It turns red.
3. **Confirm** – click the _Confirm Exchange_ button.  The two passengers' names are swapped and the exchange is recorded in the log.

Click **Cancel** at any step to abort without changing any data.

