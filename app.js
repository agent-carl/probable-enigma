"use strict";

/* ============ Данные ============ */

const STORAGE_KEY = "subtrack.subscriptions.v1";

const PERIODS = {
  week:    { label: "нед.",  perMonth: 52 / 12 },
  month:   { label: "мес.",  perMonth: 1 },
  quarter: { label: "квартал", perMonth: 1 / 3 },
  year:    { label: "год",   perMonth: 1 / 12 },
};

// Популярные сервисы для автоподсказки при вводе названия
const PRESETS = [
  "Яндекс Плюс", "Кинопоиск", "ВК Музыка", "Okko", "ИВИ", "Wink",
  "Netflix", "Spotify", "YouTube Premium", "Apple Music", "Apple One",
  "iCloud+", "Google One", "Telegram Premium", "ChatGPT Plus",
  "PlayStation Plus", "Xbox Game Pass", "Литрес", "Storytel",
  "Duolingo", "Notion", "Figma", "Adobe Creative Cloud", "Dropbox",
];

const AVATAR_COLORS = [
  "#6c5ce7", "#e74c5c", "#2ecc8f", "#f0b04a", "#3498db",
  "#9b59b6", "#1abc9c", "#e67e22", "#fd6c9e", "#34708f",
];

let subs = load();

function load() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    const data = raw ? JSON.parse(raw) : [];
    return Array.isArray(data) ? data.filter(isValidSub) : [];
  } catch {
    return [];
  }
}

function save() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(subs));
}

function isValidSub(s) {
  return s && typeof s.name === "string" && typeof s.price === "number" &&
    PERIODS[s.period] && typeof s.nextDate === "string";
}

/* ============ Даты ============ */

function today() {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d;
}

function parseDate(iso) {
  const [y, m, d] = iso.split("-").map(Number);
  return new Date(y, m - 1, d);
}

function toISO(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function advancePeriod(date, period) {
  const d = new Date(date);
  if (period === "week") d.setDate(d.getDate() + 7);
  else if (period === "month") d.setMonth(d.getMonth() + 1);
  else if (period === "quarter") d.setMonth(d.getMonth() + 3);
  else d.setFullYear(d.getFullYear() + 1);
  return d;
}

// Если дата списания уже прошла — сдвигаем на следующий период,
// чтобы счётчик «через N дней» всегда был актуален.
function rollForwardDates() {
  const now = today();
  let changed = false;
  for (const s of subs) {
    let d = parseDate(s.nextDate);
    while (d < now) {
      d = advancePeriod(d, s.period);
      changed = true;
    }
    s.nextDate = toISO(d);
  }
  if (changed) save();
}

function daysUntil(iso) {
  return Math.round((parseDate(iso) - today()) / 86400000);
}

function formatDays(n) {
  if (n === 0) return "сегодня";
  if (n === 1) return "завтра";
  const mod10 = n % 10, mod100 = n % 100;
  let word = "дней";
  if (mod10 === 1 && mod100 !== 11) word = "день";
  else if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) word = "дня";
  return `через ${n} ${word}`;
}

const dateFmt = new Intl.DateTimeFormat("ru-RU", { day: "numeric", month: "short" });

/* ============ Деньги ============ */

function monthlyCost(s) {
  return s.price * PERIODS[s.period].perMonth;
}

