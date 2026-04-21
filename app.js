/**
 * Train Seat Exchange — app.js
 *
 * Data model
 * ----------
 * Each coach contains ROWS × SEATS_PER_ROW seats.
 * Seat states: 'available' | 'booked'
 * UI states layered on top: 'selected' | 'exchange-target'
 *
 * Exchange flow
 * -------------
 * 1. User clicks a 'booked' seat  → becomes 'selected' (the seat you hold)
 * 2. User clicks another 'booked' seat → becomes 'exchange-target'
 * 3. User confirms → the two seats swap passenger names
 * 4. Clicking an 'available' seat books it with a generated name
 * Cancel at any time resets UI state without touching data.
 */

'use strict';

/* ─── Configuration ──────────────────────────────────────────────── */
const COACHES = ['A', 'B', 'C'];
const ROWS = 10;
const SEATS_PER_ROW = 4;                 // 2 window + 2 aisle
const SEAT_LABELS = ['W', 'A', 'A', 'W']; // window / aisle pattern
const BOOKED_RATIO = 0.55;               // fraction of seats pre-booked

/* ─── Sample passenger names ─────────────────────────────────────── */
const NAMES = [
  'Alice', 'Bob', 'Carol', 'David', 'Eve', 'Frank', 'Grace', 'Henry',
  'Iris', 'James', 'Karen', 'Leo', 'Mia', 'Noah', 'Olivia', 'Paul',
  'Quinn', 'Rachel', 'Sam', 'Tina', 'Uma', 'Victor', 'Wendy', 'Xander',
  'Yara', 'Zoe',
];
let nameIdx = 0;
function nextName() { return NAMES[nameIdx++ % NAMES.length]; }

/* ─── State ──────────────────────────────────────────────────────── */
/**
 * @typedef {{ id: string, coach: string, row: number, col: number,
 *             label: string, state: 'available'|'booked', passenger: string|null }} Seat
 */
/** @type {Record<string, Seat[]>} coach → seats */
const coachData = {};
let activeCoach = COACHES[0];
/** @type {string|null} id of seat selected for exchange (step 1) */
let selectedSeatId = null;
/** @type {string|null} id of target seat (step 2) */
let targetSeatId = null;

/* ─── Initialisation ─────────────────────────────────────────────── */
function init() {
  COACHES.forEach(coach => {
    const seats = [];
    for (let row = 0; row < ROWS; row++) {
      for (let col = 0; col < SEATS_PER_ROW; col++) {
        const id = `${coach}-${row}-${col}`;
        const booked = Math.random() < BOOKED_RATIO;
        seats.push({
          id,
          coach,
          row,
          col,
          label: SEAT_LABELS[col],
          state: booked ? 'booked' : 'available',
          passenger: booked ? nextName() : null,
        });
      }
    }
    coachData[coach] = seats;
  });

  buildCoachTabs();
  renderCoach(activeCoach);
}

/* ─── Coach tabs ─────────────────────────────────────────────────── */
function buildCoachTabs() {
  const container = document.getElementById('coachTabs');
  container.innerHTML = '';
  COACHES.forEach(coach => {
    const btn = document.createElement('button');
    btn.className = 'coach-tab' + (coach === activeCoach ? ' active' : '');
    btn.textContent = `Coach ${coach}`;
    btn.setAttribute('aria-label', `Switch to coach ${coach}`);
    btn.addEventListener('click', () => switchCoach(coach));
    container.appendChild(btn);
  });
}

function switchCoach(coach) {
  clearSelection();
  activeCoach = coach;
  document.querySelectorAll('.coach-tab').forEach(btn => {
    btn.classList.toggle('active', btn.textContent === `Coach ${coach}`);
  });
  renderCoach(coach);
}

/* ─── Render coach ───────────────────────────────────────────────── */
function renderCoach(coach) {
  const seats = coachData[coach];
  document.getElementById('coachLabel').textContent = `Coach ${coach}`;

  const total  = seats.length;
  const booked = seats.filter(s => s.state === 'booked').length;
  const avail  = total - booked;
  document.getElementById('coachStats').textContent =
    `${booked} booked · ${avail} available`;

  const grid = document.getElementById('seatGrid');
  grid.innerHTML = '';
  grid.style.gridTemplateColumns = `repeat(${SEATS_PER_ROW}, 1fr)`;

  seats.forEach(seat => {
    const el = createSeatElement(seat);
    grid.appendChild(el);
  });

  updateActionPanel();
}

function createSeatElement(seat) {
  const btn = document.createElement('button');
  btn.id = `seat-${seat.id}`;
  btn.className = `seat ${visualState(seat)}`;
  btn.setAttribute('aria-label', seatAriaLabel(seat));
  btn.setAttribute('title', seatTooltip(seat));

  // Row number badge (first seat of each row)
  if (seat.col === 0) {
    const rowBadge = document.createElement('span');
    rowBadge.className = 'seat-label';
    rowBadge.textContent = seat.row + 1;
    btn.appendChild(rowBadge);
  }

  const nameEl = document.createElement('span');
  nameEl.className = 'seat-name';
  nameEl.textContent = seat.state === 'booked' ? (seat.passenger || '').split(' ')[0] : seat.label;
  btn.appendChild(nameEl);

  btn.addEventListener('click', () => handleSeatClick(seat.id));
  return btn;
}

function visualState(seat) {
  if (seat.id === selectedSeatId)  return 'selected';
  if (seat.id === targetSeatId)    return 'exchange-target';
  return seat.state;
}

function seatAriaLabel(seat) {
  const base = `Row ${seat.row + 1}, seat ${seat.col + 1} (${seat.label === 'W' ? 'window' : 'aisle'})`;
  if (seat.state === 'available') return `${base} – available`;
  return `${base} – booked by ${seat.passenger}`;
}

