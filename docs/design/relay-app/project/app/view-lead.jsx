/* ============================================================
   Relay app — Lead workspace. The hero view: a single
   continuous, multi-channel conversation + context rail.
   ============================================================ */

/* ---------- Call player ---------- */
function CallPlayer({ duration }) {
  const [playing, setPlaying] = useState(false);
  const [pos, setPos] = useState(0.34);
  const bars = useMemo(() => Array.from({ length: 48 }, () => 0.25 + Math.random() * 0.75), []);
  useEffect(() => { if (!playing) return; const t = setInterval(() => setPos((p) => p >= 1 ? (setPlaying(false), 1) : p + 0.012), 90); return () => clearInterval(t); }, [playing]);
  return (
    <div className="rl-player" style={{ boxShadow: "none", border: "1px solid var(--color-border)" }}>
      <button className="rl-player__play" onClick={() => setPlaying((v) => !v)}><Icon name={playing ? "pause" : "play"} size={18} /></button>
      <div className="rl-player__main">
        <div className="rl-wave" onClick={(e) => { const r = e.currentTarget.getBoundingClientRect(); setPos((e.clientX - r.left) / r.width); }}>
          {bars.map((h, i) => <i key={i} className={i / bars.length <= pos ? "is-played" : ""} style={{ height: (h * 100) + "%" }} />)}
        </div>
        <div className="rl-player__time"><span>{fmtPos(pos, duration)}</span><span>{duration}</span></div>
      </div>
      <button className="rl-iconbtn" title="Download"><Icon name="download" size={16} /></button>
    </div>
  );
}
function fmtPos(p, dur) { const [m, s] = dur.split(":").map(Number); const tot = m * 60 + s; const cur = Math.floor(tot * p); return String(Math.floor(cur / 60)).padStart(2, "0") + ":" + String(cur % 60).padStart(2, "0"); }

/* ---------- Conversation events ---------- */
function CallCard({ ev }) {
  const [open, setOpen] = useState(false);
  return (
    <div className="cevent">
      <div className="callcard">
        <div className="callcard__head">
          <span className="iccircle" style={{ background: "color-mix(in oklch, var(--channel-call) 16%, transparent)", color: "var(--channel-call)" }}><Icon name={ev.dir === "out" ? "phone-outgoing" : "phone-incoming"} size={18} /></span>
          <div className="grow">
            <div className="row" style={{ gap: 8 }}><b className="rl-sm">{ev.dir === "out" ? "Outbound call" : "Inbound call"}</b><span className="rl-badge rl-badge--success">{ev.outcome}</span></div>
            <div className="muted" style={{ fontSize: 12 }}>{ev.time} · {ev.duration} · auto-recorded</div>
          </div>
          <button className="rl-btn rl-btn--ghost rl-btn--sm" onClick={() => setOpen((v) => !v)}><Icon name="file-text" size={14} />Transcript<Icon name={open ? "chevron-up" : "chevron-down"} size={14} /></button>
        </div>
        <div style={{ padding: "12px 16px 4px" }}><CallPlayer duration={ev.duration} /></div>
        {ev.summary && <div className="aisum">
          <div className="aisum__h"><Icon name="sparkles" size={13} />AI call summary</div>
          <div className="rl-sm" style={{ lineHeight: 1.55 }}>{ev.summary}</div>
          {ev.tags && <div className="tagrow" style={{ marginTop: 10 }}>{ev.tags.map((t) => <span className="rl-badge rl-badge--primary" key={t}>{t}</span>)}</div>}
        </div>}
        {open && <div style={{ padding: "4px 16px 16px" }}>
          <div className="rl-transcript">
            {ev.transcript.map((tx, i) => (
              <div className="rl-tx" key={i}>
                <span className="rl-tx__time">{tx.t}</span>
                <div>
                  <div className={cx("rl-tx__who", tx.who === "rep" ? "rl-tx__who--rep" : "rl-tx__who--lead")}>{tx.name}</div>
                  <div className="rl-tx__text">{tx.mark ? <mark>{tx.text}</mark> : tx.text}</div>
                </div>
              </div>
            ))}
          </div>
        </div>}
      </div>
    </div>
  );
}

