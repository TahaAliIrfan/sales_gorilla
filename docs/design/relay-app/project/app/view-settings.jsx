/* ============================================================
   Relay app — Settings / Admin: profile, white-label branding
   (live reskin), team & roles, integrations, notifications.
   ============================================================ */

const SETTINGS_TABS = [
  { id: "profile", label: "Profile", icon: "user-cog" },
  { id: "branding", label: "Branding & theme", icon: "palette", admin: true },
  { id: "team", label: "Team & roles", icon: "users-2", admin: true },
  { id: "integrations", label: "Integrations", icon: "plug" },
  { id: "notifications", label: "Notifications", icon: "bell" },
];
const BRAND_SWATCHES = [
  { key: "teal", name: "Teal", hue: 190, chroma: 0.118 },
  { key: "cobalt", name: "Cobalt", hue: 256, chroma: 0.170 },
  { key: "violet", name: "Violet", hue: 295, chroma: 0.190 },
  { key: "amber", name: "Amber", hue: 64, chroma: 0.150 },
  { key: "rose", name: "Rose", hue: 12, chroma: 0.200 },
];
const _L = [0.984, 0.954, 0.910, 0.846, 0.762, 0.682, 0.586, 0.498, 0.420, 0.350, 0.272];
const _CMUL = [0.16, 0.34, 0.56, 0.78, 0.93, 1, 0.90, 0.76, 0.62, 0.48, 0.37];
const _STEPS = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950];
function setBrandHue(hue, chroma) { _STEPS.forEach((s, i) => document.documentElement.style.setProperty("--brand-" + s, `oklch(${_L[i]} ${(chroma * _CMUL[i]).toFixed(3)} ${hue})`)); }

const INTEGRATIONS = [
  { id: "gcal", name: "Google Calendar", desc: "Sync meetings & follow-ups two-way.", icon: "calendar", connected: true, color: "var(--cat-1)" },
  { id: "gmail", name: "Gmail", desc: "Two-way email — send, reply and log automatically.", icon: "mail", connected: true, color: "var(--color-danger)" },
  { id: "odoo", name: "Odoo", desc: "Push proposals & invoices to your Odoo instance.", icon: "file-text", connected: true, color: "var(--cat-5)" },
  { id: "wa", name: "WhatsApp Business", desc: "Send approved templates and 1:1 messages.", icon: "message-circle", connected: true, color: "var(--channel-whatsapp)" },
  { id: "stripe", name: "Stripe", desc: "Collect payments on public invoice pages.", icon: "credit-card", connected: false, color: "var(--cat-5)" },
  { id: "voip", name: "Twilio Voice", desc: "Browser calling with auto-recording.", icon: "phone", connected: true, color: "var(--color-danger)" },
];

function ViewSettings() {
  const app = useApp();
  const [tab, setTab] = useState(app.route.params.tab || "profile");
  const visibleTabs = SETTINGS_TABS.filter((t) => !t.admin || app.role !== "associate");

  return (
    <div className="page page--wide">
      <div className="pagehead" style={{ marginBottom: "var(--space-5)" }}>
        <div><div className="pagehead__title">Settings</div><div className="pagehead__sub">Manage your profile, your workspace, branding and integrations.</div></div>
      </div>
      <div className="grid" style={{ gridTemplateColumns: "220px 1fr", gap: "var(--space-6)", alignItems: "start" }}>
        {/* settings nav */}
        <div className="col" style={{ gap: 2, position: "sticky", top: 0 }}>
          {visibleTabs.map((t) => (
            <button key={t.id} className={cx("rl-navlink", tab === t.id && "is-active")} onClick={() => setTab(t.id)}
              style={tab === t.id ? {} : { color: "var(--color-fg-2)", background: "transparent" }}>
              <Icon name={t.icon} size={17} /><span>{t.label}</span>
            </button>
          ))}
          {app.role !== "associate" && <button className="rl-navlink" style={{ color: "var(--color-fg-2)" }} onClick={() => app.navigate("pipeline")}><Icon name="layers" size={17} /><span>Pipeline stages</span></button>}
        </div>

        {/* panel */}
        <div className="route-enter" style={{ minWidth: 0 }}>
          {tab === "profile" && <ProfilePanel />}
          {tab === "branding" && <BrandingPanel />}
          {tab === "team" && <TeamPanel />}
          {tab === "integrations" && <IntegrationsPanel />}
          {tab === "notifications" && <NotificationsPanel />}
        </div>
      </div>
    </div>
  );
}

