/* ============================================================
   Relay app — Outreach: audiences (customer groups),
   WhatsApp campaigns (schedule, per-recipient status,
   stop/restart), and template management.
   ============================================================ */

const CAMPAIGN_STATUS = {
  sending:   { badge: "rl-badge--info", label: "Sending", icon: "loader" },
  scheduled: { badge: "rl-badge--neutral", label: "Scheduled", icon: "clock" },
  completed: { badge: "rl-badge--success", label: "Completed", icon: "check-circle-2" },
  paused:    { badge: "rl-badge--warning", label: "Paused", icon: "pause" },
  draft:     { badge: "rl-badge--neutral", label: "Draft", icon: "file" },
};
const SEND_SEG = [
  { k: "replied", label: "Replied", color: "var(--color-primary)" },
  { k: "read", label: "Read", color: "var(--channel-whatsapp)" },
  { k: "delivered", label: "Delivered", color: "var(--color-info)" },
  { k: "sent", label: "Sent", color: "var(--cat-3)" },
  { k: "queued", label: "Queued", color: "var(--color-border-strong)" },
  { k: "failed", label: "Failed", color: "var(--color-danger)" },
];

function CampaignProgress({ counts, total }) {
  return (
    <div>
      <div className="segbar" style={{ marginBottom: 8 }}>
        {SEND_SEG.map((s) => counts[s.k] > 0 && <i key={s.k} title={s.label + ": " + counts[s.k]} style={{ width: (counts[s.k] / total * 100) + "%", background: s.color }} />)}
      </div>
      <div className="row" style={{ gap: 14, flexWrap: "wrap" }}>
        {SEND_SEG.map((s) => <span key={s.k} className="row" style={{ gap: 5, fontSize: 12 }}><i style={{ width: 8, height: 8, borderRadius: 2, background: s.color }} /><span className="muted">{s.label}</span><b className="tnum">{counts[s.k]}</b></span>)}
      </div>
    </div>
  );
}