function seatTooltip(seat) {
  if (seat.state === 'available') return `Row ${seat.row + 1} · ${seat.label === 'W' ? 'Window' : 'Aisle'} · Available`;
  return `Row ${seat.row + 1} · ${seat.label === 'W' ? 'Window' : 'Aisle'} · ${seat.passenger}`;
}

/* ─── Seat click handler ─────────────────────────────────────────── */
function handleSeatClick(seatId) {
  const seat = findSeat(seatId);
  if (!seat) return;

  // Clicking selected seat deselects it
  if (seatId === selectedSeatId) {
    clearSelection();
    renderCoach(activeCoach);
    return;
  }

  // Clicking target seat deselects it
  if (seatId === targetSeatId) {
    targetSeatId = null;
    updateSeatElement(seat);
    updateActionPanel();
    return;
  }

  if (seat.state === 'available') {
    // Book this seat
    if (selectedSeatId || targetSeatId) {
      clearSelection();
    }
    bookSeat(seat);
    return;
  }

  // seat is booked
  if (!selectedSeatId) {
    // Step 1: select your seat
    selectedSeatId = seatId;
    updateSeatElement(seat);
    updateActionPanel();
  } else {
    // Step 2: pick the target
    targetSeatId = seatId;
    updateSeatElement(seat);
    updateActionPanel();
  }
}

/* ─── Book a seat ────────────────────────────────────────────────── */
function bookSeat(seat) {
  const name = nextName();
  seat.state = 'booked';
  seat.passenger = name;

  updateSeatElement(seat);
  updateCoachStats();
  appendLog(`🎫 ${name} booked seat ${seatCode(seat)} in Coach ${seat.coach}`, 'book');
  updateActionPanel();
}

/* ─── Exchange ───────────────────────────────────────────────────── */
function confirmExchange() {
  if (!selectedSeatId || !targetSeatId) return;

  const seatA = findSeat(selectedSeatId);
  const seatB = findSeat(targetSeatId);
  if (!seatA || !seatB) return;

  // Capture names before the swap for the log message
  const nameA = seatA.passenger;
  const nameB = seatB.passenger;

  // Swap passengers
  seatA.passenger = nameB;
  seatB.passenger = nameA;

  const logMsg = `🔄 ${nameA} (${seatCode(seatA)}) ↔ ${nameB} (${seatCode(seatB)}) exchanged in Coach ${activeCoach}`;

  clearSelection();
  renderCoach(activeCoach);
  appendLog(logMsg, 'exchange');
}

function cancelAction() {
  clearSelection();
  renderCoach(activeCoach);
}

/* ─── Helpers ────────────────────────────────────────────────────── */
function findSeat(id) {
  for (const coach of COACHES) {
    const s = coachData[coach].find(s => s.id === id);
    if (s) return s;
  }
  return null;
}

function seatCode(seat) {
  return `${seat.row + 1}${String.fromCharCode(65 + seat.col)}`;
}

function clearSelection() {
  selectedSeatId = null;
  targetSeatId   = null;
}

/* ─── DOM helpers ────────────────────────────────────────────────── */
function updateSeatElement(seat) {
  const el = document.getElementById(`seat-${seat.id}`);
  if (!el) return;
  el.className = `seat ${visualState(seat)}`;
  el.setAttribute('aria-label', seatAriaLabel(seat));
  el.setAttribute('title', seatTooltip(seat));
  // update inner text
  const nameEl = el.querySelector('.seat-name');
  if (nameEl) {
    nameEl.textContent = seat.state === 'booked'
      ? (seat.passenger || '').split(' ')[0]
      : seat.label;
  }
}

function updateCoachStats() {
  const seats  = coachData[activeCoach];
  const total  = seats.length;
  const booked = seats.filter(s => s.state === 'booked').length;
  document.getElementById('coachStats').textContent =
    `${booked} booked · ${total - booked} available`;
}

function updateActionPanel() {
  const msg   = document.getElementById('actionMsg');
  const btns  = document.getElementById('actionButtons');
  btns.innerHTML = '';

  if (!selectedSeatId && !targetSeatId) {
    msg.textContent = 'Select a booked seat to start an exchange, or an available seat to book it.';
    return;
  }

  const seatA = findSeat(selectedSeatId);

  if (selectedSeatId && !targetSeatId) {
    msg.textContent = `Step 2: now click another booked seat to exchange with ${seatA.passenger} (${seatCode(seatA)}).`;
    btns.appendChild(makeBtn('Cancel', 'btn-cancel', cancelAction));
    return;
  }

  const seatB = findSeat(targetSeatId);
  msg.textContent = `Swap ${seatA.passenger} (${seatCode(seatA)}) with ${seatB.passenger} (${seatCode(seatB)})?`;
  btns.appendChild(makeBtn('Confirm Exchange ✓', 'btn-confirm', confirmExchange));
  btns.appendChild(makeBtn('Cancel', 'btn-cancel', cancelAction));
}

function makeBtn(label, cls, handler) {
  const btn = document.createElement('button');
  btn.className = `btn ${cls}`;
  btn.textContent = label;
  btn.addEventListener('click', handler);
  return btn;
}

function appendLog(text, type) {
  const ul = document.getElementById('exchangeLog');
  const empty = ul.querySelector('.log-empty');
  if (empty) empty.remove();
  const li = document.createElement('li');
  li.className = `log-${type}`;
  li.textContent = `[${timestamp()}] ${text}`;
  ul.prepend(li);
}

function timestamp() {
  return new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });
}

/* ─── Boot ───────────────────────────────────────────────────────── */
document.addEventListener('DOMContentLoaded', init);