/* ---------- Profile ---------- */
function ProfilePanel() {
  const app = useApp();
  return (
    <div className="col" style={{ gap: "var(--space-5)", maxWidth: 720 }}>
      <div className="sect"><div className="sect__head"><div className="sect__title">Profile</div></div><div className="sect__body">
        <div className="row" style={{ gap: 16, marginBottom: 20 }}>
          <Avatar user={app.me} size="xl" />
          <div><button className="rl-btn rl-btn--secondary rl-btn--sm"><Icon name="upload" size={14} />Change photo</button><div className="muted" style={{ fontSize: 12, marginTop: 6 }}>JPG or PNG, up to 2 MB.</div></div>
        </div>
        <div className="grid grid-2" style={{ gap: 14 }}>
          <div className="rl-field"><label className="rl-label">Full name</label><input className="rl-input" defaultValue={app.me.name} /></div>
          <div className="rl-field"><label className="rl-label">Job title</label><input className="rl-input" defaultValue={app.me.title} /></div>
          <div className="rl-field"><label className="rl-label">Email</label><input className="rl-input" defaultValue={app.me.email} /></div>
          <div className="rl-field"><label className="rl-label">Timezone</label><select className="rl-select"><option>America/Chicago (CST)</option><option>America/New_York (EST)</option><option>Europe/London (GMT)</option></select></div>
        </div>
      </div></div>

      <div className="sect"><div className="sect__head"><div className="sect__title">Working hours & availability</div></div><div className="sect__body">
        <div className="grid grid-2" style={{ gap: 14 }}>
          <div className="rl-field"><label className="rl-label">Day starts</label><input className="rl-input" type="time" defaultValue="09:00" /></div>
          <div className="rl-field"><label className="rl-label">Day ends</label><input className="rl-input" type="time" defaultValue="17:30" /></div>
        </div>
        <label className="rl-check" style={{ marginTop: 14 }}><input type="checkbox" defaultChecked /><span className="rl-box"><Icon name="check" size={13} /></span>Pause campaign sends outside working hours</label>
      </div></div>

      <div className="sect"><div className="sect__head"><div className="sect__title">Appearance</div></div><div className="sect__body">
        <div className="spread" style={{ marginBottom: 14 }}>
          <div><b className="rl-sm">Theme</b><div className="muted" style={{ fontSize: 12 }}>Light or dark interface.</div></div>
          <div className="rl-segmented"><button className={app.theme === "light" ? "is-active" : ""} onClick={() => app.setTheme("light")}><Icon name="sun" size={14} style={{ marginRight: 5 }} />Light</button><button className={app.theme === "dark" ? "is-active" : ""} onClick={() => app.setTheme("dark")}><Icon name="moon" size={14} style={{ marginRight: 5 }} />Dark</button></div>
        </div>
        <div className="spread">
          <div><b className="rl-sm">Density</b><div className="muted" style={{ fontSize: 12 }}>Comfortable or compact tables.</div></div>
          <div className="rl-segmented"><button className={app.density === "comfortable" ? "is-active" : ""} onClick={() => app.setDensity("comfortable")}>Comfortable</button><button className={app.density === "compact" ? "is-active" : ""} onClick={() => app.setDensity("compact")}>Compact</button></div>
        </div>
      </div></div>
      <div className="row" style={{ justifyContent: "flex-end", gap: 8 }}><button className="rl-btn rl-btn--ghost">Cancel</button><button className="rl-btn rl-btn--primary" onClick={() => app.toast("Profile saved", "success")}>Save changes</button></div>
    </div>
  );
}

