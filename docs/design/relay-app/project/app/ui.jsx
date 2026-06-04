/* ============================================================
   Relay app — shared UI primitives. Exposed on window.
   ============================================================ */
const { useState, useEffect, useRef, useMemo, useCallback, createContext, useContext } = React;

/* App-wide context: navigation, role, toasts, state-mode, call */
const AppCtx = createContext(null);
const useApp = () => useContext(AppCtx);

function cx(...a) { return a.filter(Boolean).join(" "); }

/* ---------- Icon (Lucide, React-safe) ---------- */
const INLINE_ICONS = {
  linkedin: '<svg viewBox="0 0 24 24" fill="currentColor" stroke="none"><path d="M20.45 20.45h-3.55v-5.57c0-1.33-.02-3.04-1.85-3.04-1.85 0-2.14 1.45-2.14 2.94v5.66H9.35V9h3.41v1.56h.05c.47-.9 1.64-1.85 3.37-1.85 3.6 0 4.27 2.37 4.27 5.45v6.29zM5.34 7.43a2.06 2.06 0 1 1 0-4.12 2.06 2.06 0 0 1 0 4.12zM7.12 20.45H3.55V9h3.57v11.45zM22.22 0H1.77C.79 0 0 .77 0 1.73v20.54C0 23.22.79 24 1.77 24h20.45c.98 0 1.78-.78 1.78-1.73V1.73C24 .77 23.2 0 22.22 0z"/></svg>',
};
function Icon({ name, size = 18, stroke = 1.9, className = "", style = {} }) {
  const ref = useRef(null);
  useEffect(() => {
    const host = ref.current;
    if (!host) return;
    if (INLINE_ICONS[name]) {
      host.innerHTML = INLINE_ICONS[name];
      const svg = host.querySelector("svg");
      if (svg) { svg.setAttribute("width", size); svg.setAttribute("height", size); svg.style.display = "block"; }
      return;
    }
    if (!window.lucide) return;
    host.innerHTML = '<i data-lucide="' + name + '"></i>';
    try { window.lucide.createIcons(); } catch (e) {}
    const svg = host.querySelector("svg");
    if (svg) {
      svg.setAttribute("width", size);
      svg.setAttribute("height", size);
      svg.setAttribute("stroke-width", stroke);
      svg.style.display = "block";
    }
  });
  return <span ref={ref} className={cx("ic", className)} style={{ display: "inline-flex", width: size, height: size, flex: "none", ...style }} />;
}

/* ---------- Avatar ---------- */
function Avatar({ user, name, av, size = "", presence, square }) {
  const u = user;
  const label = u ? u.initials : (name ? RX.initialsOf(name) : "?");
  const cls = u ? u.av : (av || "rl-avatar--c1");
  const pres = presence || (u && u.presence);
  return (
    <span className={cx("rl-avatar", size && "rl-avatar--" + size, square && "rl-avatar--square", cls)}>
      {label}
      {pres && pres !== "offline" && <span className={cx("rl-presence", "rl-presence--" + (pres === "busy" ? "busy" : pres === "away" ? "away" : "online"))} />}
    </span>
  );
}

/* ---------- Status pill ---------- */
function StatusPill({ status }) {
  const m = RX.STATUS[status] || { pill: "", label: status };
  return <span className={cx("rl-pill", m.pill)}><i className="rl-dot" />{m.label}</span>;
}

/* ---------- Source tag ---------- */
function SourceTag({ source }) {
  const c = RX.SOURCE[source] || "var(--color-fg-3)";
  return <span className="rl-tag"><i className="rl-tag-dot" style={{ background: c }} />{source}</span>;
}

/* ---------- Score meter ---------- */
function Score({ value, showNum = true }) {
  return (
    <span className="score">
      <span className="score__bar"><i style={{ width: value + "%", background: RX.scoreColor(value) }} /></span>
      {showNum && <span className="score__num">{value}</span>}
    </span>
  );
}

/* ---------- Channel pip ---------- */
const CHAN_ICON = { whatsapp: "message-circle", call: "phone", email: "mail", sms: "message-square", linkedin: "linkedin", system: "activity" };
function ChannelPip({ type, ghost }) {
  return <span className={cx("chan", ghost ? "chan--ghost" : "chan--" + type)}><Icon name={CHAN_ICON[type] || "circle"} size={14} /></span>;
}