function ViewOutreach() {
  const app = useApp();
  const { toast } = app;
  const [tab, setTab] = useState("campaigns");
  const [campaigns, setCampaigns] = useState(RX.CAMPAIGNS);
  const [detail, setDetail] = useState(null);
  const [newOpen, setNewOpen] = useState(!!app.route.params.newCampaign);

  const ctl = (id, action) => {
    setCampaigns((cs) => cs.map((c) => c.id === id ? { ...c, status: action === "pause" ? "paused" : action === "resume" ? "sending" : action === "stop" ? "completed" : c.status } : c));
    toast(action === "pause" ? "Campaign paused" : action === "resume" ? "Campaign restarted" : "Campaign stopped", action === "stop" ? "info" : "success");
  };

  return (
    <div className="page page--wide">
      <div className="pagehead">
        <div><div className="pagehead__title">Outreach</div><div className="pagehead__sub">Build audiences, run bulk WhatsApp campaigns, manage approved templates.</div></div>
        <div className="pagehead__actions">
          <button className="rl-btn rl-btn--secondary" onClick={() => setTab("audiences")}><Icon name="users-round" size={15} />New audience</button>
          <button className="rl-btn rl-btn--primary" onClick={() => setNewOpen(true)}><Icon name="megaphone" size={15} />New campaign</button>
        </div>
      </div>

      <div className="grid grid-4" style={{ marginBottom: "var(--space-6)" }}>
        <Stat label="Active campaigns" value={campaigns.filter((c) => c.status === "sending" || c.status === "scheduled").length} icon="megaphone" />
        <Stat label="Messages sent (mo)" value="11.4k" delta={32} deltaSuffix="%" icon="send" sparkColor="var(--channel-whatsapp)" spark={[4, 6, 5, 8, 7, 9, 8, 11, 10, 12, 11, 14]} />
        <Stat label="Reply rate" value="13%" delta={2} deltaSuffix="pt" icon="message-circle" sparkColor="var(--color-primary)" spark={[9, 10, 11, 10, 12, 11, 13, 12, 13, 12, 13, 13]} />
        <Stat label="Audiences" value={RX.GROUPS.length} icon="users-round" />
      </div>

      <div className="rl-tabs" style={{ marginBottom: "var(--space-5)" }}>
        {[["campaigns", "Campaigns", campaigns.length], ["audiences", "Audiences", RX.GROUPS.length], ["templates", "Templates", RX.TEMPLATES.length]].map(([id, label, n]) => (
          <button key={id} className={cx("rl-tab", tab === id && "is-active")} onClick={() => setTab(id)}>{label}<span className="rl-tab-count">{n}</span></button>
        ))}
      </div>

      {tab === "campaigns" && <div className="col" style={{ gap: "var(--space-4)" }}>
        {campaigns.map((c) => { const st = CAMPAIGN_STATUS[c.status]; const owner = RX.USERS[c.owner]; return (
          <div className="sect" key={c.id}>
            <div className="sect__body">
              <div className="spread" style={{ marginBottom: 14, alignItems: "flex-start" }}>
                <div className="row" style={{ gap: 12 }}>
                  <span className="iccircle" style={{ width: 42, height: 42, background: "color-mix(in oklch, var(--channel-whatsapp) 16%, transparent)", color: "var(--channel-whatsapp)" }}><Icon name="message-circle" size={20} /></span>
                  <div>
                    <div className="row" style={{ gap: 8 }}><b style={{ fontSize: "var(--text-h4)", fontWeight: 700 }}>{c.name}</b><span className={cx("rl-badge", st.badge)}><Icon name={st.icon} size={11} />{st.label}</span></div>
                    <div className="muted rl-sm row" style={{ gap: 8, marginTop: 2 }}><span><Icon name="users-round" size={13} style={{ verticalAlign: "-2px", marginRight: 3 }} />{c.group}</span><span>·</span><span><Icon name="clock" size={13} style={{ verticalAlign: "-2px", marginRight: 3 }} />{c.scheduled}</span><span>·</span><span>{c.recipients} recipients</span></div>
                  </div>
                </div>
                <div className="row" style={{ gap: 6 }}>
                  {c.status === "sending" && <button className="rl-btn rl-btn--secondary rl-btn--sm" onClick={() => ctl(c.id, "pause")}><Icon name="pause" size={14} />Pause</button>}
                  {c.status === "paused" && <button className="rl-btn rl-btn--brand-soft rl-btn--sm" onClick={() => ctl(c.id, "resume")}><Icon name="play" size={14} />Restart</button>}
                  {c.status === "scheduled" && <button className="rl-btn rl-btn--secondary rl-btn--sm" onClick={() => ctl(c.id, "pause")}><Icon name="pause" size={14} />Hold</button>}
                  {(c.status === "sending" || c.status === "paused") && <button className="rl-btn rl-btn--destructive-ghost rl-btn--sm" onClick={() => ctl(c.id, "stop")}><Icon name="square" size={14} />Stop</button>}
                  <button className="rl-btn rl-btn--ghost rl-btn--sm" onClick={() => setDetail(c)}>Details<Icon name="chevron-right" size={14} /></button>
                </div>
              </div>
              <CampaignProgress counts={c.counts} total={c.recipients} />
            </div>
          </div>
        ); })}
      </div>}

      {tab === "audiences" && <div className="grid grid-2">
        {RX.GROUPS.map((g) => (
          <div className="sect" key={g.id}><div className="sect__body">
            <div className="spread" style={{ marginBottom: 10 }}>
              <div className="row" style={{ gap: 10 }}><span className="iccircle" style={{ background: "var(--color-primary-subtle)", color: "var(--color-primary-text)" }}><Icon name="users-round" size={18} /></span><div><b style={{ fontWeight: 700 }}>{g.name}</b><div className="muted" style={{ fontSize: 12 }}>Updated {g.updated}</div></div></div>
              <div style={{ textAlign: "right" }}><div style={{ fontFamily: "var(--font-display)", fontWeight: 800, fontSize: 22 }}>{g.count}</div><div className="muted" style={{ fontSize: 11 }}>contacts</div></div>
            </div>
            <div style={{ background: "var(--color-surface-2)", border: "1px solid var(--color-border)", borderRadius: "var(--radius-md)", padding: "8px 12px", fontSize: 12 }} className="mono muted">{g.filter}</div>
            <div className="row" style={{ gap: 6, marginTop: 12 }}><button className="rl-btn rl-btn--primary rl-btn--sm"><Icon name="megaphone" size={14} />Launch campaign</button><button className="rl-btn rl-btn--ghost rl-btn--sm"><Icon name="pencil" size={14} />Edit filter</button></div>
          </div></div>
        ))}
      </div>}

      {tab === "templates" && <div className="grid grid-2">
        {RX.TEMPLATES.map((t) => (
          <div className="sect" key={t.id}><div className="sect__body">
            <div className="spread" style={{ marginBottom: 10 }}>
              <div className="row" style={{ gap: 10 }}>
                <span className={cx("chan", t.channel === "whatsapp" ? "chan--whatsapp" : "chan--email")} style={{ width: 34, height: 34 }}><Icon name={t.channel === "whatsapp" ? "message-circle" : "mail"} size={16} /></span>
                <div><b style={{ fontWeight: 700 }}>{t.name}</b><div className="muted" style={{ fontSize: 12 }}>{t.channel === "whatsapp" ? "WhatsApp" : "Email"} · {t.category}</div></div>
              </div>
              <span className={cx("rl-badge", t.status === "approved" ? "rl-badge--success" : "rl-badge--warning")}>{t.status === "approved" ? "Approved" : "Pending review"}</span>
            </div>
            <div style={{ background: "var(--color-surface-2)", border: "1px solid var(--color-border)", borderRadius: "var(--radius-md)", padding: 12, fontSize: 13, lineHeight: 1.5, color: "var(--color-fg-2)" }}>
              {t.body.split(/(\{\{[a-z_]+\}\})/g).map((p, i) => p.startsWith("{{") ? <span key={i} className="rl-badge rl-badge--primary" style={{ height: 18, margin: "0 1px" }}>{p.replace(/[{}]/g, "")}</span> : p)}
            </div>
            <div className="row" style={{ gap: 6, marginTop: 12 }}><button className="rl-btn rl-btn--secondary rl-btn--sm"><Icon name="pencil" size={14} />Edit</button><button className="rl-btn rl-btn--ghost rl-btn--sm"><Icon name="copy" size={14} />Duplicate</button></div>
          </div></div>
        ))}
        <button className="sect clickable" onClick={() => app.toast("New template", "info")} style={{ display: "grid", placeItems: "center", minHeight: 160, border: "1.5px dashed var(--color-border-strong)", background: "var(--color-surface-2)" }}>
          <div style={{ textAlign: "center", color: "var(--color-fg-3)" }}><Icon name="plus" size={24} /><div className="rl-sm" style={{ fontWeight: 600, marginTop: 6 }}>New template</div></div>
        </button>
      </div>}

      {detail && <CampaignDetail campaign={detail} onClose={() => setDetail(null)} />}
      {newOpen && <NewCampaign onClose={() => setNewOpen(false)} onCreate={() => { setNewOpen(false); toast("Campaign scheduled", "success"); }} />}
    </div>
  );
}