/* ---------- Branding (white-label, live reskin) ---------- */
function BrandingPanel() {
  const app = useApp();
  const [name, setName] = useState(app.productName);
  const [activeKey, setActiveKey] = useState(app.brand);
  const [hue, setHue] = useState(190);
  const [custom, setCustom] = useState(false);

  const pickPreset = (sw) => { setCustom(false); setActiveKey(sw.key); app.setBrand(sw.key); };
  const pickHue = (h) => { setCustom(true); setActiveKey(null); setHue(h); setBrandHue(h, 0.16); };

  return (
    <div className="col" style={{ gap: "var(--space-5)", maxWidth: 860 }}>
      <div style={{ background: "var(--color-primary-subtle)", border: "1px solid var(--color-primary-border)", borderRadius: "var(--radius-lg)", padding: "14px 16px" }} className="row">
        <Icon name="sparkles" size={18} style={{ color: "var(--color-primary-text)" }} />
        <div className="rl-sm" style={{ color: "var(--color-primary-text)" }}><b>White-label.</b> Set your product name, logo and brand colour — the entire interface reskins from one colour. Changes here apply live across the whole app.</div>
      </div>

      <div className="grid" style={{ gridTemplateColumns: "1fr 1fr", gap: "var(--space-5)", alignItems: "start" }}>
        {/* controls */}
        <div className="col" style={{ gap: "var(--space-5)" }}>
          <div className="sect"><div className="sect__head"><div className="sect__title">Identity</div></div><div className="sect__body">
            <div className="rl-field" style={{ marginBottom: 16 }}><label className="rl-label">Product name</label><input className="rl-input" value={name} onChange={(e) => { setName(e.target.value); app.setProductName(e.target.value); }} /></div>
            <label className="rl-label" style={{ marginBottom: 8 }}>Logo</label>
            <div className="row" style={{ gap: 12 }}>
              <span className="rl-logo" style={{ width: 48, height: 48, borderRadius: 12, background: "var(--color-primary)", display: "grid", placeItems: "center", color: "#fff" }}>
                <svg viewBox="0 0 32 32" width="26" height="26" fill="none"><path d="M6 7.5 L14.5 16 L6 24.5" stroke="currentColor" strokeWidth="4" strokeLinecap="round" strokeLinejoin="round" /><path d="M15.5 7.5 L24 16 L15.5 24.5" stroke="currentColor" strokeWidth="4" strokeLinecap="round" strokeLinejoin="round" opacity="0.55" /></svg>
              </span>
              <button className="rl-btn rl-btn--secondary rl-btn--sm"><Icon name="upload" size={14} />Upload logo</button>
              <span className="muted" style={{ fontSize: 12 }}>SVG or PNG, square.</span>
            </div>
          </div></div>

          <div className="sect"><div className="sect__head"><div className="sect__title">Brand colour</div></div><div className="sect__body">
            <div className="row" style={{ gap: 10, marginBottom: 18, flexWrap: "wrap" }}>
              {BRAND_SWATCHES.map((sw) => (
                <button key={sw.key} onClick={() => pickPreset(sw)} title={sw.name} style={{ width: 44, height: 44, borderRadius: 12, border: activeKey === sw.key ? "3px solid var(--color-fg)" : "2px solid var(--color-border)", background: `oklch(${sw.key === "amber" ? 0.64 : 0.55} ${sw.chroma} ${sw.hue})`, cursor: "pointer", boxShadow: "var(--shadow-xs)" }} />
              ))}
            </div>
            <label className="rl-label" style={{ marginBottom: 8 }}>Custom hue {custom && <span className="rl-badge rl-badge--primary" style={{ marginLeft: 6 }}>{hue}°</span>}</label>
            <input className="rl-range" type="range" min="0" max="360" value={hue} onChange={(e) => pickHue(+e.target.value)}
              style={{ background: "linear-gradient(90deg, oklch(0.6 0.18 0), oklch(0.6 0.18 60), oklch(0.6 0.18 120), oklch(0.6 0.18 180), oklch(0.6 0.18 240), oklch(0.6 0.18 300), oklch(0.6 0.18 360))" }} />
          </div></div>
        </div>

        {/* live preview */}
        <div className="sect" style={{ position: "sticky", top: 0 }}>
          <div className="sect__head"><div className="sect__title"><Icon name="eye" size={18} />Live preview</div></div>
          <div className="sect__body" style={{ background: "var(--color-bg)" }}>
            {/* mini app */}
            <div style={{ display: "grid", gridTemplateColumns: "84px 1fr", borderRadius: "var(--radius-lg)", overflow: "hidden", border: "1px solid var(--color-border)", boxShadow: "var(--shadow-sm)", marginBottom: 16 }}>
              <div style={{ background: "var(--color-sidebar)", padding: 10 }}>
                <div className="row" style={{ gap: 6, marginBottom: 14 }}><span style={{ width: 22, height: 22, borderRadius: 6, background: "var(--color-primary)", display: "grid", placeItems: "center" }}><svg viewBox="0 0 32 32" width="13" height="13" fill="none"><path d="M6 7.5 L14.5 16 L6 24.5" stroke="#fff" strokeWidth="4.5" strokeLinecap="round" strokeLinejoin="round" /></svg></span><b style={{ color: "#fff", fontSize: 11, fontFamily: "var(--font-display)" }}>{name.slice(0, 7)}</b></div>
                <div style={{ height: 20, borderRadius: 6, background: "var(--color-primary)", marginBottom: 6 }} />
                {[0, 1, 2].map((i) => <div key={i} style={{ height: 16, borderRadius: 6, background: "rgba(255,255,255,.06)", marginBottom: 6 }} />)}
              </div>
              <div style={{ background: "var(--color-surface)", padding: 12 }}>
                <div style={{ height: 10, width: 90, background: "var(--color-fg)", borderRadius: 3, marginBottom: 10, opacity: .85 }} />
                <div className="row" style={{ gap: 6, marginBottom: 10 }}><span className="rl-pill rl-pill--brand"><i className="rl-dot" />Qualified</span><span className="rl-pill rl-pill--success"><i className="rl-dot" />Won</span></div>
                <div className="rl-msgrow rl-msgrow--out" style={{ maxWidth: "100%" }}><div className="rl-bubble rl-bubble--out" style={{ fontSize: 11 }}>On for Thursday 👍</div></div>
              </div>
            </div>
            <div className="row" style={{ gap: 8, marginBottom: 12, flexWrap: "wrap" }}>
              <button className="rl-btn rl-btn--primary rl-btn--sm">Primary</button>
              <button className="rl-btn rl-btn--brand-soft rl-btn--sm">Soft</button>
              <button className="rl-btn rl-btn--secondary rl-btn--sm">Secondary</button>
            </div>
            <div className="rl-stat" style={{ padding: 14 }}><div className="rl-stat__label">Conversion</div><div className="rl-stat__value" style={{ fontSize: 24 }}>24%</div><div className="rl-stat__delta rl-delta-up"><Icon name="trending-up" size={12} />+3pt</div></div>
          </div>
        </div>
      </div>
      <div className="row" style={{ justifyContent: "flex-end", gap: 8 }}><button className="rl-btn rl-btn--ghost" onClick={() => { pickPreset(BRAND_SWATCHES[0]); app.setProductName("Meridian"); setName("Meridian"); }}>Reset</button><button className="rl-btn rl-btn--primary" onClick={() => app.toast("Branding published to all tenants users", "success")}><Icon name="check" size={15} />Publish branding</button></div>
    </div>
  );
}

