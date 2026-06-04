/* ============================================================
   Relay app — Today (home). Role-aware rep cockpit.
   ============================================================ */

function greeting() { const h = new Date().getHours(); return h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"; }

const TASK_TYPE_ICON = { call: "phone", whatsapp: "message-circle", email: "mail", meeting: "calendar" };
const PRIO = { high: { c: "var(--color-danger)", l: "High" }, med: { c: "var(--color-warning)", l: "Medium" }, low: { c: "var(--color-fg-4)", l: "Low" } };

function TaskRow({ t, onDone, onOpen, onCall }) {
  const lead = RX.leadByKey(t.leadKey);
  const overdue = t.due === "overdue";
  return (
    <div className="rl-listitem" style={{ opacity: t.done ? 0.5 : 1 }}>
      <button className="rl-check" onClick={() => onDone(t.id)} title="Complete" style={{ marginRight: 2 }}>
        <span className="rl-box" style={t.done ? { background: "var(--color-primary)", borderColor: "var(--color-primary)", color: "#fff" } : {}}>{t.done && <Icon name="check" size={13} />}</span>
      </button>
      <span className="iccircle" style={{ width: 30, height: 30, background: "var(--color-surface-3)", color: "var(--color-fg-2)" }}><Icon name={TASK_TYPE_ICON[t.type]} size={15} /></span>
      <div className="rl-listitem__main">
        <div className="rl-listitem__title" style={{ textDecoration: t.done ? "line-through" : "none" }}>{t.title}</div>
        <div className="rl-listitem__sub row" style={{ gap: 8 }}>
          {lead && <span className="clickable" style={{ color: "var(--color-primary-text)", fontWeight: 600 }} onClick={() => onOpen(lead.key)}>{lead.company}</span>}
          <span style={{ width: 3, height: 3, borderRadius: 9, background: "var(--color-fg-4)" }} />
          <span style={{ color: overdue ? "var(--color-danger-text)" : "var(--color-fg-3)", fontWeight: overdue ? 700 : 500 }}>{t.dueLabel}</span>
        </div>
      </div>
      <span className="rl-badge" style={{ background: "transparent" }}><i style={{ width: 7, height: 7, borderRadius: 9, background: PRIO[t.priority].c }} />{PRIO[t.priority].l}</span>
      {t.type === "call" && lead && <button className="rl-btn rl-btn--secondary rl-btn--sm" onClick={() => onCall(lead)}><Icon name="phone" size={14} />Call</button>}
      {t.type !== "call" && lead && <button className="rl-btn rl-btn--ghost rl-btn--sm" onClick={() => onOpen(lead.key)}>Open</button>}
    </div>
  );
}

function ViewToday() {
  const app = useApp();
  const { me, role, navigate, toast, startCall, stateMode } = app;
  const [tasks, setTasks] = useState(RX.TASKS);
  const [unassigned, setUnassigned] = useState(RX.UNASSIGNED);

  const isMgr = role !== "associate";
  const myTasks = isMgr ? tasks : tasks.filter((t) => t.owner === me.id);
  const buckets = {
    overdue: myTasks.filter((t) => t.due === "overdue" && !t.done),
    today: myTasks.filter((t) => t.due === "today" && !t.done),
    upcoming: myTasks.filter((t) => t.due === "upcoming" && !t.done),
  };
  const doneCount = myTasks.filter((t) => t.done).length;

  const onDone = (id) => { setTasks((ts) => ts.map((t) => t.id === id ? { ...t, done: !t.done } : t)); toast("Task updated", "success"); };
  const onOpen = (key) => navigate("lead", { key });
  const onCall = (lead) => startCall(lead);
  const assignToMe = (id) => { setUnassigned((u) => u.filter((l) => l.id !== id)); toast("Lead assigned to you", "success"); };

  const myDeals = RX.DEALS.filter((d) => isMgr || d.owner === me.id);
  const wonValue = myDeals.filter((d) => d.stage === "won").reduce((s, d) => s + d.value, 0);
  const openPipe = myDeals.filter((d) => d.stage !== "won" && d.stage !== "lost").reduce((s, d) => s + d.value, 0);

  const hot = RX.ALL_LEADS.filter((l) => (isMgr || l.owner === me.id) && l.unread > 0).slice(0, 4);

  if (stateMode === "loading") return <TodaySkeleton />;

  return (
    <div className="page">
      {/* Header */}
      <div className="pagehead">
        <div>
          <div className="rl-eyebrow" style={{ marginBottom: 6 }}>{new Date().toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric" })}</div>
          <div className="pagehead__title">{greeting()}, {me.first}.</div>
          <div className="pagehead__sub">
            {isMgr ? <>Your team has <b>{tasks.filter((t) => !t.done).length} open follow-ups</b> and <b>{RX.money(openPipe)}</b> in active pipeline.</>
              : buckets.overdue.length ? <>You have <b style={{ color: "var(--color-danger-text)" }}>{buckets.overdue.length} overdue</b> and {buckets.today.length} due today. Let's clear them.</>
                : <>You're on track — {buckets.today.length} follow-ups due today and {hot.length} leads waiting on you.</>}
          </div>
        </div>
        <div className="pagehead__actions">
          <button className="rl-btn rl-btn--secondary" onClick={() => navigate("insights")}><Icon name="bar-chart-3" size={15} />My numbers</button>
          <button className="rl-btn rl-btn--primary" onClick={() => navigate("leads")}><Icon name="zap" size={15} />Work my list</button>
        </div>
      </div>

      {/* KPI row */}
      <div className="grid grid-4" style={{ marginBottom: "var(--space-6)" }}>
        <Stat label="Calls today" value={isMgr ? 71 : RX.KPIS.callsToday} delta={RX.KPIS.callsDelta} deltaSuffix="%" spark={RX.SPARK} icon="phone" />
        <Stat label="Leads worked" value={isMgr ? 100 : RX.KPIS.leadsWorked} delta={RX.KPIS.leadsDelta} icon="users" sparkColor="var(--cat-2)" spark={[8, 12, 10, 16, 14, 20, 18, 24, 22, 27, 25, 31]} />
        <Stat label="Deals won (mo)" value={RX.moneyK(isMgr ? 319000 : wonValue)} delta={RX.KPIS.dealsDelta} icon="trophy" sparkColor="var(--cat-3)" spark={[2, 2, 3, 3, 2, 4, 4, 3, 5, 4, 5, isMgr ? 11 : 4]} />
        <Stat label="Conversion" value={(isMgr ? 21 : RX.KPIS.conversion) + "%"} delta={RX.KPIS.conversionDelta} deltaSuffix="pt" icon="target" sparkColor="var(--cat-5)" spark={[18, 19, 17, 20, 21, 22, 20, 23, 22, 24, 23, 24]} />
      </div>

      <div className="grid" style={{ gridTemplateColumns: "1.55fr 1fr", alignItems: "start" }}>
        {/* Left: follow-ups */}
        <div className="col" style={{ gap: "var(--space-5)" }}>
          <div className="sect">
            <div className="sect__head">
              <div className="sect__title"><Icon name="list-checks" size={19} />Today's follow-ups</div>
              <div className="row" style={{ gap: 8 }}>
                <span className="muted rl-sm">{doneCount} done</span>
                <button className="rl-btn rl-btn--ghost rl-btn--sm" onClick={() => navigate("leads")}>View all</button>
              </div>
            </div>
            <div className="sect__body--flush">
              {stateMode === "error" ? <ErrorPanel onRetry={() => toast("Reloaded", "success")} />
                : myTasks.filter((t) => !t.done).length === 0 ? <Empty icon="check-circle-2" title="Inbox zero on tasks" body="You've cleared every follow-up. Nice work — go work some fresh leads." action={<button className="rl-btn rl-btn--primary rl-btn--sm" onClick={() => navigate("leads")}>Work my list</button>} />
                  : <>
                    {buckets.overdue.length > 0 && <div style={{ padding: "10px 16px 4px" }}><span className="rl-eyebrow" style={{ color: "var(--color-danger-text)" }}>Overdue · {buckets.overdue.length}</span></div>}
                    {buckets.overdue.map((t) => <TaskRow key={t.id} t={t} onDone={onDone} onOpen={onOpen} onCall={onCall} />)}
                    <div style={{ padding: "12px 16px 4px" }}><span className="rl-eyebrow">Today · {buckets.today.length}</span></div>
                    {buckets.today.map((t) => <TaskRow key={t.id} t={t} onDone={onDone} onOpen={onOpen} onCall={onCall} />)}
                    <div style={{ padding: "12px 16px 4px" }}><span className="rl-eyebrow">Upcoming · {buckets.upcoming.length}</span></div>
                    {buckets.upcoming.map((t) => <TaskRow key={t.id} t={t} onDone={onDone} onOpen={onOpen} onCall={onCall} />)}
                  </>}
            </div>
          </div>

          {/* Manager: team performance */}
          {isMgr && <div className="sect">
            <div className="sect__head">
              <div className="sect__title"><Icon name="users-2" size={19} />Team today</div>
              <button className="rl-btn rl-btn--ghost rl-btn--sm" onClick={() => navigate("insights")}>Full report</button>
            </div>
            <div className="sect__body--flush">
              {RX.PER_REP.map((r) => { const u = RX.USERS[r.id]; return (
                <div className="rl-listitem" key={r.id}>
                  <Avatar user={u} size="sm" />
                  <div className="rl-listitem__main">
                    <div className="rl-listitem__title">{u.name}</div>
                    <div className="rl-listitem__sub">{r.calls} calls · {r.leads} leads · {RX.money(r.wonValue)} won</div>
                  </div>
                  <div style={{ width: 130 }}>
                    <div className="spread" style={{ marginBottom: 4 }}><span className="muted" style={{ fontSize: 11 }}>Target</span><span className="mono" style={{ fontSize: 11, fontWeight: 700, color: r.attainment >= 85 ? "var(--color-success-text)" : r.attainment >= 60 ? "var(--color-warning-text)" : "var(--color-danger-text)" }}>{r.attainment}%</span></div>
                    <div className="targetbar"><i style={{ width: r.attainment + "%", background: r.attainment >= 85 ? "var(--color-success)" : r.attainment >= 60 ? "var(--color-warning)" : "var(--color-danger)" }} /></div>
                  </div>
                </div>
              ); })}
            </div>
          </div>}
        </div>

        {/* Right column */}
        <div className="col" style={{ gap: "var(--space-5)" }}>
          {/* Unassigned / assign to me */}
          <div className="sect">
            <div className="sect__head">
              <div className="sect__title"><Icon name="inbox" size={18} />Unassigned leads</div>
              <span className="rl-badge rl-badge--warning">{unassigned.length} new</span>
            </div>
            <div className="sect__body--flush">
              {unassigned.length === 0 ? <div style={{ padding: "20px 16px", textAlign: "center" }} className="muted rl-sm">All caught up — nothing waiting.</div>
                : unassigned.map((l) => (
                  <div className="rl-listitem" key={l.id}>
                    <Avatar name={l.name} av="rl-avatar--c3" size="sm" />
                    <div className="rl-listitem__main">
                      <div className="rl-listitem__title">{l.name}</div>
                      <div className="rl-listitem__sub row" style={{ gap: 6 }}><span>{l.company}</span><i style={{ width: 3, height: 3, borderRadius: 9, background: "var(--color-fg-4)" }} /><SourceMini source={l.source} /></div>
                    </div>
                    <button className="rl-btn rl-btn--brand-soft rl-btn--sm" onClick={() => assignToMe(l.id)}>Assign to me</button>
                  </div>
                ))}
            </div>
          </div>

          {/* Waiting on you */}
          <div className="sect">
            <div className="sect__head">
              <div className="sect__title"><Icon name="message-circle" size={18} />Waiting on you</div>
              <button className="rl-btn rl-btn--ghost rl-btn--sm" onClick={() => navigate("inbox")}>Inbox</button>
            </div>
            <div className="sect__body--flush">
              {hot.length === 0 ? <div style={{ padding: "20px 16px", textAlign: "center" }} className="muted rl-sm">No unread conversations.</div>
                : hot.map((l) => (
                  <div className="rl-convo" onClick={() => navigate("lead", { key: l.key })} key={l.id}>
                    <Avatar name={l.name} av="rl-avatar--c1" />
                    <div className="rl-convo__main">
                      <div className="rl-convo__row"><span className="rl-convo__name">{l.name}</span><span className="rl-convo__time">{l.lastTouch}</span></div>
                      <div className="rl-convo__preview"><ChannelPip type={l.lastChannel} ghost /><span style={{ marginLeft: 2 }}>{l.company}</span></div>
                    </div>
                    {l.unread > 0 && <span className="rl-convo__unread">{l.unread}</span>}
                  </div>
                ))}
            </div>
          </div>

          {/* Pipeline snapshot */}
          <div className="sect">
            <div className="sect__head"><div className="sect__title"><Icon name="trending-up" size={18} />Pipeline</div><button className="rl-btn rl-btn--ghost rl-btn--sm" onClick={() => navigate("pipeline")}>Open board</button></div>
            <div className="sect__body">
              <div className="spread" style={{ alignItems: "center" }}>
                <div>
                  <div className="rl-eyebrow">Open pipeline</div>
                  <div style={{ fontFamily: "var(--font-display)", fontWeight: 800, fontSize: 30, letterSpacing: "-.02em", lineHeight: 1.1 }}>{RX.money(openPipe)}</div>
                  <div className="muted rl-sm" style={{ marginTop: 2 }}>{myDeals.filter((d) => d.stage !== "won" && d.stage !== "lost").length} active deals</div>
                </div>
                <Ring value={isMgr ? 68 : 72} size={84} stroke={9} label={(isMgr ? 68 : 72) + "%"} sub="win rate" />
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function SourceMini({ source }) {
  const c = RX.SOURCE[source] || "var(--color-fg-3)";
  return <span className="row" style={{ gap: 5, fontSize: 12 }}><i style={{ width: 7, height: 7, borderRadius: 2, background: c }} />{source}</span>;
}

function TodaySkeleton() {
  return (
    <div className="page">
      <div className="rl-skel" style={{ height: 38, width: 320, marginBottom: 10 }} />
      <div className="rl-skel" style={{ height: 16, width: 460, marginBottom: 28 }} />
      <div className="grid grid-4" style={{ marginBottom: 24 }}>{[0, 1, 2, 3].map((i) => <div className="rl-stat" key={i}><div className="rl-skel" style={{ height: 12, width: 80, marginBottom: 14 }} /><div className="rl-skel" style={{ height: 30, width: 110, marginBottom: 12 }} /><div className="rl-skel" style={{ height: 12, width: 60 }} /></div>)}</div>
      <div className="grid" style={{ gridTemplateColumns: "1.55fr 1fr" }}>
        <div className="sect"><div className="sect__head"><div className="rl-skel" style={{ height: 18, width: 160 }} /></div><SkeletonRows rows={6} /></div>
        <div className="sect"><div className="sect__head"><div className="rl-skel" style={{ height: 18, width: 120 }} /></div><SkeletonRows rows={4} /></div>
      </div>
    </div>
  );
}

window.ViewToday = ViewToday;
