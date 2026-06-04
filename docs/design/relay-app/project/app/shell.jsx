/* ============================================================
   Relay app — shell: sidebar, topbar, command palette,
   notifications, global call bar, toaster.
   ============================================================ */

const NAV = [
  { view: "today", label: "Today", icon: "sunrise" },
  { view: "leads", label: "Leads", icon: "users" },
  { view: "inbox", label: "Inbox", icon: "message-square", badgeKey: "inboxUnread" },
  { view: "pipeline", label: "Pipeline", icon: "layers" },
  { view: "outreach", label: "Outreach", icon: "megaphone" },
  { view: "insights", label: "Insights", icon: "bar-chart-3" },
];

/* ---------- Sidebar ---------- */
function Sidebar() {
  const app = useApp();
  const { route, navigate, collapsed, setCollapsed, me, inboxUnread, productName } = app;
  const active = route.view;
  const counts = { inboxUnread };
  return (
    <aside className={cx("rl-sidebar", collapsed && "is-collapsed")}>
      <div className="rl-sidebar__brand">
        <span className="rl-logo">
          <svg viewBox="0 0 32 32" fill="none"><path d="M6 7.5 L14.5 16 L6 24.5" stroke="currentColor" strokeWidth="4" strokeLinecap="round" strokeLinejoin="round" /><path d="M15.5 7.5 L24 16 L15.5 24.5" stroke="currentColor" strokeWidth="4" strokeLinecap="round" strokeLinejoin="round" opacity="0.55" /></svg>
        </span>
        <b>{productName || RX.TENANT.name}</b>
      </div>

      <nav className="rl-sidebar__nav">
        <div className="rl-navgroup-label">Workspace</div>
        {NAV.map((n) => (
          <a key={n.view} className={cx("rl-navlink", active === n.view && "is-active")} onClick={() => navigate(n.view)} title={n.label}>
            <Icon name={n.icon} size={18} />
            <span>{n.label}</span>
            {n.badgeKey && counts[n.badgeKey] > 0 && <span className="rl-navbadge">{counts[n.badgeKey]}</span>}
          </a>
        ))}

        <div className="rl-navgroup-label">Money</div>
        <a className={cx("rl-navlink", active === "billing" && "is-active")} onClick={() => navigate("billing")} title="Quotes & invoices">
          <Icon name="receipt" size={18} /><span>Quotes &amp; invoices</span>
        </a>

        <div style={{ flex: 1 }} />
        <div className="rl-navgroup-label">System</div>
        <a className={cx("rl-navlink", active === "settings" && "is-active")} onClick={() => navigate("settings")} title="Settings">
          <Icon name="settings" size={18} /><span>Settings</span>
        </a>
        <a className="rl-navlink" onClick={() => setCollapsed(!collapsed)} title="Collapse">
          <Icon name={collapsed ? "chevrons-right" : "chevrons-left"} size={18} /><span>Collapse</span>
        </a>
      </nav>

      <div className="rl-sidebar__foot">
        <div className="rl-userchip" onClick={() => navigate("settings", { tab: "profile" })}>
          <Avatar user={me} size="sm" />
          <div className="rl-userchip__main">
            <div className="rl-userchip__name">{me.name}</div>
            <div className="rl-userchip__role" style={{ textTransform: "capitalize" }}>{me.role} · {RX.TENANT.name}</div>
          </div>
          <Icon name="chevron-up" size={15} style={{ color: "var(--color-fg-on-sidebar-3)" }} />
        </div>
      </div>
    </aside>
  );
}