/* ---------- Team & roles ---------- */
const ROLE_BADGE = { admin: "rl-badge--danger", manager: "rl-badge--info", associate: "rl-badge--neutral" };
function TeamPanel() {
  const app = useApp();
  const [users, setUsers] = useState(Object.values(RX.USERS));
  const [invite, setInvite] = useState(false);
  return (
    <div className="col" style={{ gap: "var(--space-5)", maxWidth: 900 }}>
      <div className="spread"><div><b style={{ fontSize: "var(--text-h4)", fontWeight: 700 }}>Team & roles</b><div className="muted rl-sm">Admin → Manager → Associate. Managers oversee assigned associates and pipelines.</div></div><button className="rl-btn rl-btn--primary" onClick={() => setInvite(true)}><Icon name="user-plus" size={15} />Invite user</button></div>
      <div className="rl-table-wrap"><table className="rl-table">
        <thead><tr><th>User</th><th>Role</th><th>Reports to</th><th>Pipelines</th><th style={{ textAlign: "right" }}>Status</th><th></th></tr></thead>
        <tbody>
          {users.map((u) => (
            <tr key={u.id}>
              <td><div className="row" style={{ gap: 10 }}><Avatar user={u} size="sm" /><div><div className="rl-cell-strong">{u.name}</div><div className="muted" style={{ fontSize: 11 }}>{u.email}</div></div></div></td>
              <td><Dropdown trigger={(o, t) => <button className="rl-chip" style={{ height: 28 }} onClick={t}><span className={cx("rl-badge", ROLE_BADGE[u.role])} style={{ textTransform: "capitalize" }}>{u.role}</span><Icon name="chevron-down" size={13} /></button>}>
                {["admin", "manager", "associate"].map((r) => <div key={r} className="rl-menuitem" style={{ textTransform: "capitalize" }} onClick={() => { setUsers((us) => us.map((x) => x.id === u.id ? { ...x, role: r } : x)); app.toast(u.first + " is now " + r, "success"); }}>{r}{u.role === r && <span className="rl-check-trail"><Icon name="check" size={15} /></span>}</div>)}
              </Dropdown></td>
              <td className="muted">{u.role === "associate" ? "Marcus Bell" : u.role === "manager" ? "Dana Okafor" : "—"}</td>
              <td>{u.role === "admin" ? <span className="rl-badge">All</span> : <span className="rl-badge rl-badge--primary">{u.role === "manager" ? "3 pipelines" : "Outbound"}</span>}</td>
              <td style={{ textAlign: "right" }}><span className="rl-pill rl-pill--success" style={{ display: "inline-flex" }}><i className="rl-dot" />Active</span></td>
              <td><Dropdown align="right" trigger={(o, t) => <button className="rl-iconbtn rl-iconbtn--sm" onClick={t}><Icon name="more-horizontal" size={16} /></button>}>
                <div className="rl-menuitem"><Icon name="user-cog" />Edit access</div>
                <div className="rl-menuitem"><Icon name="link" />Assign pipelines</div>
                <div className="rl-menu__sep" /><div className="rl-menuitem is-danger"><Icon name="user-x" />Deactivate</div>
              </Dropdown></td>
            </tr>
          ))}
        </tbody>
      </table></div>
      {invite && <Modal onClose={() => setInvite(false)} width={480}>
        <div className="rl-modal__head"><div className="rl-modal__icon rl-modal__icon--brand"><Icon name="user-plus" size={20} /></div><div><div className="rl-modal__title">Invite user</div><div className="muted rl-sm" style={{ marginTop: 2 }}>They'll get an email to join Meridian.</div></div><button className="rl-iconbtn rl-modal__close" onClick={() => setInvite(false)}><Icon name="x" size={18} /></button></div>
        <div className="rl-modal__body"><div className="rl-field" style={{ marginBottom: 14 }}><label className="rl-label">Email</label><input className="rl-input" placeholder="name@meridiangrowth.co" /></div><div className="grid grid-2" style={{ gap: 14 }}><div className="rl-field"><label className="rl-label">Role</label><select className="rl-select"><option>Associate</option><option>Manager</option><option>Admin</option></select></div><div className="rl-field"><label className="rl-label">Reports to</label><select className="rl-select"><option>Marcus Bell</option><option>Dana Okafor</option></select></div></div></div>
        <div className="rl-modal__foot"><button className="rl-btn rl-btn--ghost" onClick={() => setInvite(false)}>Cancel</button><button className="rl-btn rl-btn--primary" onClick={() => { setInvite(false); app.toast("Invite sent", "success"); }}>Send invite</button></div>
      </Modal>}
    </div>
  );
}

