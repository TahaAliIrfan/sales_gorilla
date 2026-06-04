/* ============================================================
   Relay app — Pipeline: draggable kanban, deal drawer
   (audit trail, recordings, assign, won/lost), stage config.
   ============================================================ */

const AUDIT = {
  "DEAL-310": [
    { icon: "flag", text: "Deal created from lead Maya Brennan", who: "Priya Shah", time: "Jun 2 · 09:14", dot: "brand" },
    { icon: "phone", text: "Discovery call logged · 6:48", who: "Priya Shah", time: "Jun 2 · 11:12", dot: "" },
    { icon: "arrow-right", text: "Moved Qualifying → Proposal sent", who: "Priya Shah", time: "Jun 3 · 08:40", dot: "" },
    { icon: "file-text", text: "Proposal PDF generated & sent", who: "Priya Shah", time: "Jun 3 · 08:42", dot: "" },
    { icon: "message-circle", text: "Lead replied on WhatsApp", who: "Maya Brennan", time: "Today · 10:38", dot: "whatsapp" },
  ],
};
function auditFor(id) { return AUDIT[id] || [
  { icon: "flag", text: "Deal created", who: "System", time: "—", dot: "brand" },
  { icon: "arrow-right", text: "Stage updated", who: "Owner", time: "—", dot: "" },
]; }

function DealCard({ deal, onOpen, onDragStart, dragging }) {
  const lead = RX.leadByKey(deal.leadKey);
  const owner = RX.USERS[deal.owner];
  return (
    <div className={cx("rl-dealcard", dragging && "is-dragging")} draggable onDragStart={(e) => onDragStart(e, deal)} onClick={() => onOpen(deal)}>
      <div className="rl-dealcard__top">
        <div className="rl-dealcard__title">{deal.title}</div>
      </div>
      <div className="rl-dealcard__value">{RX.money(deal.value)}</div>
      <div className="row" style={{ gap: 6, marginTop: 8, flexWrap: "wrap" }}>
        <span className="rl-badge"><Icon name="building-2" size={11} />{deal.company}</span>
        <span className="rl-badge" style={{ background: "transparent", color: deal.prob >= 70 ? "var(--color-success-text)" : "var(--color-fg-3)" }}><Icon name="percent" size={11} />{deal.prob}%</span>
      </div>
      <div className="rl-dealcard__foot">
        <div className="row" style={{ gap: 6 }}><Avatar user={owner} size="xs" /><span className="muted" style={{ fontSize: 11 }}>{deal.age}d old</span></div>
        <span className="muted" style={{ fontSize: 11 }}><Icon name="arrow-right-circle" size={12} style={{ verticalAlign: "-2px", marginRight: 3 }} />{deal.next}</span>
      </div>
    </div>
  );
}