/* ---------- Sparkline ---------- */
function Spark({ data, w = 120, h = 34, color = "var(--color-primary)", fill = true }) {
  const max = Math.max(...data), min = Math.min(...data);
  const rng = max - min || 1;
  const pts = data.map((v, i) => [(i / (data.length - 1)) * w, h - ((v - min) / rng) * (h - 6) - 3]);
  const line = pts.map((p, i) => (i ? "L" : "M") + p[0].toFixed(1) + " " + p[1].toFixed(1)).join(" ");
  const area = line + ` L${w} ${h} L0 ${h} Z`;
  const gid = "sg" + useMemo(() => Math.random().toString(36).slice(2, 7), []);
  return (
    <svg className="spark" width={w} height={h} viewBox={`0 0 ${w} ${h}`}>
      <defs><linearGradient id={gid} x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor={color} stopOpacity="0.22" /><stop offset="1" stopColor={color} stopOpacity="0" /></linearGradient></defs>
      {fill && <path d={area} fill={`url(#${gid})`} />}
      <path d={line} fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
      <circle cx={pts[pts.length - 1][0]} cy={pts[pts.length - 1][1]} r="2.6" fill={color} />
    </svg>
  );
}

/* ---------- Donut / ring ---------- */
function Ring({ value, size = 64, stroke = 8, color = "var(--color-primary)", track = "var(--color-surface-3)", label, sub }) {
  const r = (size - stroke) / 2, c = 2 * Math.PI * r;
  return (
    <div style={{ position: "relative", width: size, height: size }}>
      <svg width={size} height={size}>
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={track} strokeWidth={stroke} />
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={color} strokeWidth={stroke} strokeLinecap="round"
          strokeDasharray={c} strokeDashoffset={c * (1 - value / 100)} transform={`rotate(-90 ${size / 2} ${size / 2})`}
          style={{ transition: "stroke-dashoffset .6s var(--ease-out)" }} />
      </svg>
      {label && <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", textAlign: "center" }}>
        <div><div style={{ fontFamily: "var(--font-display)", fontWeight: 800, fontSize: 16, lineHeight: 1 }}>{label}</div>{sub && <div style={{ fontSize: 10, color: "var(--color-fg-3)" }}>{sub}</div>}</div>
      </div>}
    </div>
  );
}

/* ---------- Bar chart (simple) ---------- */
function Bars({ data, h = 120, color = "var(--color-primary)" }) {
  const max = Math.max(...data.map((d) => d.v)) || 1;
  return (
    <div style={{ display: "flex", alignItems: "flex-end", gap: 8, height: h }}>
      {data.map((d, i) => (
        <div key={i} style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", gap: 6, height: "100%", justifyContent: "flex-end" }}>
          <div style={{ width: "100%", maxWidth: 30, height: (d.v / max) * (h - 24), background: d.color || color, borderRadius: "5px 5px 2px 2px", transition: "height .5s var(--ease-out)" }} title={d.v} />
          <span style={{ fontSize: 11, color: "var(--color-fg-3)", fontWeight: 600 }}>{d.label}</span>
        </div>
      ))}
    </div>
  );
}

/* ---------- Stat tile ---------- */
function Stat({ label, value, delta, deltaSuffix = "", spark, sparkColor, icon }) {
  const up = delta != null && delta >= 0;
  return (
    <div className="rl-stat">
      <div className="spread">
        <span className="rl-stat__label">{label}</span>
        {icon && <span style={{ color: "var(--color-fg-4)" }}><Icon name={icon} size={16} /></span>}
      </div>
      <div className="rl-stat__value">{value}</div>
      <div className="spread" style={{ alignItems: "flex-end" }}>
        {delta != null && <span className={cx("rl-stat__delta", up ? "rl-delta-up" : "rl-delta-down")}>
          <Icon name={up ? "trending-up" : "trending-down"} size={13} />{up ? "+" : ""}{delta}{deltaSuffix}
        </span>}
        {spark && <Spark data={spark} w={92} h={28} color={sparkColor || "var(--color-primary)"} />}
      </div>
    </div>
  );
}