/* ---------- Integrations ---------- */
function IntegrationsPanel() {
  const app = useApp();
  const [conns, setConns] = useState(INTEGRATIONS);
  const toggle = (id) => { setConns((c) => c.map((x) => x.id === id ? { ...x, connected: !x.connected } : x)); const it = conns.find((c) => c.id === id); app.toast(it.connected ? it.name + " disconnected" : it.name + " connected", it.connected ? "info" : "success"); };
  return (
    <div className="col" style={{ gap: "var(--space-4)", maxWidth: 760 }}>
      <div><b style={{ fontSize: "var(--text-h4)", fontWeight: 700 }}>Integrations</b><div className="muted rl-sm">Connect the tools Meridian runs on.</div></div>
      <div className="grid grid-2">
        {conns.map((it) => (
          <div className="sect" key={it.id}><div className="sect__body" style={{ padding: 16 }}>
            <div className="spread" style={{ marginBottom: 10 }}>
              <span className="iccircle" style={{ width: 40, height: 40, background: `color-mix(in oklch, ${it.color} 14%, transparent)`, color: it.color }}><Icon name={it.icon} size={19} /></span>
              {it.connected ? <span className="rl-pill rl-pill--success"><i className="rl-dot" />Connected</span> : <span className="rl-pill"><i className="rl-dot" style={{ background: "var(--color-fg-4)" }} />Not connected</span>}
            </div>
            <b style={{ fontWeight: 700 }}>{it.name}</b>
            <div className="muted rl-sm" style={{ marginTop: 2, marginBottom: 14, minHeight: 36 }}>{it.desc}</div>
            <button className={cx("rl-btn rl-btn--sm rl-btn--block", it.connected ? "rl-btn--secondary" : "rl-btn--primary")} onClick={() => toggle(it.id)}>
              <Icon name={it.connected ? "unplug" : "plug"} size={14} />{it.connected ? "Disconnect" : "Connect"}
            </button>
          </div></div>
        ))}
      </div>
    </div>
  );
}