function ViewPipeline() {
  const app = useApp();
  const { navigate, toast, role, me } = app;
  const [stages, setStages] = useState(RX.STAGES);
  const [deals, setDeals] = useState(RX.DEALS);
  const [drag, setDrag] = useState(null);
  const [over, setOver] = useState(null);
  const [drawer, setDrawer] = useState(app.route.params.deal ? RX.DEALS.find((d) => d.id === app.route.params.deal) : null);
  const [cfg, setCfg] = useState(false);
  const [ownerFilter, setOwnerFilter] = useState(role === "associate" ? me.id : "");

  const shown = deals.filter((d) => !ownerFilter || d.owner === ownerFilter);
  const onDragStart = (e, deal) => { setDrag(deal); e.dataTransfer.effectAllowed = "move"; };
  const onDrop = (stageId) => { if (drag && drag.stage !== stageId) { setDeals((ds) => ds.map((d) => d.id === drag.id ? { ...d, stage: stageId, prob: stageId === "won" ? 100 : stageId === "lost" ? 0 : d.prob } : d)); const st = stages.find((s) => s.id === stageId); toast(stageId === "won" ? "🎉 Deal won · " + RX.money(drag.value) : "Moved to " + st.name, stageId === "lost" ? "info" : "success"); } setDrag(null); setOver(null); };

  const totalOpen = shown.filter((d) => d.stage !== "won" && d.stage !== "lost").reduce((s, d) => s + d.value, 0);
  const weighted = shown.filter((d) => d.stage !== "won" && d.stage !== "lost").reduce((s, d) => s + d.value * d.prob / 100, 0);
  const wonVal = shown.filter((d) => d.stage === "won").reduce((s, d) => s + d.value, 0);

  return (
    <div className="page--flush" style={{ height: "calc(100vh - var(--topbar-h))", display: "flex", flexDirection: "column" }}>
      <div className="page" style={{ paddingBottom: 0, maxWidth: "none" }}>
        <div className="pagehead" style={{ marginBottom: "var(--space-4)" }}>
          <div><div className="pagehead__title">Pipeline</div><div className="pagehead__sub">Drag deals across stages · {shown.length} deals · {RX.money(totalOpen)} open</div></div>
          <div className="pagehead__actions">
            {role !== "associate" && <select className="rl-select" style={{ width: 160 }} value={ownerFilter} onChange={(e) => setOwnerFilter(e.target.value)}><option value="">All owners</option><option value={me.id}>Owned by me</option>{RX.REP_IDS.map((id) => <option key={id} value={id}>{RX.USERS[id].name}</option>)}</select>}
            <button className="rl-btn rl-btn--secondary" onClick={() => setCfg(true)}><Icon name="sliders-horizontal" size={15} />Configure stages</button>
            <button className="rl-btn rl-btn--primary"><Icon name="plus" size={15} />Create deal</button>
          </div>
        </div>
        <div className="row" style={{ gap: 20, marginBottom: 4 }}>
          <div><span className="rl-eyebrow">Open pipeline</span><div style={{ fontFamily: "var(--font-display)", fontWeight: 800, fontSize: 22 }}>{RX.money(totalOpen)}</div></div>
          <div style={{ width: 1, background: "var(--color-border)" }} />
          <div><span className="rl-eyebrow">Weighted</span><div style={{ fontFamily: "var(--font-display)", fontWeight: 800, fontSize: 22 }}>{RX.money(Math.round(weighted))}</div></div>
          <div style={{ width: 1, background: "var(--color-border)" }} />
          <div><span className="rl-eyebrow">Won this quarter</span><div style={{ fontFamily: "var(--font-display)", fontWeight: 800, fontSize: 22, color: "var(--color-success-text)" }}>{RX.money(wonVal)}</div></div>
        </div>
      </div>

      <div className="boardwrap grow">
        <div className="rl-board" style={{ height: "100%" }}>
          {stages.map((st) => {
            const list = shown.filter((d) => d.stage === st.id);
            const sum = list.reduce((s, d) => s + d.value, 0);
            return (
              <div key={st.id} className="rl-col" style={{ outline: over === st.id ? "2px solid var(--color-primary)" : "none", outlineOffset: -1 }}
                onDragOver={(e) => { e.preventDefault(); setOver(st.id); }} onDragLeave={() => setOver((o) => o === st.id ? null : o)} onDrop={() => onDrop(st.id)}>
                <div className="rl-col__head">
                  <span className="rl-dotmark" style={{ background: st.color }} />
                  <b>{st.name}</b>
                  <span className="rl-count">{list.length}</span>
                </div>
                <div style={{ padding: "6px 14px", borderBottom: "1px solid var(--color-divider)" }}><span className="mono muted" style={{ fontSize: 12, fontWeight: 600 }}>{RX.money(sum)}</span></div>
                <div className="rl-col__body" style={{ minHeight: 120 }}>
                  {list.map((d) => <DealCard key={d.id} deal={d} dragging={drag && drag.id === d.id} onOpen={setDrawer} onDragStart={onDragStart} />)}
                  {list.length === 0 && <div style={{ textAlign: "center", padding: 16, color: "var(--color-fg-4)", fontSize: 12 }}>{over === st.id ? "Drop here" : "No deals"}</div>}
                  {st.id !== "won" && st.id !== "lost" && <button className="rl-col--add"><Icon name="plus" size={15} />Add deal</button>}
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {drawer && <DealDrawer deal={deals.find((d) => d.id === drawer.id) || drawer} stages={stages} onClose={() => setDrawer(null)}
        onStage={(sid) => { setDeals((ds) => ds.map((d) => d.id === drawer.id ? { ...d, stage: sid, prob: sid === "won" ? 100 : sid === "lost" ? 0 : d.prob } : d)); toast(sid === "won" ? "🎉 Deal won" : sid === "lost" ? "Deal marked lost" : "Stage updated", sid === "lost" ? "info" : "success"); }} />}
      {cfg && <StageConfig stages={stages} setStages={setStages} onClose={() => setCfg(false)} />}
    </div>
  );
}

/* ---------- Deal drawer ---------- */
function DealDrawer({ deal, stages, onClose, onStage }) {
  const app = useApp();
  const lead = RX.leadByKey(deal.leadKey);
  const owner = RX.USERS[deal.owner];
  const st = stages.find((s) => s.id === deal.stage);
  return (
    <Drawer onClose={onClose} wide>
      <div className="drawer__head">
        <span className="iccircle" style={{ background: "var(--color-primary-subtle)", color: "var(--color-primary-text)" }}><Icon name="circle-dollar-sign" size={18} /></span>
        <div className="grow"><div className="rl-h4" style={{ lineHeight: 1.2 }}>{deal.title}</div><div className="muted rl-sm">{deal.company} · {deal.id}</div></div>
        <button className="rl-iconbtn" onClick={onClose}><Icon name="x" size={18} /></button>
      </div>
      <div className="drawer__body">
        <div className="row" style={{ gap: 16, marginBottom: 18, flexWrap: "wrap" }}>
          <div><span className="rl-eyebrow">Value</span><div style={{ fontFamily: "var(--font-display)", fontWeight: 800, fontSize: 26 }}>{RX.money(deal.value)}</div></div>
          <div><span className="rl-eyebrow">Stage</span><div style={{ marginTop: 4 }}><span className="rl-pill"><i className="rl-dot" style={{ background: st.color }} />{st.name}</span></div></div>
          <div><span className="rl-eyebrow">Probability</span><div style={{ fontFamily: "var(--font-display)", fontWeight: 800, fontSize: 26 }}>{deal.prob}%</div></div>
        </div>

        {/* stage mover */}
        <div className="rl-eyebrow" style={{ marginBottom: 8 }}>Move stage</div>
        <div className="row" style={{ gap: 6, flexWrap: "wrap", marginBottom: 18 }}>
          {stages.map((s) => <button key={s.id} className={cx("rl-chip", deal.stage === s.id && "is-active")} onClick={() => onStage(s.id)} style={{ height: 32 }}><i style={{ width: 8, height: 8, borderRadius: 2, background: s.color }} />{s.name}</button>)}
        </div>

        {/* owner / next */}
        <div className="sect" style={{ marginBottom: 16 }}><div className="sect__body" style={{ padding: 16 }}>
          <div className="kvline"><dt>Owner</dt><dd><Dropdown align="right" trigger={(o, t) => <button className="rl-chip" onClick={t} style={{ height: 30 }}><Avatar user={owner} size="xs" />{owner.name}<Icon name="chevron-down" size={13} /></button>}>
            <div className="rl-menu__label">Assign to</div>
            {RX.REP_IDS.map((id) => <div key={id} className="rl-menuitem" onClick={() => app.toast("Reassigned to " + RX.USERS[id].name, "success")}><Avatar user={RX.USERS[id]} size="xs" />{RX.USERS[id].name}</div>)}
          </Dropdown></dd></div>
          <div className="kvline"><dt>Linked lead</dt><dd><a className="clickable" style={{ color: "var(--color-primary-text)" }} onClick={() => { onClose(); app.navigate("lead", { key: deal.leadKey }); }}>{lead ? lead.name : "—"}</a></dd></div>
          <div className="kvline"><dt>Next step</dt><dd>{deal.next}</dd></div>
          <div className="kvline"><dt>Age</dt><dd>{deal.age} days</dd></div>
        </div></div>

        {/* linked recording */}
        {lead && RX.timelineFor(deal.leadKey).some((e) => e.type === "call") && <div style={{ marginBottom: 16 }}>
          <div className="rl-eyebrow" style={{ marginBottom: 8 }}>Linked recordings</div>
          <CallPlayer duration={"6:48"} />
        </div>}

        {/* audit trail */}
        <div className="rl-eyebrow" style={{ marginBottom: 12 }}>Audit trail</div>
        <div className="rl-timeline">
          {auditFor(deal.id).map((a, i) => (
            <div className="rl-tl-item" key={i}>
              <div className={cx("rl-tl-dot", a.dot && "rl-tl-dot--" + a.dot)}><Icon name={a.icon} size={14} /></div>
              <div className="rl-tl-body"><div className="rl-tl-title"><b>{a.text}</b></div><div className="rl-tl-time">{a.who} · {a.time}</div></div>
            </div>
          ))}
        </div>
      </div>
      <div className="drawer__foot" style={{ justifyContent: "space-between" }}>
        <button className="rl-btn rl-btn--destructive-ghost" onClick={() => onStage("lost")}><Icon name="x-circle" size={15} />Mark lost</button>
        <div className="row" style={{ gap: 8 }}>
          <button className="rl-btn rl-btn--secondary" onClick={() => { onClose(); app.navigate("lead", { key: deal.leadKey }); }}><Icon name="messages-square" size={15} />Open conversation</button>
          <button className="rl-btn rl-btn--primary" onClick={() => onStage("won")} style={{ background: "var(--color-success)", borderColor: "var(--color-success)" }}><Icon name="trophy" size={15} />Mark won</button>
        </div>
      </div>
    </Drawer>
  );
}

/* ---------- Stage configuration ---------- */
function StageConfig({ stages, setStages, onClose }) {
  const [local, setLocal] = useState(stages);
  const PALETTE = ["var(--cat-1)", "var(--cat-3)", "var(--cat-5)", "var(--cat-6)", "var(--color-success)", "var(--color-danger)"];
  return (
    <Modal onClose={onClose} width={520}>
      <div className="rl-modal__head">
        <div className="rl-modal__icon rl-modal__icon--brand"><Icon name="sliders-horizontal" size={20} /></div>
        <div><div className="rl-modal__title">Configure stages</div><div className="muted rl-sm" style={{ marginTop: 2 }}>Rename, recolor, reorder or add pipeline stages.</div></div>
        <button className="rl-iconbtn rl-modal__close" onClick={onClose}><Icon name="x" size={18} /></button>
      </div>
      <div className="rl-modal__body">
        <div className="col" style={{ gap: 8 }}>
          {local.map((s, i) => (
            <div className="row" key={s.id} style={{ gap: 8, padding: "8px 10px", border: "1px solid var(--color-border)", borderRadius: "var(--radius-md)" }}>
              <Icon name="grip-vertical" size={16} style={{ color: "var(--color-fg-4)" }} />
              <Dropdown trigger={(o, t) => <button onClick={t} style={{ width: 22, height: 22, borderRadius: 6, background: s.color, border: "none", cursor: "pointer" }} />}>
                <div className="row" style={{ gap: 6, padding: 8 }}>{PALETTE.map((c) => <button key={c} onClick={() => setLocal((l) => l.map((x) => x.id === s.id ? { ...x, color: c } : x))} style={{ width: 22, height: 22, borderRadius: 6, background: c, border: "none", cursor: "pointer" }} />)}</div>
              </Dropdown>
              <input className="rl-input rl-input--sm grow" value={s.name} onChange={(e) => setLocal((l) => l.map((x) => x.id === s.id ? { ...x, name: e.target.value } : x))} />
              <button className="rl-iconbtn rl-iconbtn--sm" onClick={() => setLocal((l) => l.filter((x) => x.id !== s.id))}><Icon name="trash-2" size={15} /></button>
            </div>
          ))}
        </div>
        <button className="rl-btn rl-btn--ghost rl-btn--sm" style={{ marginTop: 10 }} onClick={() => setLocal((l) => [...l, { id: "s" + Date.now(), name: "New stage", color: "var(--cat-6)" }])}><Icon name="plus" size={14} />Add stage</button>
      </div>
      <div className="rl-modal__foot">
        <button className="rl-btn rl-btn--ghost" onClick={onClose}>Cancel</button>
        <button className="rl-btn rl-btn--primary" onClick={() => { setStages(local); onClose(); }}><Icon name="check" size={15} />Save stages</button>
      </div>
    </Modal>
  );
}

window.ViewPipeline = ViewPipeline;