/* ---------- Empty state ---------- */
function Empty({ icon = "inbox", title, body, action }) {
  return (
    <div className="empty">
      <div className="empty__ic"><Icon name={icon} size={26} /></div>
      <div className="rl-h4" style={{ marginBottom: 4 }}>{title}</div>
      {body && <div className="muted rl-sm" style={{ maxWidth: 360 }}>{body}</div>}
      {action && <div style={{ marginTop: 16 }}>{action}</div>}
    </div>
  );
}

/* ---------- Skeleton table ---------- */
function SkeletonRows({ rows = 8 }) {
  return (
    <div>
      {Array.from({ length: rows }).map((_, i) => (
        <div className="skelrow" key={i}>
          <div className="rl-skel" style={{ width: 18, height: 18, borderRadius: 5 }} />
          <div className="rl-skel" style={{ width: 32, height: 32, borderRadius: 999 }} />
          <div className="rl-skel" style={{ height: 12, width: 160 + (i % 3) * 40 }} />
          <div className="rl-skel" style={{ height: 12, width: 90, marginLeft: "auto" }} />
          <div className="rl-skel" style={{ height: 22, width: 70, borderRadius: 999 }} />
          <div className="rl-skel" style={{ height: 12, width: 50 }} />
        </div>
      ))}
    </div>
  );
}

/* ---------- Inline error panel ---------- */
function ErrorPanel({ title = "Something went wrong", body = "Couldn't load this view. Your changes were not lost.", onRetry }) {
  return (
    <div className="empty">
      <div className="empty__ic" style={{ background: "var(--color-danger-subtle)", borderColor: "var(--color-danger-border)", color: "var(--color-danger-text)" }}><Icon name="cloud-off" size={26} /></div>
      <div className="rl-h4" style={{ marginBottom: 4 }}>{title}</div>
      <div className="muted rl-sm" style={{ maxWidth: 360 }}>{body}</div>
      {onRetry && <button className="rl-btn rl-btn--secondary" style={{ marginTop: 16 }} onClick={onRetry}><Icon name="refresh-cw" size={15} />Try again</button>}
    </div>
  );
}

/* ---------- Modal shell ---------- */
function Modal({ children, onClose, width = 480 }) {
  useEffect(() => {
    const h = (e) => e.key === "Escape" && onClose && onClose();
    window.addEventListener("keydown", h); return () => window.removeEventListener("keydown", h);
  }, [onClose]);
  return (
    <div className="scrim" onMouseDown={(e) => e.target === e.currentTarget && onClose && onClose()}>
      <div className="rl-modal pop" style={{ width: "min(" + width + "px, 94vw)" }} onMouseDown={(e) => e.stopPropagation()}>{children}</div>
    </div>
  );
}

/* ---------- Drawer shell ---------- */
function Drawer({ children, onClose, wide }) {
  useEffect(() => {
    const h = (e) => e.key === "Escape" && onClose && onClose();
    window.addEventListener("keydown", h); return () => window.removeEventListener("keydown", h);
  }, [onClose]);
  return (
    <div className="scrim" style={{ placeItems: "stretch", padding: 0 }} onMouseDown={(e) => e.target === e.currentTarget && onClose && onClose()}>
      <div className={cx("drawer", wide && "drawer--wide")} onMouseDown={(e) => e.stopPropagation()}>{children}</div>
    </div>
  );
}

/* ---------- Dropdown (click-away) ---------- */
function Dropdown({ trigger, children, align = "left", width = 220 }) {
  const [open, setOpen] = useState(false);
  const ref = useRef(null);
  useEffect(() => {
    if (!open) return;
    const h = (e) => { if (ref.current && !ref.current.contains(e.target)) setOpen(false); };
    document.addEventListener("mousedown", h); return () => document.removeEventListener("mousedown", h);
  }, [open]);
  return (
    <span ref={ref} style={{ position: "relative", display: "inline-flex" }}>
      {trigger(open, () => setOpen((v) => !v))}
      {open && <div className="menu-float pop" style={{ top: "calc(100% + 6px)", [align]: 0 }} onClick={() => setOpen(false)}>
        <div className="rl-menu" style={{ minWidth: width }}>{children}</div>
      </div>}
    </span>
  );
}

Object.assign(window, {
  AppCtx, useApp, cx, Icon, Avatar, StatusPill, SourceTag, Score, ChannelPip, Spark, Ring, Bars, Stat, Empty, SkeletonRows, ErrorPanel, Modal, Drawer, Dropdown,
});
