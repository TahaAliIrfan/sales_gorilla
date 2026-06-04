/* ============================================================
   Relay app — root: context, routing, global state, tweaks.
   ============================================================ */

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "brand": "teal",
  "theme": "light",
  "role": "associate",
  "state": "normal",
  "density": "comfortable"
}/*EDITMODE-END*/;

const BRAND_PRESETS = [
  { key: "teal", swatch: "oklch(0.55 0.118 190)" },
  { key: "cobalt", swatch: "oklch(0.52 0.170 256)" },
  { key: "violet", swatch: "oklch(0.53 0.190 295)" },
  { key: "amber", swatch: "oklch(0.64 0.150 64)" },
  { key: "rose", swatch: "oklch(0.55 0.200 12)" },
];

function App() {
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);
  const role = t.role, brand = t.brand, theme = t.theme, stateMode = t.state, density = t.density;
  const setRole = (v) => setTweak("role", v);
  const setBrand = (v) => setTweak("brand", v);
  const setTheme = (v) => setTweak("theme", v);
  const setStateMode = (v) => setTweak("state", v);
  const setDensity = (v) => setTweak("density", v);

  const [route, setRoute] = useState({ view: "today", params: {} });
  const [history, setHistory] = useState([]);
  const [collapsed, setCollapsed] = useState(false);
  const [cmdOpen, setCmdOpen] = useState(false);
  const [notifs, setNotifs] = useState(RX.NOTIFS);
  const [call, setCall] = useState(null);
  const [toasts, setToasts] = useState([]);
  const [productName, setProductName] = useState(RX.TENANT.name);

  const me = useMemo(() => role === "manager" ? RX.USERS.marcus : role === "admin" ? RX.USERS.dana : RX.USERS.priya, [role]);

  const navigate = useCallback((view, params = {}) => {
    setRoute((r) => { setHistory((h) => [...h, r]); return { view, params }; });
    const body = document.querySelector(".app__body"); if (body) body.scrollTop = 0;
  }, []);
  const back = useCallback(() => setHistory((h) => { if (!h.length) return h; const prev = h[h.length - 1]; setRoute(prev); return h.slice(0, -1); }), []);

  const toast = useCallback((msg, type = "info") => {
    const id = Math.random().toString(36).slice(2);
    setToasts((ts) => [...ts, { id, msg, type }]);
    setTimeout(() => setToasts((ts) => ts.filter((x) => x.id !== id)), 2600);
  }, []);

  const markRead = useCallback((id) => setNotifs((n) => n.map((x) => x.id === id ? { ...x, unread: false } : x)), []);
  const markAllRead = useCallback(() => setNotifs((n) => n.map((x) => ({ ...x, unread: false }))), []);
  const startCall = useCallback((lead) => setCall(lead), []);
  const endCall = useCallback(() => setCall(null), []);

  const inboxUnread = useMemo(() => RX.ALL_LEADS.reduce((s, l) => s + (l.unread || 0), 0), []);

  useEffect(() => { try { window.RelayDS && window.RelayDS.applyBrand(brand); } catch (e) {} }, [brand]);
  useEffect(() => { try { window.RelayDS && window.RelayDS.applyTheme(theme); } catch (e) {} }, [theme]);
  useEffect(() => { document.documentElement.setAttribute("data-density", density); }, [density]);

  useEffect(() => {
    const h = (e) => { if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") { e.preventDefault(); setCmdOpen((v) => !v); } };
    window.addEventListener("keydown", h); return () => window.removeEventListener("keydown", h);
  }, []);

  useEffect(() => { const b = document.getElementById("boot"); if (b) { b.style.opacity = "0"; setTimeout(() => b.remove(), 400); } }, []);

  const ctx = {
    route, navigate, back, history,
    role, setRole, me,
    collapsed, setCollapsed,
    cmdOpen, setCmdOpen,
    notifs, markRead, markAllRead,
    call, startCall, endCall,
    toasts, toast,
    stateMode, setStateMode,
    density, setDensity,
    brand, setBrand, theme, setTheme,
    productName, setProductName,
    inboxUnread,
  };

  return (
    <AppCtx.Provider value={ctx}>
      <div className="app">
        <Sidebar />
        <div className="app__main"><Router /></div>
      </div>
      <CommandPalette />
      <CallBar />
      <Toaster />

      <TweaksPanel title="Tweaks">
        <TweakSection label="Brand (white-label)" />
        <div className="twk-row">
          <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
            {BRAND_PRESETS.map((b) => (
              <button key={b.key} type="button" title={b.key} onClick={() => setBrand(b.key)}
                style={{ width: 30, height: 30, borderRadius: 8, cursor: "pointer", background: b.swatch,
                  border: brand === b.key ? "2px solid #fff" : "2px solid transparent",
                  boxShadow: brand === b.key ? "0 0 0 2px #111" : "0 0 0 1px rgba(0,0,0,.2)" }} />
            ))}
          </div>
        </div>
        <TweakSection label="Appearance" />
        <TweakRadio label="Theme" value={theme} options={[{ value: "light", label: "Light" }, { value: "dark", label: "Dark" }]} onChange={setTheme} />
        <TweakRadio label="Density" value={density} options={[{ value: "comfortable", label: "Comfortable" }, { value: "compact", label: "Compact" }]} onChange={setDensity} />
        <TweakSection label="Role (oversight demo)" />
        <TweakRadio label="View as" value={role} options={[{ value: "associate", label: "Rep" }, { value: "manager", label: "Manager" }, { value: "admin", label: "Admin" }]} onChange={setRole} />
        <TweakSection label="Realistic states" />
        <TweakRadio label="Data state" value={stateMode} options={[{ value: "normal", label: "Populated" }, { value: "empty", label: "Empty" }, { value: "loading", label: "Loading" }, { value: "error", label: "Error" }]} onChange={setStateMode} />
        <div className="twk-row" style={{ fontSize: 11, color: "var(--color-fg-3, #888)", lineHeight: 1.5 }}>
          State affects Today, Leads &amp; the lead conversation. Try “Loading” then open Leads.
        </div>
      </TweaksPanel>
    </AppCtx.Provider>
  );
}

function Router() {
  const app = useApp();
  const v = app.route.view;
  const MAP = {
    today: window.ViewToday, leads: window.ViewLeads, lead: window.ViewLead,
    inbox: window.ViewInbox, pipeline: window.ViewPipeline, outreach: window.ViewOutreach,
    insights: window.ViewInsights, settings: window.ViewSettings, billing: window.ViewBilling,
  };
  const Comp = MAP[v];
  const FULL = { lead: 1, inbox: 1 };
  if (!Comp) return (<><Topbar /><div className="app__body"><div className="page"><Empty icon="hammer" title="Coming together" body={"The “" + v + "” workspace is being built."} /></div></div></>);
  if (FULL[v]) return (<><Topbar /><div className="app__body" style={{ overflow: "hidden" }}><div className="route-enter" style={{ height: "100%" }}><Comp key={JSON.stringify(app.route)} /></div></div></>);
  return (<><Topbar /><div className="app__body"><div className="route-enter"><Comp key={JSON.stringify(app.route)} /></div></div></>);
}

ReactDOM.createRoot(document.getElementById("root")).render(<App />);