function formatMoney(value, currency) {
  const rounded = Math.round(value * 100) / 100;
  const str = Number.isInteger(rounded)
    ? rounded.toLocaleString("ru-RU")
    : rounded.toLocaleString("ru-RU", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  return `${str} ${currency}`;
}

// Сводку считаем по основной валюте — той, в которой больше всего подписок
function mainCurrency() {
  const counts = {};
  for (const s of subs) counts[s.currency] = (counts[s.currency] || 0) + 1;
  let best = "₽", max = 0;
  for (const [cur, n] of Object.entries(counts)) {
    if (n > max) { best = cur; max = n; }
  }
  return best;
}

/* ============ Отрисовка ============ */

const $ = (id) => document.getElementById(id);

const els = {
  list: $("subsList"),
  empty: $("emptyState"),
  monthlyTotal: $("monthlyTotal"),
  yearlyTotal: $("yearlyTotal"),
  subsCount: $("subsCount"),
  nextPayment: $("nextPayment"),
  nextPaymentName: $("nextPaymentName"),
  search: $("searchInput"),
  categoryFilter: $("categoryFilter"),
  sort: $("sortSelect"),
  overlay: $("modalOverlay"),
  form: $("subForm"),
  modalTitle: $("modalTitle"),
  toast: $("toast"),
};

function avatarColor(name) {
  let hash = 0;
  for (const ch of name) hash = (hash * 31 + ch.codePointAt(0)) >>> 0;
  return AVATAR_COLORS[hash % AVATAR_COLORS.length];
}

function render() {
  rollForwardDates();
  renderSummary();
  renderCategoryFilter();
  renderList();
}

function renderSummary() {
  const cur = mainCurrency();
  const inMain = subs.filter((s) => s.currency === cur);
  const monthly = inMain.reduce((sum, s) => sum + monthlyCost(s), 0);
  const extra = subs.length - inMain.length;

  els.monthlyTotal.textContent = formatMoney(monthly, cur) + (extra > 0 ? " +" : "");
  els.yearlyTotal.textContent = `${formatMoney(monthly * 12, cur)} в год` +
    (extra > 0 ? ` (ещё ${extra} в др. валюте)` : "");
  els.subsCount.textContent = subs.length;

  if (subs.length === 0) {
    els.nextPayment.textContent = "—";
    els.nextPaymentName.textContent = "";
    return;
  }
  const next = [...subs].sort((a, b) => a.nextDate.localeCompare(b.nextDate))[0];
  els.nextPayment.textContent = formatDays(daysUntil(next.nextDate));
  els.nextPaymentName.textContent = `${next.name} · ${formatMoney(next.price, next.currency)}`;
}

function renderCategoryFilter() {
  const current = els.categoryFilter.value;
  const cats = [...new Set(subs.map((s) => s.category))].sort();
  els.categoryFilter.innerHTML = '<option value="">Все категории</option>' +
    cats.map((c) => `<option value="${escapeHtml(c)}">${escapeHtml(c)}</option>`).join("");
  if (cats.includes(current)) els.categoryFilter.value = current;
}

function renderList() {
  const query = els.search.value.trim().toLowerCase();
  const cat = els.categoryFilter.value;
  const sort = els.sort.value;

  let items = subs.filter((s) =>
    (!query || s.name.toLowerCase().includes(query)) &&
    (!cat || s.category === cat)
  );

  items.sort((a, b) => {
    if (sort === "price") return monthlyCost(b) - monthlyCost(a);
    if (sort === "name") return a.name.localeCompare(b.name, "ru");
    return a.nextDate.localeCompare(b.nextDate);
  });

  els.empty.classList.toggle("visible", subs.length === 0);
  els.list.innerHTML = items.map(cardHtml).join("");
}

function cardHtml(s) {
  const days = daysUntil(s.nextDate);
  const dueClass = days === 0 ? "sub-due-today" : days <= 3 ? "sub-due-soon" : "";
  const letter = s.name.trim().charAt(0).toUpperCase() || "?";
  return `
    <article class="sub-card" data-id="${s.id}">
      <div class="sub-avatar" style="background:${avatarColor(s.name)}">${escapeHtml(letter)}</div>
      <div class="sub-info">
        <div class="sub-name">${escapeHtml(s.name)}</div>
        <div class="sub-meta">
          ${escapeHtml(s.category)} ·
          <span class="${dueClass}">${dateFmt.format(parseDate(s.nextDate))}, ${formatDays(days)}</span>
        </div>
      </div>
      <div class="sub-price">
        <div class="sub-price-value">${formatMoney(s.price, s.currency)}</div>
        <div class="sub-price-period">за ${PERIODS[s.period].label}</div>
      </div>
      <div class="sub-actions">
        <button class="icon-btn" data-action="edit" title="Редактировать">✏️</button>
        <button class="icon-btn" data-action="delete" title="Удалить">🗑️</button>
      </div>
    </article>`;
}

function escapeHtml(str) {
  return String(str).replace(/[&<>"']/g, (c) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  })[c]);
}

/* ============ Модалка ============ */

function openModal(sub) {
  els.modalTitle.textContent = sub ? "Редактировать подписку" : "Новая подписка";
  $("subId").value = sub ? sub.id : "";
  $("subName").value = sub ? sub.name : "";
  $("subPrice").value = sub ? sub.price : "";
  $("subCurrency").value = sub ? sub.currency : "₽";
  $("subPeriod").value = sub ? sub.period : "month";
  $("subDate").value = sub ? sub.nextDate : toISO(advancePeriod(today(), "month"));
  $("subCategory").value = sub ? sub.category : "Развлечения";
  els.overlay.hidden = false;
  $("subName").focus();
}

function closeModal() {
  els.overlay.hidden = true;
}

els.form.addEventListener("submit", (e) => {
  e.preventDefault();
  const id = $("subId").value;
  const data = {
    name: $("subName").value.trim(),
    price: parseFloat($("subPrice").value),
    currency: $("subCurrency").value,
    period: $("subPeriod").value,
    nextDate: $("subDate").value,
    category: $("subCategory").value,
  };
  if (!data.name || !(data.price >= 0) || !data.nextDate) return;

  if (id) {
    const sub = subs.find((s) => s.id === id);
    if (sub) Object.assign(sub, data);
    showToast("Подписка обновлена");
  } else {
    subs.push({ id: crypto.randomUUID(), ...data });
    showToast("Подписка добавлена");
  }
  save();
  closeModal();
  render();
});

/* ============ События ============ */

$("addBtn").addEventListener("click", () => openModal(null));
$("emptyAddBtn").addEventListener("click", () => openModal(null));
$("cancelBtn").addEventListener("click", closeModal);

els.overlay.addEventListener("click", (e) => {
  if (e.target === els.overlay) closeModal();
});

document.addEventListener("keydown", (e) => {
  if (e.key === "Escape" && !els.overlay.hidden) closeModal();
});

els.list.addEventListener("click", (e) => {
  const btn = e.target.closest("[data-action]");
  if (!btn) return;
  const id = btn.closest(".sub-card").dataset.id;
  const sub = subs.find((s) => s.id === id);
  if (!sub) return;

  if (btn.dataset.action === "edit") {
    openModal(sub);
  } else if (btn.dataset.action === "delete") {
    if (confirm(`Удалить «${sub.name}»?`)) {
      subs = subs.filter((s) => s.id !== id);
      save();
      render();
      showToast("Подписка удалена");
    }
  }
});

els.search.addEventListener("input", renderList);
els.categoryFilter.addEventListener("change", renderList);
els.sort.addEventListener("change", renderList);

/* ============ Экспорт / импорт ============ */

$("exportBtn").addEventListener("click", () => {
  const blob = new Blob([JSON.stringify(subs, null, 2)], { type: "application/json" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = `subtrack-${toISO(today())}.json`;
  a.click();
  URL.revokeObjectURL(a.href);
});

$("importBtn").addEventListener("click", () => $("importFile").click());

$("importFile").addEventListener("change", async (e) => {
  const file = e.target.files[0];
  e.target.value = "";
  if (!file) return;
  try {
    const data = JSON.parse(await file.text());
    if (!Array.isArray(data)) throw new Error();
    const incoming = data.filter(isValidSub);
    let added = 0;
    for (const item of incoming) {
      if (!subs.some((s) => s.id === item.id)) {
        subs.push({ ...item, id: item.id || crypto.randomUUID() });
        added++;
      }
    }
    save();
    render();
    showToast(added ? `Импортировано: ${added}` : "Новых подписок нет");
  } catch {
    showToast("Не удалось прочитать файл");
  }
});

/* ============ Тосты ============ */

let toastTimer;
function showToast(text) {
  els.toast.textContent = text;
  els.toast.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { els.toast.hidden = true; }, 2200);
}

/* ============ Инициализация ============ */

$("presetList").innerHTML = PRESETS.map((p) => `<option value="${escapeHtml(p)}">`).join("");

render();

if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("sw.js").catch(() => {});
}
