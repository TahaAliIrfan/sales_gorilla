/* ============================================================
   Relay app — Insights: KPI dashboard, funnel, per-rep
   performance, targets. Role-scoped (rep vs manager/admin).
   ============================================================ */

const INSIGHTS_RANGES = ["7 days", "30 days", "Quarter", "Year"];
const CALLS_WEEKS = [{ label: "W1", v: 84 }, { label: "W2", v: 102 }, { label: "W3", v: 96 }, { label: "W4", v: 121 }, { label: "W5", v: 138 }, { label: "W6", v: 117 }];
const CONV_WEEKS = [18, 19, 17, 20, 21, 22, 20, 23, 22, 24, 23, 24];

function Funnel({ data }) {
  return (
    <div className="col" style={{ gap: 10 }}>
      {data.map((f, i) => (
        <div key={f.stage}>
          <div className="spread" style={{ marginBottom: 4 }}><span className="rl-sm" style={{ fontWeight: 600 }}>{f.stage}</span><span className="row" style={{ gap: 8 }}><b className="tnum">{f.value}</b><span className="muted tnum" style={{ fontSize: 12, width: 38, textAlign: "right" }}>{f.pct}%</span></span></div>
          <div style={{ height: 26, borderRadius: 6, background: "var(--color-surface-3)", overflow: "hidden" }}>
            <div style={{ width: f.pct + "%", height: "100%", borderRadius: 6, background: `color-mix(in oklch, var(--color-primary) ${100 - i * 12}%, var(--cat-5))`, transition: "width .6s var(--ease-out)" }} />
          </div>
        </div>
      ))}
    </div>
  );
}

