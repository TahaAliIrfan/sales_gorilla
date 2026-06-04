/* Relay DS docs — theme, white-label brand switching, icons */
(function () {
  const STORE_THEME = 'relay-ds-theme';
  const STORE_BRAND = 'relay-ds-brand';

  // White-label brand presets — each overrides ONLY the 11 --brand-* stops.
  // This is exactly what a tenant supplies. Everything else recomputes.
  const BRANDS = {
    teal:   { name: 'Teal',   seed: 'oklch(0.586 0.106 190)', h: 190, c: 0.118 },
    cobalt: { name: 'Cobalt', seed: 'oklch(0.520 0.170 256)', h: 256, c: 0.170 },
    violet: { name: 'Violet', seed: 'oklch(0.530 0.200 295)', h: 295, c: 0.190 },
    amber:  { name: 'Amber',  seed: 'oklch(0.640 0.150 64)',  h: 64,  c: 0.150 },
    rose:   { name: 'Rose',   seed: 'oklch(0.580 0.205 12)',  h: 12,  c: 0.200 },
  };
  // Lightness curve shared by every ramp (keeps perceptual rhythm constant)
  const L = [0.984,0.954,0.910,0.846,0.762,0.682,0.586,0.498,0.420,0.350,0.272];
  const CMUL = [0.16,0.34,0.56,0.78,0.93,1,0.90,0.76,0.62,0.48,0.37];
  const STEPS = [50,100,200,300,400,500,600,700,800,900,950];

  function applyBrand(key) {
    const b = BRANDS[key] || BRANDS.teal;
    const root = document.documentElement;
    STEPS.forEach((step, i) => {
      root.style.setProperty(`--brand-${step}`, `oklch(${L[i]} ${(b.c * CMUL[i]).toFixed(3)} ${b.h})`);
    });
    localStorage.setItem(STORE_BRAND, key);
    document.querySelectorAll('[data-brand-pick]').forEach(el => {
      el.setAttribute('aria-pressed', String(el.dataset.brandPick === key));
    });
  }

  function applyTheme(mode) {
    if (mode === 'dark') document.documentElement.setAttribute('data-theme', 'dark');
    else document.documentElement.removeAttribute('data-theme');
    localStorage.setItem(STORE_THEME, mode);
    document.querySelectorAll('[data-theme-label]').forEach(el => { el.textContent = mode === 'dark' ? 'Dark' : 'Light'; });
  }

  window.RelayDS = {
    applyBrand, applyTheme, BRANDS,
    toggleTheme() { applyTheme(document.documentElement.getAttribute('data-theme') === 'dark' ? 'light' : 'dark'); },
  };

  // boot
  applyTheme(localStorage.getItem(STORE_THEME) || 'light');
  applyBrand(localStorage.getItem(STORE_BRAND) || 'teal');

  document.addEventListener('DOMContentLoaded', () => {
    applyBrand(localStorage.getItem(STORE_BRAND) || 'teal');
    applyTheme(localStorage.getItem(STORE_THEME) || 'light');
    if (window.lucide) window.lucide.createIcons();
    // mark current nav page
    const here = location.pathname.split('/').pop() || 'index.html';
    document.querySelectorAll('.ds-nav a').forEach(a => {
      if (a.getAttribute('href') === here) a.setAttribute('aria-current', 'page');
    });
  });
})();