function EmailCard({ ev }) {
  const [open, setOpen] = useState(true);
  return (
    <div className="cevent">
      <div className="emailcard">
        <div className="emailcard__head" style={{ borderBottom: open ? "1px solid var(--color-divider)" : "none" }}>
          <span className="iccircle" style={{ background: "color-mix(in oklch, var(--channel-email) 16%, transparent)", color: "var(--channel-email)" }}><Icon name="mail" size={18} /></span>
          <div className="grow" style={{ minWidth: 0 }}>
            <div className="rl-sm" style={{ fontWeight: 600, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{ev.subject}</div>
            <div className="muted" style={{ fontSize: 12 }}>{ev.dir === "out" ? "You → " + ev.to : ev.from + " → you"} · {ev.time}</div>
          </div>
          <span className="rl-badge">{ev.dir === "out" ? "Sent" : "Received"}</span>
          <button className="rl-iconbtn rl-iconbtn--sm" onClick={() => setOpen((v) => !v)}><Icon name={open ? "chevron-up" : "chevron-down"} size={16} /></button>
        </div>
        {open && <div style={{ padding: "12px 16px", fontSize: "var(--text-sm)", lineHeight: 1.6, color: "var(--color-fg-2)", whiteSpace: "pre-wrap" }}>{ev.body}</div>}
        {open && <div style={{ padding: "0 16px 12px" }} className="row"><button className="rl-btn rl-btn--secondary rl-btn--sm"><Icon name="reply" size={14} />Reply</button><button className="rl-btn rl-btn--ghost rl-btn--sm"><Icon name="forward" size={14} />Forward</button></div>}
      </div>
    </div>
  );
}

function NoteCard({ ev }) {
  return (
    <div className="cevent">
      <div className="notecard">
        <div className="notecard__head">
          <span className="iccircle" style={{ width: 30, height: 30, background: "var(--color-warning-subtle)", color: "var(--color-warning-text)" }}><Icon name="sticky-note" size={16} /></span>
          <div className="grow"><b className="rl-sm">Internal note</b><div className="muted" style={{ fontSize: 12 }}>{ev.author} · {ev.time}</div></div>
          <span className="rl-badge rl-badge--warning">Private</span>
        </div>
        <div style={{ padding: "2px 16px 14px 16px", fontSize: "var(--text-sm)", lineHeight: 1.55 }}>{ev.text}</div>
      </div>
    </div>
  );
}

function WBubble({ ev }) {
  const out = ev.dir === "out";
  return (
    <div className={cx("rl-msgrow", out && "rl-msgrow--out")} style={{ marginBottom: 8 }}>
      <div className={cx("rl-bubble", out ? "rl-bubble--out" : "rl-bubble--in")}>
        {ev.text}
        <div className="rl-bubble__meta">{ev.time}{out && <Icon name="check-check" size={14} className={ev.status === "read" ? "rl-read" : ""} style={ev.status === "read" ? { color: "oklch(0.82 0.10 200)" } : {}} />}</div>
      </div>
    </div>
  );
}

function SysRow({ ev }) {
  return <div style={{ textAlign: "center", margin: "10px 0" }}><span className="rl-sysmsg"><Icon name={ev.icon || "activity"} size={12} style={{ marginRight: 4, verticalAlign: "-2px" }} />{ev.text} · {ev.time}</span></div>;
}

/* ---------- Composer ---------- */
const COMPOSE_TABS = [
  { id: "whatsapp", label: "WhatsApp", icon: "message-circle", color: "var(--channel-whatsapp)" },
  { id: "email", label: "Email", icon: "mail", color: "var(--channel-email)" },
  { id: "note", label: "Note", icon: "sticky-note", color: "var(--color-warning)" },
  { id: "call", label: "Log call", icon: "phone", color: "var(--channel-call)" },
];
function Composer({ onSend, lead }) {
  const [tab, setTab] = useState("whatsapp");
  const [text, setText] = useState("");
  const [subject, setSubject] = useState("");
  const app = useApp();
  const send = () => {
    if (tab === "call") { onSend({ type: "call", dir: "out", time: "now", duration: "2:14", outcome: "Logged manually", recording: false, summary: null, transcript: [] }); app.toast("Call logged", "success"); return; }
    if (!text.trim()) return;
    if (tab === "whatsapp") onSend({ type: "whatsapp", dir: "out", time: "now", status: "sent", text });
    else if (tab === "email") onSend({ type: "email", dir: "out", time: "now", subject: subject || "(no subject)", to: lead.name, from: "You", body: text });
    else onSend({ type: "note", author: "You", time: "now", text });
    setText(""); setSubject("");
    app.toast(tab === "whatsapp" ? "WhatsApp sent" : tab === "email" ? "Email sent" : "Note saved", "success");
  };
  const cur = COMPOSE_TABS.find((t) => t.id === tab);
  return (
    <div className="lead__compose">
      <div className="composer__tabs">
        {COMPOSE_TABS.map((t) => (
          <button key={t.id} className={cx("composer__tab", tab === t.id && "is-active")} onClick={() => setTab(t.id)}>
            <span style={{ color: tab === t.id ? t.color : "currentColor" }}><Icon name={t.icon} size={15} /></span>{t.label}
          </button>
        ))}
      </div>
      {tab === "call" ? (
        <div className="composer__box" style={{ padding: 12 }}>
          <div className="row" style={{ gap: 10, flexWrap: "wrap" }}>
            <select className="rl-select rl-input--sm" style={{ width: 170 }}><option>Connected · qualified</option><option>Left voicemail</option><option>No answer</option><option>Wrong number</option></select>
            <input className="rl-input rl-input--sm" style={{ width: 110 }} placeholder="Duration 2:14" />
            <input className="rl-input rl-input--sm grow" placeholder="Quick note about the call…" />
            <button className="rl-btn rl-btn--primary rl-btn--sm" onClick={send}><Icon name="check" size={14} />Save call</button>
          </div>
        </div>
      ) : (
        <div className="composer__box">
          {tab === "email" && <input value={subject} onChange={(e) => setSubject(e.target.value)} placeholder="Subject" style={{ width: "100%", border: "none", borderBottom: "1px solid var(--color-divider)", padding: "10px 14px", outline: "none", background: "none", fontSize: "var(--text-sm)", fontWeight: 600, fontFamily: "var(--font-sans)", color: "var(--color-fg)" }} />}
          <textarea className="composer__input" rows={tab === "email" ? 3 : 1} value={text} onChange={(e) => setText(e.target.value)}
            onKeyDown={(e) => { if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) send(); }}
            placeholder={tab === "whatsapp" ? "Message " + lead.name.split(" ")[0] + " on WhatsApp…" : tab === "email" ? "Write your email…" : "Add an internal note (only your team sees this)…"} />
          <div className="composer__bar">
            <button className="rl-iconbtn rl-iconbtn--sm" title="Template"><Icon name="layout-template" size={16} /></button>
            <button className="rl-iconbtn rl-iconbtn--sm" title="Attach"><Icon name="paperclip" size={16} /></button>
            <button className="rl-iconbtn rl-iconbtn--sm" title="Emoji"><Icon name="smile" size={16} /></button>
            {tab === "whatsapp" && <span className="rl-badge rl-badge--success" style={{ marginLeft: 4 }}><Icon name="circle-check" size={11} />Session open</span>}
            <div className="grow" />
            <span className="muted" style={{ fontSize: 11, marginRight: 4 }}>⌘↵ to send</span>
            <button className="rl-btn rl-btn--primary rl-btn--sm" onClick={send} style={tab !== "whatsapp" ? {} : { background: "var(--channel-whatsapp)" }}>
              <Icon name="send-horizontal" size={14} />{tab === "note" ? "Save note" : "Send"}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

/* ---------- Context rail ---------- */
function LeadRail({ lead, onMoney }) {
  const app = useApp();
  const { startCall, toast, navigate } = app;
  const owner = lead.owner ? RX.USERS[lead.owner] : null;
  const deals = RX.DEALS.filter((d) => d.leadKey === lead.key);
  const tasks = RX.TASKS.filter((t) => t.leadKey === lead.key && !t.done);
  return (
    <div className="lead__rail">
      {/* identity */}
      <div className="railsect" style={{ paddingTop: 18 }}>
        <button className="rl-btn rl-btn--ghost rl-btn--sm" style={{ marginBottom: 12, marginLeft: -6 }} onClick={() => navigate("leads")}><Icon name="arrow-left" size={15} />All leads</button>
        <div className="row" style={{ gap: 12, marginBottom: 12 }}>
          <Avatar name={lead.name} av="rl-avatar--c1" size="xl" />
          <div style={{ minWidth: 0 }}>
            <div className="rl-h4" style={{ lineHeight: 1.2 }}>{lead.name}</div>
            <div className="muted rl-sm">{lead.title}</div>
            <div className="rl-sm" style={{ fontWeight: 600 }}>{lead.company}</div>
          </div>
        </div>
        <div className="row" style={{ gap: 8, marginBottom: 12, flexWrap: "wrap" }}>
          <StatusPill status={lead.status} />
          <span className="row" style={{ gap: 6 }}><span className="muted rl-sm">Score</span><Score value={lead.score} /></span>
        </div>
        <div className="row" style={{ gap: 6 }}>
          <button className="rl-btn rl-btn--primary rl-btn--sm grow" onClick={() => startCall(lead)}><Icon name="phone" size={14} />Call</button>
          {lead.whatsapp && <button className="rl-iconbtn rl-iconbtn--bordered" title="WhatsApp" onClick={() => toast("Jump to WhatsApp composer", "info")}><Icon name="message-circle" size={16} /></button>}
          <button className="rl-iconbtn rl-iconbtn--bordered" title="Email"><Icon name="mail" size={16} /></button>
          {lead.linkedin && <button className="rl-iconbtn rl-iconbtn--bordered" title="LinkedIn"><Icon name="linkedin" size={16} /></button>}
          <Dropdown align="right" trigger={(o, t) => <button className="rl-iconbtn rl-iconbtn--bordered" onClick={t}><Icon name="more-horizontal" size={16} /></button>}>
            <div className="rl-menuitem"><Icon name="user-check" />Reassign</div>
            <div className="rl-menuitem"><Icon name="tag" />Change status</div>
            <div className="rl-menuitem"><Icon name="calendar-plus" />Schedule follow-up</div>
            <div className="rl-menu__sep" />
            <div className="rl-menuitem is-danger"><Icon name="archive" />Archive lead</div>
          </Dropdown>
        </div>
      </div>

      {/* AI best time */}
      <div className="railsect">
        <div className="railsect__h"><span><Icon name="sparkles" size={12} style={{ verticalAlign: "-2px", marginRight: 4 }} />Best time to reach</span></div>
        <div style={{ background: "var(--color-primary-subtle)", border: "1px solid var(--color-primary-border)", borderRadius: "var(--radius-md)", padding: 12 }}>
          <div className="spread"><div><div className="rl-h4 mono">{lead.local}</div><div className="muted" style={{ fontSize: 12 }}>{lead.city} · {lead.tz}</div></div><span className="iccircle" style={{ background: "var(--color-surface)", color: "var(--color-primary-text)" }}><Icon name="clock" size={18} /></span></div>
          <div className="hr" style={{ margin: "10px 0" }} />
          <div className="row" style={{ gap: 7, fontSize: 13 }}><Icon name="phone-call" size={14} style={{ color: "var(--color-primary-text)" }} /><span><b>Prefers:</b> {lead.pref}</span></div>
        </div>
      </div>

      {/* facts */}
      <div className="railsect">
        <div className="railsect__h">Details</div>
        <dl style={{ margin: 0 }}>
          <div className="kvline"><dt>Lead ID</dt><dd className="mono">{lead.id}</dd></div>
          <div className="kvline"><dt>Source</dt><dd><SourceMini source={lead.source} /></dd></div>
          <div className="kvline"><dt>Owner</dt><dd>{owner ? <span className="row" style={{ gap: 6, justifyContent: "flex-end" }}><Avatar user={owner} size="xs" />{owner.first}</span> : "Unassigned"}</dd></div>
          <div className="kvline"><dt>Potential value</dt><dd className="mono">{RX.money(lead.value)}</dd></div>
          <div className="kvline"><dt>Phone</dt><dd className="mono">{lead.phone}</dd></div>
          <div className="kvline"><dt>Email</dt><dd style={{ fontWeight: 500, fontSize: 12 }}>{lead.email}</dd></div>
          <div className="kvline"><dt>Last touch</dt><dd>{lead.lastTouch}</dd></div>
        </dl>
        {lead.tags.length > 0 && <div className="tagrow" style={{ marginTop: 12 }}>{lead.tags.map((t) => <span className="rl-tag" key={t}><i className="rl-tag-dot" style={{ background: "var(--cat-5)" }} />{t}</span>)}</div>}
      </div>

      {/* money actions */}
      <div className="railsect">
        <div className="railsect__h">Money actions</div>
        <div className="col" style={{ gap: 6 }}>
          <button className="rl-btn rl-btn--secondary rl-btn--block" style={{ justifyContent: "flex-start" }} onClick={() => onMoney("estimate")}><Icon name="calculator" size={15} />Cost estimate <span className="grow" /><Icon name="chevron-right" size={14} /></button>
          <button className="rl-btn rl-btn--secondary rl-btn--block" style={{ justifyContent: "flex-start" }} onClick={() => onMoney("proposal")}><Icon name="file-text" size={15} />Odoo proposal <span className="grow" /><Icon name="chevron-right" size={14} /></button>
          <button className="rl-btn rl-btn--secondary rl-btn--block" style={{ justifyContent: "flex-start" }} onClick={() => onMoney("invoice")}><Icon name="receipt" size={15} />Create invoice <span className="grow" /><Icon name="chevron-right" size={14} /></button>
        </div>
      </div>

      {/* linked deals */}
      {deals.length > 0 && <div className="railsect">
        <div className="railsect__h"><span>Deals</span><a className="rl-sm clickable" style={{ color: "var(--color-primary-text)" }} onClick={() => navigate("pipeline")}>Board</a></div>
        {deals.map((d) => { const st = RX.STAGES.find((s) => s.id === d.stage); return (
          <div key={d.id} className="clickable" onClick={() => navigate("pipeline", { deal: d.id })} style={{ border: "1px solid var(--color-border)", borderRadius: "var(--radius-md)", padding: 10, marginBottom: 8 }}>
            <div className="spread"><b className="rl-sm">{d.title}</b></div>
            <div className="row spread" style={{ marginTop: 6 }}><span className="rl-pill" style={{ borderColor: "var(--color-border)" }}><i className="rl-dot" style={{ background: st.color }} />{st.name}</span><span className="mono" style={{ fontWeight: 700 }}>{RX.money(d.value)}</span></div>
          </div>
        ); })}
      </div>}

      {/* tasks */}
      <div className="railsect">
        <div className="railsect__h"><span>Open follow-ups</span><span className="rl-badge">{tasks.length}</span></div>
        {tasks.length === 0 ? <div className="muted rl-sm">No open tasks.</div> : tasks.map((t) => (
          <div key={t.id} className="row" style={{ gap: 8, padding: "6px 0" }}>
            <span style={{ width: 7, height: 7, borderRadius: 9, background: PRIO[t.priority].c, flex: "none" }} />
            <span className="rl-sm grow">{t.title}</span>
            <span className="muted" style={{ fontSize: 11 }}>{t.due === "overdue" ? "Overdue" : t.due}</span>
          </div>
        ))}
        <button className="rl-btn rl-btn--ghost rl-btn--sm" style={{ marginTop: 6, marginLeft: -6 }}><Icon name="plus" size={14} />Add follow-up</button>
      </div>

      {/* documents */}
      <div className="railsect">
        <div className="railsect__h"><span>Documents</span><button className="rl-iconbtn rl-iconbtn--sm"><Icon name="upload" size={14} /></button></div>
        {lead.docs.length === 0 ? <div className="muted rl-sm">No documents yet.</div> : lead.docs.map((d) => (
          <div key={d.name} className="row" style={{ gap: 10, padding: "7px 0" }}>
            <span className="iccircle" style={{ width: 30, height: 30, background: "var(--color-surface-2)", color: d.kind === "pdf" ? "var(--color-danger)" : "var(--channel-call)" }}><Icon name={d.kind === "pdf" ? "file-text" : "file"} size={15} /></span>
            <div className="grow" style={{ minWidth: 0 }}><div className="rl-sm" style={{ fontWeight: 600, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{d.name}</div><div className="muted" style={{ fontSize: 11 }}>{d.size}</div></div>
            <button className="rl-iconbtn rl-iconbtn--sm"><Icon name="download" size={15} /></button>
          </div>
        ))}
      </div>

      {/* ad attribution */}
      <div className="railsect">
        <div className="railsect__h">Ad attribution</div>
        <dl style={{ margin: 0 }}>
          <div className="kvline"><dt>Campaign</dt><dd style={{ fontSize: 12 }}>{lead.ad.campaign}</dd></div>
          <div className="kvline"><dt>Ad set</dt><dd style={{ fontSize: 12 }}>{lead.ad.adset}</dd></div>
          <div className="kvline"><dt>Keyword</dt><dd style={{ fontSize: 12 }}>{lead.ad.keyword}</dd></div>
          <div className="kvline"><dt>UTM</dt><dd className="mono" style={{ fontSize: 11 }}>{lead.ad.utm}</dd></div>
        </dl>
      </div>
    </div>
  );
}

/* ---------- The workspace ---------- */
const FILTERS = [
  { id: "all", label: "All", icon: "layers" },
  { id: "whatsapp", label: "WhatsApp", icon: "message-circle" },
  { id: "call", label: "Calls", icon: "phone" },
  { id: "email", label: "Email", icon: "mail" },
  { id: "note", label: "Notes", icon: "sticky-note" },
];
function ViewLead() {
  const app = useApp();
  const key = app.route.params.key || "maya";
  const lead = RX.leadByKey(key) || RX.LEADS[0];
  const [events, setEvents] = useState(() => RX.timelineFor(key));
  const [filter, setFilter] = useState("all");
  const [money, setMoney] = useState(null);
  const bodyRef = useRef(null);
  useEffect(() => { setEvents(RX.timelineFor(key)); }, [key]);
  useEffect(() => { if (bodyRef.current) bodyRef.current.scrollTop = bodyRef.current.scrollHeight; }, [events]);

  const append = (ev) => setEvents((e) => [...e, ev]);
  const visible = events.filter((e) => e.date || filter === "all" || e.type === filter || (filter === "whatsapp" && e.type === "whatsapp"));

  const MoneyModal = money === "estimate" ? window.EstimatorModal : money === "proposal" ? window.ProposalModal : money === "invoice" ? window.InvoiceModal : null;

  return (
    <div className="lead" data-screen-label={"Lead · " + lead.name}>
      <LeadRail lead={lead} onMoney={setMoney} />
      <div className="lead__conv">
        {/* conversation header */}
        <div className="row spread" style={{ padding: "12px 20px", borderBottom: "1px solid var(--color-border)", background: "var(--color-surface)", flex: "none" }}>
          <div className="row" style={{ gap: 10 }}>
            <Avatar name={lead.name} av="rl-avatar--c1" presence="online" />
            <div>
              <div className="row" style={{ gap: 8 }}><b className="rl-sm">{lead.name}</b><span className="rl-badge rl-badge--success" style={{ height: 18 }}><Icon name="circle" size={8} />Active now</span></div>
              <div className="muted" style={{ fontSize: 12 }}>Continuous conversation · all channels in one thread</div>
            </div>
          </div>
          <div className="row" style={{ gap: 4 }}>
            <div className="rl-segmented">
              {FILTERS.map((f) => <button key={f.id} className={filter === f.id ? "is-active" : ""} onClick={() => setFilter(f.id)} title={f.label}><Icon name={f.icon} size={14} /></button>)}
            </div>
            <button className="rl-iconbtn rl-iconbtn--bordered" style={{ marginLeft: 6 }} title="Search in conversation"><Icon name="search" size={16} /></button>
          </div>
        </div>

        {/* conversation body */}
        <div className="lead__convbody" ref={bodyRef}>
          {app.stateMode === "empty" ? <Empty icon="message-square" title="No conversation yet" body={"You haven't reached out to " + lead.name.split(" ")[0] + " yet. Start with a call or a WhatsApp."} action={<button className="rl-btn rl-btn--primary rl-btn--sm" onClick={() => app.startCall(lead)}><Icon name="phone" size={14} />Call now</button>} />
            : visible.map((ev, i) => {
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

      {MoneyModal && <MoneyModal lead={lead} onClose={() => setMoney(null)} />}
    </div>
  );
}

window.ViewLead = ViewLead;