function ViewInsights() {
  const app = useApp();
  const { role, me } = app;
  const [range, setRange] = useState("30 days");
  const isMgr = role !== "associate";
  const mine = RX.PER_REP.find((r) => r.id === me.id) || RX.PER_REP[0];

  return (
    <div className="page page--wide">
      <div className="pagehead">
        <div><div className="pagehead__title">Insights</div><div className="pagehead__sub">{isMgr ? "Team performance, conversion and targets." : "Your performance, conversion and targets."} · {range}</div></div>
        <div className="pagehead__actions">
          <div className="rl-segmented">{INSIGHTS_RANGES.map((r) => <button key={r} className={range === r ? "is-active" : ""} onClick={() => setRange(r)}>{r}</button>)}</div>
          <button className="rl-btn rl-btn--secondary"><Icon name="download" size={15} />Export</button>
        </div>
      </div>

      {/* KPI row */}
      <div className="grid grid-4" style={{ marginBottom: "var(--space-6)" }}>
        <Stat label="Calls" value={isMgr ? 658 : mine.calls * 12} delta={12} deltaSuffix="%" icon="phone" spark={RX.SPARK} />
        <Stat label="Leads worked" value={isMgr ? 412 : mine.leads * 9} delta={5} icon="users" sparkColor="var(--cat-2)" spark={[8, 12, 10, 16, 14, 20, 18, 24, 22, 27, 25, 31]} />
        <Stat label="Deals won" value={isMgr ? 10 : mine.won} delta={2} icon="trophy" sparkColor="var(--cat-3)" spark={[2, 2, 3, 3, 2, 4, 4, 3, 5, 4, 5, isMgr ? 10 : 4]} />
        <Stat label="Conversion" value={(isMgr ? 21 : mine.conv) + "%"} delta={3} deltaSuffix="pt" icon="target" sparkColor="var(--cat-5)" spark={CONV_WEEKS} />
      </div>

      {/* charts */}
      <div className="grid" style={{ gridTemplateColumns: "1.4fr 1fr", marginBottom: "var(--space-6)" }}>
        <div className="sect"><div className="sect__head"><div className="sect__title"><Icon name="bar-chart-3" size={19} />Calls per week</div><span className="muted rl-sm">{isMgr ? "Team" : "You"}</span></div>
          <div className="sect__body"><Bars data={CALLS_WEEKS} h={180} /></div></div>
        <div className="sect"><div className="sect__head"><div className="sect__title"><Icon name="filter" size={19} />Conversion funnel</div></div>
          <div className="sect__body"><Funnel data={RX.FUNNEL} /></div></div>
      </div>

      {/* targets + (team or personal) */}
      <div className="grid" style={{ gridTemplateColumns: isMgr ? "1fr" : "1fr 1fr", marginBottom: "var(--space-6)" }}>
        {isMgr ? (
          <div className="sect">
            <div className="sect__head"><div className="sect__title"><Icon name="users-2" size={19} />Per-rep performance</div><span className="muted rl-sm">vs monthly target</span></div>
            <div className="sect__body--flush">
              <table className="rl-table">
                <thead><tr><th>Rep</th><th style={{ textAlign: "right" }}>Calls</th><th style={{ textAlign: "right" }}>Leads</th><th style={{ textAlign: "right" }}>Won</th><th style={{ textAlign: "right" }}>Won value</th><th style={{ textAlign: "right" }}>Conv.</th><th style={{ width: 200 }}>Target attainment</th></tr></thead>
                <tbody>
                  {RX.PER_REP.map((r) => { const u = RX.USERS[r.id]; const col = r.attainment >= 85 ? "var(--color-success)" : r.attainment >= 60 ? "var(--color-warning)" : "var(--color-danger)"; return (
                    <tr key={r.id}>
                      <td><div className="row" style={{ gap: 10 }}><Avatar user={u} size="sm" /><div><div className="rl-cell-strong">{u.name}</div><div className="muted" style={{ fontSize: 11 }}>{u.title}</div></div></div></td>
                      <td className="rl-cell-num">{r.calls}</td>
                      <td className="rl-cell-num">{r.leads}</td>
                      <td className="rl-cell-num">{r.won}</td>
                      <td className="rl-cell-num">{RX.money(r.wonValue)}</td>
                      <td className="rl-cell-num">{r.conv}%</td>
                      <td><div className="row" style={{ gap: 10 }}><div className="targetbar grow"><i style={{ width: Math.min(r.attainment, 100) + "%", background: col }} /></div><b className="tnum" style={{ color: col, fontSize: 13, width: 38, textAlign: "right" }}>{r.attainment}%</b></div></td>
                    </tr>
                  ); })}
                </tbody>
              </table>
            </div>
          </div>
        ) : (<>
          <div className="sect"><div className="sect__head"><div className="sect__title"><Icon name="target" size={19} />My target</div></div>
            <div className="sect__body">
              <div className="spread" style={{ alignItems: "center" }}>
                <div><div className="rl-eyebrow">Monthly meetings</div><div style={{ fontFamily: "var(--font-display)", fontWeight: 800, fontSize: 34 }}>{Math.round(mine.target * mine.attainment / 100)}<span className="muted" style={{ fontSize: 20 }}> / {mine.target}</span></div><div className="muted rl-sm">{mine.attainment}% of target · 6 days left</div></div>
                <Ring value={mine.attainment} size={96} stroke={10} label={mine.attainment + "%"} sub="attained" />
              </div>
            </div>
          </div>
          <div className="sect"><div className="sect__head"><div className="sect__title"><Icon name="award" size={19} />Where you rank</div></div>
            <div className="sect__body--flush">
              {[...RX.PER_REP].sort((a, b) => b.attainment - a.attainment).map((r, i) => { const u = RX.USERS[r.id]; const meRow = r.id === me.id; return (
                <div className="rl-listitem" key={r.id} style={{ background: meRow ? "var(--color-primary-subtle)" : "transparent" }}>
                  <span className="mono" style={{ fontWeight: 700, width: 22, color: i === 0 ? "var(--color-warning-text)" : "var(--color-fg-3)" }}>{i + 1}</span>
                  <Avatar user={u} size="sm" />
                  <div className="rl-listitem__main"><div className="rl-listitem__title">{u.name}{meRow && <span className="rl-badge rl-badge--primary" style={{ marginLeft: 6 }}>You</span>}</div><div className="rl-listitem__sub">{r.won} won · {RX.money(r.wonValue)}</div></div>
                  <b className="tnum" style={{ color: r.attainment >= 85 ? "var(--color-success-text)" : "var(--color-fg-2)" }}>{r.attainment}%</b>
                </div>
              ); })}
            </div>
          </div>
        </>)}
      </div>

      {/* source breakdown */}
      <div className="sect">
        <div className="sect__head"><div className="sect__title"><Icon name="git-fork" size={19} />Lead source performance</div><span className="muted rl-sm">won deals by attribution</span></div>
        <div className="sect__body">
          <div className="grid grid-4">
            {Object.entries(RX.SOURCE).slice(0, 4).map(([src, color], i) => { const vals = [38, 24, 18, 12]; return (
              <div key={src}>
                <div className="row" style={{ gap: 6, marginBottom: 6 }}><i style={{ width: 9, height: 9, borderRadius: 2, background: color }} /><span className="rl-sm" style={{ fontWeight: 600 }}>{src}</span></div>
                <div style={{ fontFamily: "var(--font-display)", fontWeight: 800, fontSize: 24 }}>{vals[i]}%</div>
                <div className="muted" style={{ fontSize: 12 }}>{[12, 8, 6, 4][i]} won · {RX.money([148000, 92000, 64000, 38000][i])}</div>
              </div>
            ); })}
          </div>
        </div>
      </div>
    </div>
  );
}

window.ViewInsights = ViewInsights;