/* ---------- Topbar ---------- */
function Topbar({ title }) {
  const app = useApp();
  const { navigate, setCmdOpen, notifs, markAllRead, me, setRole, startCall, toast } = app;
  const unread = notifs.filter((n) => n.unread).length;
  const [notifOpen, setNotifOpen] = useState(false);
  const notifRef = useRef(null);
  useEffect(() => {
    if (!notifOpen) return;
    const h = (e) => { if (notifRef.current && !notifRef.current.contains(e.target)) setNotifOpen(false); };
    document.addEventListener("mousedown", h); return () => document.removeEventListener("mousedown", h);
  }, [notifOpen]);

  return (
    <header className="app__top">
      <div className="app__search" onClick={() => setCmdOpen(true)}>
        <Icon name="search" size={16} />
        <input readOnly placeholder="Search leads, deals, actions…" />
        <span className="rl-kbd">⌘K</span>
      </div>
      <div className="grow" />

      {/* quick add */}
      <Dropdown align="right" width={210} trigger={(open, t) => (
        <button className="rl-btn rl-btn--primary rl-btn--sm" onClick={t}><Icon name="plus" size={15} />New<Icon name="chevron-down" size={14} /></button>
      )}>
        <div className="rl-menuitem" onClick={() => navigate("leads", { add: true })}><Icon name="user-plus" />Add lead</div>
        <div className="rl-menuitem" onClick={() => navigate("pipeline", { add: true })}><Icon name="circle-dollar-sign" />Create deal</div>
        <div className="rl-menuitem" onClick={() => navigate("today")}><Icon name="check-square" />Add task</div>
        <div className="rl-menu__sep" />
        <div className="rl-menuitem" onClick={() => navigate("outreach", { newCampaign: true })}><Icon name="megaphone" />New campaign</div>
        <div className="rl-menuitem" onClick={() => navigate("leads", { importCsv: true })}><Icon name="upload" />Import CSV</div>
      </Dropdown>

      <div className="rl-tooltip">
        <button className="rl-iconbtn rl-iconbtn--bordered" title="Dialer" onClick={() => startCall(RX.leadByKey("maya"))}><Icon name="phone" size={17} /></button>
      </div>

      {/* notifications */}
      <span ref={notifRef} style={{ position: "relative", display: "inline-flex" }}>
        <button className="rl-iconbtn rl-iconbtn--bordered" style={{ position: "relative" }} onClick={() => setNotifOpen((v) => !v)} title="Notifications">
          <Icon name="bell" size={17} />
          {unread > 0 && <span className="dotcount">{unread}</span>}
        </button>
        {notifOpen && <NotifPanel onClose={() => setNotifOpen(false)} />}
      </span>

      {/* profile / role */}
      <Dropdown align="right" width={230} trigger={(open, t) => (
        <button onClick={t} className="clickable" style={{ border: "none", background: "none", padding: 0, display: "inline-flex" }}><Avatar user={me} size="sm" /></button>
      )}>
        <div style={{ padding: "8px 10px 10px", display: "flex", gap: 10, alignItems: "center" }}>
          <Avatar user={me} />
          <div style={{ minWidth: 0 }}>
            <div style={{ fontWeight: 700, fontSize: "var(--text-sm)" }}>{me.name}</div>
            <div className="muted" style={{ fontSize: 12 }}>{me.email}</div>
          </div>
        </div>
        <div className="rl-menu__sep" />
        <div className="rl-menu__label">View as role</div>
        {["associate", "manager", "admin"].map((r) => (
          <div key={r} className="rl-menuitem" onClick={() => { setRole(r); toast("Now viewing as " + r, "info"); }} style={{ textTransform: "capitalize" }}>
            <Icon name={r === "admin" ? "shield" : r === "manager" ? "users-2" : "user"} />{r}
            {me.role === r && <span className="rl-check-trail"><Icon name="check" size={16} /></span>}
          </div>
        ))}
        <div className="rl-menu__sep" />
        <div className="rl-menuitem" onClick={() => navigate("settings", { tab: "profile" })}><Icon name="user-cog" />Profile &amp; preferences</div>
        <div className="rl-menuitem" onClick={() => navigate("settings", { tab: "integrations" })}><Icon name="plug" />Connections</div>
        <div className="rl-menu__sep" />
        <div className="rl-menuitem is-danger"><Icon name="log-out" />Sign out</div>
      </Dropdown>
    </header>
  );
}

/* ---------- Notifications panel ---------- */
function NotifPanel({ onClose }) {
  const app = useApp();
  const { notifs, markAllRead, markRead, navigate } = app;
  return (
    <div className="menu-float pop" style={{ top: "calc(100% + 8px)", right: 0, width: 360 }}>
      <div className="rl-popover" style={{ width: 360 }}>
        <div className="rl-popover__head">
          <b style={{ fontSize: "var(--text-sm)", fontWeight: 700 }}>Notifications</b>
          <button className="rl-btn rl-btn--ghost rl-btn--sm" onClick={markAllRead}>Mark all read</button>
        </div>
        <div style={{ maxHeight: 380, overflowY: "auto" }}>
          {notifs.map((n) => (
            <div key={n.id} className="rl-listitem clickable" style={{ background: n.unread ? "var(--color-primary-subtle)" : "transparent" }}
              onClick={() => { markRead(n.id); if (n.leadKey) navigate("lead", { key: n.leadKey }); onClose(); }}>
              <span className={cx("iccircle")} style={{ background: "var(--color-surface-3)", color: "var(--color-fg-2)" }}><Icon name={n.icon} size={17} /></span>
              <div className="rl-listitem__main">
                <div className="rl-listitem__title">{n.title}</div>
                <div className="rl-listitem__sub">{n.body}</div>
              </div>
              <div style={{ textAlign: "right", flex: "none" }}>
                <div className="muted" style={{ fontSize: 11 }}>{n.time}</div>
                {n.unread && <span style={{ display: "inline-block", width: 8, height: 8, borderRadius: 999, background: "var(--color-primary)", marginTop: 6 }} />}
              </div>
            </div>
          ))}
        </div>
        <div className="rl-cmd__foot" style={{ justifyContent: "center", cursor: "pointer" }} onClick={onClose}>Close</div>
      </div>
    </div>
  );
}