/* ---------- Campaign detail: per-recipient status ---------- */
const RCPT_STATUS = { replied: ["Replied", "var(--color-primary-text)", "reply"], read: ["Read", "var(--channel-whatsapp)", "check-check"], delivered: ["Delivered", "var(--color-info-text)", "check-check"], sent: ["Sent", "var(--cat-3)", "check"], queued: ["Queued", "var(--color-fg-3)", "clock"], failed: ["Failed", "var(--color-danger-text)", "alert-circle"] };
function CampaignDetail({ campaign, onClose }) {
  const recipients = useMemo(() => {
    const order = ["replied", "read", "read", "delivered", "sent", "queued", "failed", "read", "delivered", "replied", "queued", "read"];
    const names = ["Sara Lindqvist", "Tomás Ferreira", "Rosa Méndez", "Hiro Tanaka", "Jonah Reyes", "Karl Nyström", "Wendy Aboagye", "Irene Sokolova", "Greg Mulligan", "Nadia Haddad", "Felix Brandt", "Yuki Sato"];
    return names.map((n, i) => ({ name: n, status: order[i], time: i < 8 ? (9 + i % 4) + ":1" + i : "—" }));
  }, [campaign.id]);
  return (
    <Drawer onClose={onClose} wide>
      <div className="drawer__head">
        <span className="iccircle" style={{ background: "color-mix(in oklch, var(--channel-whatsapp) 16%, transparent)", color: "var(--channel-whatsapp)" }}><Icon name="message-circle" size={18} /></span>
        <div className="grow"><div className="rl-h4">{campaign.name}</div><div className="muted rl-sm">{campaign.group} · {campaign.recipients} recipients</div></div>
        <button className="rl-iconbtn" onClick={onClose}><Icon name="x" size={18} /></button>
      </div>
      <div className="drawer__body">
        <CampaignProgress counts={campaign.counts} total={campaign.recipients} />
        <div className="rl-eyebrow" style={{ margin: "20px 0 10px" }}>Per-recipient status</div>
        <div className="rl-table-wrap">
          <table className="rl-table is-dense">
            <thead><tr><th>Recipient</th><th>Status</th><th style={{ textAlign: "right" }}>Time</th></tr></thead>
            <tbody>
              {recipients.map((r, i) => { const m = RCPT_STATUS[r.status]; return (
                <tr key={i}>
                  <td><div className="row" style={{ gap: 8 }}><Avatar name={r.name} av={"rl-avatar--c" + ((i % 5) + 1)} size="xs" />{r.name}</div></td>
                  <td><span className="row" style={{ gap: 6, color: m[1], fontWeight: 600, fontSize: 13 }}><Icon name={m[2]} size={14} />{m[0]}</span></td>
                  <td className="rl-cell-num muted">{r.time}</td>
                </tr>
              ); })}
            </tbody>
          </table>
        </div>
      </div>
      <div className="drawer__foot" style={{ justifyContent: "space-between" }}>
        {campaign.status === "sending" || campaign.status === "paused" ? <button className="rl-btn rl-btn--destructive-ghost"><Icon name="square" size={15} />Stop campaign</button> : <span />}
        <button className="rl-btn rl-btn--secondary" onClick={onClose}>Close</button>
      </div>
    </Drawer>
  );
}

