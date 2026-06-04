/* ============================================================
   Relay app — Inbox: cross-lead conversation triage.
   Reuses the conversation event renderers + Composer.
   ============================================================ */

const INBOX_FILTERS = [
  { id: "all", label: "All", icon: "layers" },
  { id: "unread", label: "Unread", icon: "circle-dot" },
  { id: "whatsapp", label: "WhatsApp", icon: "message-circle" },
  { id: "email", label: "Email", icon: "mail" },
  { id: "mine", label: "Mine", icon: "user" },
];

function lastEventPreview(key) {
  const tl = RX.timelineFor(key);
  for (let i = tl.length - 1; i >= 0; i--) {
    const e = tl[i];
    if (e.type === "whatsapp") return { chan: "whatsapp", text: (e.dir === "out" ? "You: " : "") + e.text };
    if (e.type === "email") return { chan: "email", text: e.subject };
    if (e.type === "call") return { chan: "call", text: (e.dir === "out" ? "Outbound call · " : "Inbound call · ") + e.duration };
    if (e.type === "note") return { chan: "note", text: "Note: " + e.text };
  }
  return { chan: "system", text: "No messages yet" };
}

function ViewInbox() {
  const app = useApp();
  const { navigate, me, role, startCall } = app;
  const [filter, setFilter] = useState("all");
  const [q, setQ] = useState("");
  const convos = useMemo(() => {
    return RX.ALL_LEADS
      .filter((l) => role === "associate" ? l.owner === me.id : true)
      .map((l) => ({ lead: l, preview: lastEventPreview(l.key) }))
      .filter(({ lead, preview }) => {
        if (q && !lead.name.toLowerCase().includes(q.toLowerCase()) && !lead.company.toLowerCase().includes(q.toLowerCase())) return false;
        if (filter === "unread") return lead.unread > 0;
        if (filter === "mine") return lead.owner === me.id;
        if (filter === "whatsapp") return preview.chan === "whatsapp";
        if (filter === "email") return preview.chan === "email";
        return true;
      })
      .sort((a, b) => (b.lead.unread > 0 ? 1 : 0) - (a.lead.unread > 0 ? 1 : 0));
  }, [filter, q, me, role]);

  const [activeKey, setActiveKey] = useState(convos[0] ? convos[0].lead.key : null);
  const active = activeKey ? RX.leadByKey(activeKey) : null;
  const totalUnread = RX.ALL_LEADS.reduce((s, l) => s + l.unread, 0);

  return (
    <div className="inbox" data-screen-label="Inbox">
      {/* list */}
      <div className="inbox__list">
        <div style={{ padding: "16px 16px 10px", borderBottom: "1px solid var(--color-divider)", position: "sticky", top: 0, background: "var(--color-surface)", zIndex: 2 }}>
          <div className="spread" style={{ marginBottom: 12 }}>
            <div className="rl-h3" style={{ fontFamily: "var(--font-display)", fontWeight: 800 }}>Inbox</div>
            <span className="rl-badge rl-badge--success">{totalUnread} unread</span>
          </div>
          <div className="rl-inputwrap" style={{ marginBottom: 10 }}>
            <span className="rl-affix"><Icon name="search" size={16} /></span>
            <input className="rl-input rl-input--sm" placeholder="Search conversations" value={q} onChange={(e) => setQ(e.target.value)} />
          </div>
          <div className="rl-segmented" style={{ width: "100%", display: "flex" }}>
            {INBOX_FILTERS.map((f) => <button key={f.id} className={cx("grow", filter === f.id && "is-active")} onClick={() => setFilter(f.id)} title={f.label}><Icon name={f.icon} size={14} /></button>)}
          </div>
        </div>
        {convos.length === 0 ? <Empty icon="inbox" title="Inbox zero" body="You've replied to every lead. Nice." /> :
          convos.map(({ lead, preview }) => (
            <div key={lead.id} className={cx("rl-convo", activeKey === lead.key && "is-active")} onClick={() => setActiveKey(lead.key)}>
              <Avatar name={lead.name} av={"rl-avatar--c" + ((lead.name.length % 5) + 1)} presence={lead.unread > 0 ? "online" : null} />
              <div className="rl-convo__main">
                <div className="rl-convo__row"><span className="rl-convo__name">{lead.name}</span><span className="rl-convo__time">{lead.lastTouch}</span></div>
                <div className="rl-convo__preview"><ChannelPip type={preview.chan} ghost /><span style={{ marginLeft: 2 }}>{preview.text}</span></div>
              </div>
              {lead.unread > 0 && <span className="rl-convo__unread">{lead.unread}</span>}
            </div>
          ))}
      </div>

      {/* thread */}
      {active ? <InboxThread lead={active} key={active.key} /> : <div className="lead__conv" style={{ display: "grid", placeItems: "center" }}><Empty icon="message-square" title="Select a conversation" body="Pick a lead from the list to read and reply." /></div>}
    </div>
  );
}

function InboxThread({ lead }) {
  const app = useApp();
  const [events, setEvents] = useState(() => RX.timelineFor(lead.key));
  const bodyRef = useRef(null);
  useEffect(() => { if (bodyRef.current) bodyRef.current.scrollTop = bodyRef.current.scrollHeight; }, [events]);
  const append = (ev) => setEvents((e) => [...e, ev]);
  return (
    <div className="lead__conv">
      <div className="row spread" style={{ padding: "12px 20px", borderBottom: "1px solid var(--color-border)", background: "var(--color-surface)", flex: "none" }}>
        <div className="row" style={{ gap: 10 }}>
          <Avatar name={lead.name} av="rl-avatar--c1" presence="online" />
          <div>
            <div className="row" style={{ gap: 8 }}><b className="rl-sm">{lead.name}</b><StatusPill status={lead.status} /></div>
            <div className="muted" style={{ fontSize: 12 }}>{lead.title} · {lead.company} · {lead.local} {lead.tz}</div>
          </div>
        </div>
        <div className="row" style={{ gap: 6 }}>
          <button className="rl-btn rl-btn--secondary rl-btn--sm" onClick={() => app.startCall(lead)}><Icon name="phone" size={14} />Call</button>
          <button className="rl-btn rl-btn--primary rl-btn--sm" onClick={() => app.navigate("lead", { key: lead.key })}><Icon name="panel-right-open" size={14} />Open workspace</button>
        </div>
      </div>
      <div className="lead__convbody" ref={bodyRef}>
        {events.map((ev, i) => {
          if (ev.date) return <div className="cdate" key={"d" + i}><span>{ev.date}</span></div>;
          if (ev.type === "call") return <CallCard ev={ev} key={i} />;
          if (ev.type === "email") return <EmailCard ev={ev} key={i} />;
          if (ev.type === "note") return <NoteCard ev={ev} key={i} />;
          if (ev.type === "whatsapp") return <div className="cevent" key={i} style={{ marginBottom: 0 }}><WBubble ev={ev} /></div>;
          if (ev.type === "system") return <SysRow ev={ev} key={i} />;
          return null;
        })}
      </div>
      <Composer lead={lead} onSend={append} />
    </div>
  );
}

window.ViewInbox = ViewInbox;