/* ---------- Command palette ---------- */
function CommandPalette() {
  const app = useApp();
  const { cmdOpen, setCmdOpen, navigate, startCall } = app;
  const [q, setQ] = useState("");
  const [sel, setSel] = useState(0);
  const inputRef = useRef(null);
  useEffect(() => { if (cmdOpen) { setQ(""); setSel(0); setTimeout(() => inputRef.current && inputRef.current.focus(), 30); } }, [cmdOpen]);

  const actions = useMemo(() => [
    { group: "Go to", icon: "sunrise", label: "Today", run: () => navigate("today") },
    { group: "Go to", icon: "users", label: "Leads", run: () => navigate("leads") },
    { group: "Go to", icon: "message-square", label: "Inbox", run: () => navigate("inbox") },
    { group: "Go to", icon: "layers", label: "Pipeline", run: () => navigate("pipeline") },
    { group: "Go to", icon: "megaphone", label: "Outreach", run: () => navigate("outreach") },
    { group: "Go to", icon: "bar-chart-3", label: "Insights", run: () => navigate("insights") },
    { group: "Go to", icon: "settings", label: "Settings", run: () => navigate("settings") },
    { group: "Actions", icon: "user-plus", label: "Add lead", kbd: "L", run: () => navigate("leads", { add: true }) },
    { group: "Actions", icon: "circle-dollar-sign", label: "Create deal", kbd: "D", run: () => navigate("pipeline", { add: true }) },
    { group: "Actions", icon: "upload", label: "Import leads from CSV", run: () => navigate("leads", { importCsv: true }) },
    { group: "Actions", icon: "calculator", label: "New cost estimate", run: () => navigate("billing", { tab: "estimate" }) },
    { group: "Actions", icon: "palette", label: "Branding & theme", run: () => navigate("settings", { tab: "branding" }) },
    ...RX.ALL_LEADS.slice(0, 8).map((l) => ({ group: "Leads", icon: "user", label: l.name + " · " + l.company, run: () => navigate("lead", { key: l.key }), call: l })),
  ], []);
  const filtered = useMemo(() => actions.filter((a) => a.label.toLowerCase().includes(q.toLowerCase())), [q, actions]);
  useEffect(() => setSel(0), [q]);

  if (!cmdOpen) return null;
  const groups = [];
  filtered.forEach((a) => { let g = groups.find((x) => x.name === a.group); if (!g) { g = { name: a.group, items: [] }; groups.push(g); } g.items.push(a); });
  let idx = -1;

  const onKey = (e) => {
    if (e.key === "ArrowDown") { e.preventDefault(); setSel((s) => Math.min(s + 1, filtered.length - 1)); }
    else if (e.key === "ArrowUp") { e.preventDefault(); setSel((s) => Math.max(s - 1, 0)); }
    else if (e.key === "Enter") { const a = filtered[sel]; if (a) { a.run(); setCmdOpen(false); } }
    else if (e.key === "Escape") setCmdOpen(false);
  };
  return (
    <div className="scrim" style={{ alignItems: "flex-start", paddingTop: "12vh", zIndex: "var(--z-command)" }} onMouseDown={(e) => e.target === e.currentTarget && setCmdOpen(false)}>
      <div className="rl-cmd pop" onMouseDown={(e) => e.stopPropagation()}>
        <div className="rl-cmd__input">
          <Icon name="search" size={20} />
          <input ref={inputRef} value={q} onChange={(e) => setQ(e.target.value)} onKeyDown={onKey} placeholder="Type a command or search…" />
          <span className="rl-kbd">esc</span>
        </div>
        <div className="rl-cmd__list">
          {filtered.length === 0 && <div className="muted" style={{ padding: 20, textAlign: "center", fontSize: "var(--text-sm)" }}>No results for “{q}”.</div>}
          {groups.map((g) => (
            <div key={g.name}>
              <div className="rl-cmd__group">{g.name}</div>
              {g.items.map((a) => { idx++; const i = idx; return (
                <div key={a.label} className={cx("rl-cmd__item", i === sel && "is-active")} onMouseEnter={() => setSel(i)} onClick={() => { a.run(); setCmdOpen(false); }}>
                  <Icon name={a.icon} size={17} />
                  <span>{a.label}</span>
                  {a.kbd && <span className="rl-cmd-trail"><span className="rl-kbd">{a.kbd}</span></span>}
                  {a.call && <span className="rl-cmd-trail muted" style={{ fontSize: 11 }}>open</span>}
                </div>
              ); })}
            </div>
          ))}
        </div>
        <div className="rl-cmd__foot">
          <span className="rl-cmd-hint"><span className="rl-kbd">↑</span><span className="rl-kbd">↓</span> navigate</span>
          <span className="rl-cmd-hint"><span className="rl-kbd">↵</span> select</span>
          <span className="rl-cmd-hint"><span className="rl-kbd">esc</span> close</span>
        </div>
      </div>
    </div>
  );
}