/* ---------- New campaign ---------- */
function NewCampaign({ onClose, onCreate }) {
  const [when, setWhen] = useState("schedule");
  return (
    <Modal onClose={onClose} width={580}>
      <div className="rl-modal__head">
        <div className="rl-modal__icon rl-modal__icon--brand"><Icon name="megaphone" size={20} /></div>
        <div><div className="rl-modal__title">New WhatsApp campaign</div><div className="muted rl-sm" style={{ marginTop: 2 }}>Send an approved template to an audience.</div></div>
        <button className="rl-iconbtn rl-modal__close" onClick={onClose}><Icon name="x" size={18} /></button>
      </div>
      <div className="rl-modal__body">
        <div className="rl-field" style={{ marginBottom: 14 }}><label className="rl-label">Campaign name <span className="rl-req">*</span></label><input className="rl-input" placeholder="e.g. June re-engagement" /></div>
        <div className="grid grid-2" style={{ gap: 14, marginBottom: 14 }}>
          <div className="rl-field"><label className="rl-label">Audience</label><select className="rl-select">{RX.GROUPS.map((g) => <option key={g.id}>{g.name} ({g.count})</option>)}</select></div>
          <div className="rl-field"><label className="rl-label">Template</label><select className="rl-select">{RX.TEMPLATES.filter((t) => t.channel === "whatsapp" && t.status === "approved").map((t) => <option key={t.id}>{t.name}</option>)}</select></div>
        </div>
        <div className="rl-field" style={{ marginBottom: 8 }}><label className="rl-label">When to send</label>
          <div className="row" style={{ gap: 8 }}>
            <button className={cx("rl-chip", when === "now" && "is-active")} onClick={() => setWhen("now")} style={{ height: 36 }}><Icon name="zap" size={14} />Send now</button>
            <button className={cx("rl-chip", when === "schedule" && "is-active")} onClick={() => setWhen("schedule")} style={{ height: 36 }}><Icon name="clock" size={14} />Schedule</button>
          </div>
        </div>
        {when === "schedule" && <div className="grid grid-2" style={{ gap: 14 }}>
          <div className="rl-field"><label className="rl-label">Date</label><input className="rl-input" type="date" /></div>
          <div className="rl-field"><label className="rl-label">Time</label><input className="rl-input" type="time" defaultValue="09:00" /></div>
        </div>}
      </div>
      <div className="rl-modal__foot">
        <button className="rl-btn rl-btn--ghost" onClick={onClose}>Cancel</button>
        <button className="rl-btn rl-btn--primary" onClick={onCreate}><Icon name={when === "now" ? "send" : "calendar-check"} size={15} />{when === "now" ? "Send campaign" : "Schedule campaign"}</button>
      </div>
    </Modal>
  );
}

window.ViewOutreach = ViewOutreach;