/* ---------- Notification prefs ---------- */
function NotificationsPanel() {
  const app = useApp();
  const groups = [
    { title: "Conversations", items: [["New WhatsApp reply", true], ["New email reply", true], ["Missed call", true], ["@mentions in notes", true]] },
    { title: "Pipeline & money", items: [["Deal stage changes", true], ["Deal won/lost", true], ["Invoice paid", true], ["Invoice overdue", false]] },
    { title: "Leads & tasks", items: [["New unassigned lead", true], ["Lead assigned to me", true], ["Follow-up due", true], ["Daily summary email", false]] },
  ];
  return (
    <div className="col" style={{ gap: "var(--space-5)", maxWidth: 640 }}>
      <div><b style={{ fontSize: "var(--text-h4)", fontWeight: 700 }}>Notifications</b><div className="muted rl-sm">Choose what reaches you, and where.</div></div>
      {groups.map((g) => (
        <div className="sect" key={g.title}><div className="sect__head"><div className="sect__title" style={{ fontSize: "var(--text-base)" }}>{g.title}</div></div><div className="sect__body--flush">
          {g.items.map(([label, on], i) => (
            <div className="spread" key={i} style={{ padding: "12px 20px", borderBottom: i < g.items.length - 1 ? "1px solid var(--color-divider)" : "none" }}>
              <span className="rl-sm">{label}</span>
              <DefaultSwitch on={on} />
            </div>
          ))}
        </div></div>
      ))}
    </div>
  );
}
function DefaultSwitch({ on }) {
  const [v, setV] = useState(on);
  return <label className="rl-switch"><input type="checkbox" checked={v} onChange={() => setV(!v)} /><span className="rl-track" /></label>;
}

/* expose NotificationsPanel under a settings-specific name to avoid collision with shell NotifPanel */
window.ViewSettings = ViewSettings;