/* ---------- Global active-call bar ---------- */
function CallBar() {
  const app = useApp();
  const { call, endCall, toast, navigate } = app;
  const [sec, setSec] = useState(0);
  const [muted, setMuted] = useState(false);
  const [hold, setHold] = useState(false);
  const [keypad, setKeypad] = useState(false);
  const [rec, setRec] = useState(true);
  useEffect(() => { setSec(0); setMuted(false); setHold(false); setKeypad(false); setRec(true); }, [call && call.key]);
  useEffect(() => { if (!call) return; const t = setInterval(() => setSec((s) => s + 1), 1000); return () => clearInterval(t); }, [call]);
  if (!call) return null;
  const mm = String(Math.floor(sec / 60)).padStart(2, "0"), ss = String(sec % 60).padStart(2, "0");
  return (
    <div className="callbar">
      <div className="callbar__strip" />
      <div className="callbar__head">
        <Avatar name={call.name} av="rl-avatar--c1" size="lg" />
        <div className="grow" style={{ minWidth: 0 }}>
          <div style={{ fontWeight: 700, fontSize: "var(--text-base)", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{call.name}</div>
          <div className="row" style={{ gap: 8 }}>
            <span className="mono muted" style={{ fontSize: 12 }}>{call.phone}</span>
          </div>
          <div className="row" style={{ gap: 6, marginTop: 4 }}>
            <span className="pulse-dot" />
            <span className="mono" style={{ fontSize: 13, fontWeight: 700, color: hold ? "var(--color-warning-text)" : "var(--color-fg)" }}>{hold ? "On hold" : mm + ":" + ss}</span>
            {rec && <span className="rl-badge rl-badge--danger" style={{ marginLeft: "auto" }}><Icon name="circle" size={9} />REC</span>}
          </div>
        </div>
      </div>
      {keypad && <div className="callbar__keys">
        {["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"].map((k) => <button key={k} className="callbar__key">{k}</button>)}
      </div>}
      <div className="callbar__actions">
        <button className={cx("callbtn", muted && "is-on")} onClick={() => setMuted(!muted)}><Icon name={muted ? "mic-off" : "mic"} size={18} />Mute</button>
        <button className={cx("callbtn", hold && "is-on")} onClick={() => setHold(!hold)}><Icon name="pause" size={18} />Hold</button>
        <button className={cx("callbtn", keypad && "is-on")} onClick={() => setKeypad(!keypad)}><Icon name="grid-3x3" size={18} />Keypad</button>
        <button className={cx("callbtn", rec && "is-on")} onClick={() => setRec(!rec)}><Icon name="circle" size={18} />Record</button>
        <button className="callbtn callbtn--end" onClick={() => { const k = call.key; endCall(); toast("Call logged · recording + transcript saved", "success"); navigate("lead", { key: k }); }}><Icon name="phone-off" size={18} />End</button>
      </div>
    </div>
  );
}

/* ---------- Toaster ---------- */
function Toaster() {
  const app = useApp();
  const { toasts } = app;
  return (
    <div className="toasts">
      {toasts.map((t) => (
        <div key={t.id} className={cx("toast", "toast--" + (t.type || "info"))}>
          <Icon name={t.type === "success" ? "check-circle-2" : t.type === "danger" ? "alert-circle" : "info"} size={17} />
          {t.msg}
        </div>
      ))}
    </div>
  );
}

Object.assign(window, { Sidebar, Topbar, CommandPalette, CallBar, Toaster, NotifPanel });
