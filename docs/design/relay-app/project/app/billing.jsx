/* ============================================================
   Relay app — Money: cost estimator, Odoo proposal, invoices,
   and the Quotes & invoices workspace.
   ============================================================ */

/* ---------- AI cost estimator -> PDF proposal ---------- */
const SERVICES = {
  pilot: { label: "Outbound pilot (3 mo)", base: 4500, unit: "rep / mo" },
  retainer: { label: "Full outbound retainer", base: 6000, unit: "rep / mo" },
  paid: { label: "Paid media management", base: 3200, unit: "channel / mo" },
};
function EstimatorModal({ lead, onClose }) {
  const app = useApp();
  const [service, setService] = useState("pilot");
  const [reps, setReps] = useState(2);
  const [months, setMonths] = useState(3);
  const [channels, setChannels] = useState({ call: true, whatsapp: true, email: true, linkedin: false });
  const [setup, setSetup] = useState(true);
  const [done, setDone] = useState(false);
  const chanCost = Object.values(channels).filter(Boolean).length * 350;
  const monthly = SERVICES[service].base * reps + chanCost;
  const setupFee = setup ? 2500 : 0;
  const total = monthly * months + setupFee;

  return (
    <Modal onClose={onClose} width={640}>
      <div className="rl-modal__head">
        <div className="rl-modal__icon rl-modal__icon--brand"><Icon name="calculator" size={20} /></div>
        <div><div className="rl-modal__title">Cost estimate</div><div className="muted rl-sm" style={{ marginTop: 2 }}>{lead ? lead.company : "New estimate"} · auto-priced from your rate card</div></div>
        <button className="rl-iconbtn rl-modal__close" onClick={onClose}><Icon name="x" size={18} /></button>
      </div>
      {!done ? <>
        <div className="rl-modal__body">
          <div className="rl-field" style={{ marginBottom: 14 }}>
            <label className="rl-label">Service</label>
            <div className="row" style={{ gap: 8 }}>
              {Object.entries(SERVICES).map(([k, v]) => (
                <button key={k} className={cx("rl-chip", service === k && "is-active")} onClick={() => setService(k)} style={{ height: 36 }}>{v.label}</button>
              ))}
            </div>
          </div>
          <div className="grid grid-2" style={{ gap: 14, marginBottom: 14 }}>
            <div className="rl-field"><label className="rl-label">Reps assigned</label><div className="rl-stepper"><button onClick={() => setReps((r) => Math.max(1, r - 1))}><Icon name="minus" size={15} /></button><input value={reps} readOnly /><button onClick={() => setReps((r) => r + 1)}><Icon name="plus" size={15} /></button></div></div>
            <div className="rl-field"><label className="rl-label">Duration (months)</label><div className="rl-stepper"><button onClick={() => setMonths((m) => Math.max(1, m - 1))}><Icon name="minus" size={15} /></button><input value={months} readOnly /><button onClick={() => setMonths((m) => m + 1)}><Icon name="plus" size={15} /></button></div></div>
          </div>
          <div className="rl-field" style={{ marginBottom: 14 }}>
            <label className="rl-label">Channels included</label>
            <div className="row" style={{ gap: 14, flexWrap: "wrap" }}>
              {[["call", "Calls"], ["whatsapp", "WhatsApp"], ["email", "Email"], ["linkedin", "LinkedIn"]].map(([k, l]) => (
                <label className="rl-check" key={k}><input type="checkbox" checked={channels[k]} onChange={() => setChannels((c) => ({ ...c, [k]: !c[k] }))} /><span className="rl-box">{channels[k] && <Icon name="check" size={13} />}</span>{l}</label>
              ))}
            </div>
          </div>
          <label className="rl-check" style={{ marginBottom: 4 }}><input type="checkbox" checked={setup} onChange={() => setSetup((s) => !s)} /><span className="rl-box">{setup && <Icon name="check" size={13} />}</span>One-time setup &amp; onboarding ($2,500)</label>

          <div style={{ marginTop: 16, background: "var(--color-surface-2)", border: "1px solid var(--color-border)", borderRadius: "var(--radius-md)", padding: 16 }}>
            <div className="kvline"><dt>Monthly ({reps} reps · {Object.values(channels).filter(Boolean).length} channels)</dt><dd className="mono">{RX.money(monthly)}</dd></div>
            <div className="kvline"><dt>× {months} months</dt><dd className="mono">{RX.money(monthly * months)}</dd></div>
            {setup && <div className="kvline"><dt>Setup fee</dt><dd className="mono">{RX.money(setupFee)}</dd></div>}
            <div className="kvline" style={{ borderTop: "1px solid var(--color-border-strong)", marginTop: 4, paddingTop: 10 }}><dt style={{ fontWeight: 700, color: "var(--color-fg)" }}>Total contract value</dt><dd style={{ fontFamily: "var(--font-display)", fontWeight: 800, fontSize: 22 }}>{RX.money(total)}</dd></div>
          </div>
        </div>
        <div className="rl-modal__foot">
          <button className="rl-btn rl-btn--ghost" onClick={onClose}>Cancel</button>
          <button className="rl-btn rl-btn--secondary" onClick={() => app.toast("Saved as draft estimate", "success")}><Icon name="save" size={15} />Save draft</button>
          <button className="rl-btn rl-btn--primary" onClick={() => setDone(true)}><Icon name="sparkles" size={15} />Generate proposal PDF</button>
        </div>
      </> : <GeneratedDoc kind="estimate" title="Cost estimate ready" sub={"3-month outbound pilot · " + RX.money(total)} onClose={onClose} />}
    </Modal>
  );
}

/* ---------- Odoo proposal (AI narrative -> branded PDF) ---------- */
function ProposalModal({ lead, onClose }) {
  const [phase, setPhase] = useState("config"); // config | generating | done
  const [tone, setTone] = useState("Consultative");
  const [pct, setPct] = useState(0);
  useEffect(() => { if (phase !== "generating") return; setPct(0); const t = setInterval(() => setPct((p) => { if (p >= 100) { clearInterval(t); setPhase("done"); return 100; } return p + 7; }), 130); return () => clearInterval(t); }, [phase]);
  return (
    <Modal onClose={onClose} width={620}>
      <div className="rl-modal__head">
        <div className="rl-modal__icon rl-modal__icon--brand"><Icon name="file-text" size={20} /></div>
        <div><div className="rl-modal__title">Odoo proposal</div><div className="muted rl-sm" style={{ marginTop: 2 }}>AI writes the narrative · exports a branded PDF to Odoo</div></div>
        <button className="rl-iconbtn rl-modal__close" onClick={onClose}><Icon name="x" size={18} /></button>
      </div>
      <div className="rl-modal__body">
        {phase === "config" && <>
          <div className="grid grid-2" style={{ gap: 14, marginBottom: 14 }}>
            <div className="rl-field"><label className="rl-label">Template</label><select className="rl-select"><option>Outbound pilot — 3 month</option><option>Full retainer — annual</option><option>Paid media — quarterly</option></select></div>
            <div className="rl-field"><label className="rl-label">Tone of voice</label><select className="rl-select" value={tone} onChange={(e) => setTone(e.target.value)}><option>Consultative</option><option>Confident</option><option>Concise</option><option>Warm</option></select></div>
          </div>
          <div className="rl-field" style={{ marginBottom: 8 }}><label className="rl-label">What should the AI emphasise?</label><textarea className="rl-textarea" defaultValue={"Northwind needs outbound capacity for their Q3 product launch without hiring SDRs. Emphasise speed-to-pipeline, our managed model, and the Brightside case study (similar ICP)."} /></div>
          <div className="row" style={{ gap: 8, color: "var(--color-fg-3)", fontSize: 13 }}><Icon name="info" size={15} />Pulls company, contact, deal value and your notes automatically.</div>
        </>}
        {phase === "generating" && <div style={{ padding: "24px 0", textAlign: "center" }}>
          <div className="rl-spinner" style={{ width: 30, height: 30, margin: "0 auto 16px" }} />
          <b>Writing your proposal…</b>
          <div className="muted rl-sm" style={{ marginTop: 6 }}>{pct < 40 ? "Drafting executive summary" : pct < 75 ? "Building scope & pricing tables" : "Applying Meridian branding"}</div>
          <div className="rl-progress" style={{ maxWidth: 320, margin: "16px auto 0" }}><i style={{ width: pct + "%" }} /></div>
        </div>}
        {phase === "done" && <GeneratedDocBody kind="proposal" title="Proposal generated" sub={(lead ? lead.company : "Client") + " — outbound pilot · 6 pages"} />}
      </div>
      <div className="rl-modal__foot">
        <button className="rl-btn rl-btn--ghost" onClick={onClose}>{phase === "done" ? "Close" : "Cancel"}</button>
        {phase === "config" && <button className="rl-btn rl-btn--primary" onClick={() => setPhase("generating")}><Icon name="sparkles" size={15} />Generate with AI</button>}
        {phase === "done" && <><button className="rl-btn rl-btn--secondary"><Icon name="download" size={15} />Download PDF</button><button className="rl-btn rl-btn--primary"><Icon name="send" size={15} />Send to client</button></>}
      </div>
    </Modal>
  );
}

/* ---------- Invoice ---------- */
function InvoiceModal({ lead, onClose }) {
  const app = useApp();
  const [paid, setPaid] = useState(false);
  const items = [
    { label: "Outbound pilot — month 1", amt: 16000 },
    { label: "One-time setup & onboarding", amt: 2500 },
  ];
  const total = items.reduce((s, i) => s + i.amt, 0);
  return (
    <Modal onClose={onClose} width={600}>
      <div className="rl-modal__head">
        <div className="rl-modal__icon rl-modal__icon--brand"><Icon name="receipt" size={20} /></div>
        <div><div className="rl-modal__title">Invoice · INV-2044</div><div className="muted rl-sm" style={{ marginTop: 2 }}>{lead ? lead.company : "Client"} · due in 14 days</div></div>
        <button className="rl-iconbtn rl-modal__close" onClick={onClose}><Icon name="x" size={18} /></button>
      </div>
      <div className="rl-modal__body">
        <div style={{ border: "1px solid var(--color-border)", borderRadius: "var(--radius-md)", overflow: "hidden", marginBottom: 14 }}>
          {items.map((it, i) => <div className="spread" key={i} style={{ padding: "12px 14px", borderBottom: "1px solid var(--color-divider)" }}><span className="rl-sm">{it.label}</span><span className="mono" style={{ fontWeight: 600 }}>{RX.money(it.amt)}</span></div>)}
          <div className="spread" style={{ padding: "12px 14px", background: "var(--color-surface-2)" }}><b>Total due</b><b className="mono" style={{ fontSize: 18 }}>{RX.money(total)}</b></div>
        </div>
        <div className="spread" style={{ padding: "10px 12px", background: "var(--color-surface-2)", border: "1px solid var(--color-border)", borderRadius: "var(--radius-md)" }}>
          <div className="row" style={{ gap: 8 }}><Icon name="link" size={16} style={{ color: "var(--color-fg-3)" }} /><span className="mono rl-sm">pay.meridiangrowth.co/inv-2044</span></div>
          <div className="row" style={{ gap: 6 }}>
            <button className="rl-btn rl-btn--ghost rl-btn--sm" onClick={() => app.toast("Public link copied", "success")}><Icon name="copy" size={14} />Copy</button>
            <a className="rl-btn rl-btn--secondary rl-btn--sm" href="Invoice.html" target="_blank"><Icon name="external-link" size={14} />Preview</a>
          </div>
        </div>
        {paid && <div className="row" style={{ gap: 8, marginTop: 14, color: "var(--color-success-text)", fontWeight: 600 }}><Icon name="check-circle-2" size={18} />Marked as paid · receipt sent.</div>}
      </div>
      <div className="rl-modal__foot">
        <button className="rl-btn rl-btn--ghost" onClick={onClose}>Cancel</button>
        <button className="rl-btn rl-btn--secondary" onClick={() => { setPaid(true); app.toast("Invoice marked paid", "success"); }}><Icon name="check" size={15} />Mark paid</button>
        <button className="rl-btn rl-btn--primary" onClick={() => app.toast("Invoice sent to client", "success")}><Icon name="send" size={15} />Send invoice</button>
      </div>
    </Modal>
  );
}

function GeneratedDocBody({ kind, title, sub }) {
  return (
    <div style={{ textAlign: "center", padding: "8px 0" }}>
      <div style={{ width: 92, height: 116, margin: "0 auto 14px", borderRadius: 8, background: "var(--color-surface)", border: "1px solid var(--color-border)", boxShadow: "var(--shadow-md)", position: "relative", overflow: "hidden" }}>
        <div style={{ height: 26, background: "var(--color-primary)" }} />
        <div style={{ padding: 8, textAlign: "left" }}>{[80, 60, 70, 45, 65, 50].map((w, i) => <div key={i} style={{ height: 4, width: w + "%", background: "var(--color-surface-3)", borderRadius: 2, margin: "5px 0" }} />)}</div>
        <div style={{ position: "absolute", bottom: 6, right: 6, width: 22, height: 22, borderRadius: 5, background: "var(--color-primary-subtle)", display: "grid", placeItems: "center", color: "var(--color-primary-text)" }}><Icon name="check" size={13} /></div>
      </div>
      <div className="rl-h3">{title}</div>
      <div className="muted rl-sm" style={{ marginTop: 4 }}>{sub}</div>
    </div>
  );
}
function GeneratedDoc({ kind, title, sub, onClose }) {
  return (<>
    <div className="rl-modal__body"><GeneratedDocBody kind={kind} title={title} sub={sub} /></div>
    <div className="rl-modal__foot">
      <button className="rl-btn rl-btn--ghost" onClick={onClose}>Close</button>
      <button className="rl-btn rl-btn--secondary"><Icon name="download" size={15} />Download PDF</button>
      <button className="rl-btn rl-btn--primary"><Icon name="send" size={15} />Send to client</button>
    </div>
  </>);
}

/* ---------- Quotes & invoices workspace ---------- */
function ViewBilling() {
  const app = useApp();
  const params = app.route.params;
  const [tab, setTab] = useState(params.tab === "estimate" ? "invoices" : "invoices");
  const [openModal, setOpenModal] = useState(params.tab === "estimate" ? "estimate" : null);
  const [invoices, setInvoices] = useState(RX.INVOICES);
  const markPaid = (id) => { setInvoices((v) => v.map((x) => x.id === id ? { ...x, status: "paid" } : x)); app.toast("Invoice marked paid", "success"); };

  const outstanding = invoices.filter((i) => i.status === "sent" || i.status === "overdue").reduce((s, i) => s + i.amount, 0);
  const paidThisMo = invoices.filter((i) => i.status === "paid").reduce((s, i) => s + i.amount, 0);

  return (
    <div className="page page--wide">
      <div className="pagehead">
        <div><div className="pagehead__title">Quotes &amp; invoices</div><div className="pagehead__sub">Estimates, proposals, milestones and invoices — money actions across your book.</div></div>
        <div className="pagehead__actions">
          <button className="rl-btn rl-btn--secondary" onClick={() => setOpenModal("estimate")}><Icon name="calculator" size={15} />New estimate</button>
          <button className="rl-btn rl-btn--primary" onClick={() => setOpenModal("invoice")}><Icon name="receipt" size={15} />New invoice</button>
        </div>
      </div>

      <div className="grid grid-4" style={{ marginBottom: "var(--space-6)" }}>
        <Stat label="Outstanding" value={RX.money(outstanding)} icon="hourglass" />
        <Stat label="Paid this month" value={RX.money(paidThisMo)} delta={18} deltaSuffix="%" icon="check-circle-2" sparkColor="var(--cat-2)" spark={[3, 5, 4, 8, 7, 10, 9, 12, 11, 14, 13, 16]} />
        <Stat label="Overdue" value={RX.money(invoices.filter((i) => i.status === "overdue").reduce((s, i) => s + i.amount, 0))} icon="alert-triangle" />
        <Stat label="Avg. days to pay" value="11" icon="calendar-clock" />
      </div>

      <div className="rl-tabs" style={{ marginBottom: "var(--space-5)" }}>
        {[["invoices", "Invoices", invoices.length], ["milestones", "Milestones", RX.MILESTONES.length], ["proposals", "Proposals", 3]].map(([id, label, n]) => (
          <button key={id} className={cx("rl-tab", tab === id && "is-active")} onClick={() => setTab(id)}>{label}<span className="rl-tab-count">{n}</span></button>
        ))}
      </div>

      {tab === "invoices" && <div className="rl-table-wrap">
        <table className="rl-table">
          <thead><tr><th>Invoice</th><th>Client</th><th>Linked deal</th><th>Issued</th><th>Due</th><th style={{ textAlign: "right" }}>Amount</th><th>Status</th><th></th></tr></thead>
          <tbody>
            {invoices.map((inv) => (
              <tr key={inv.id}>
                <td className="rl-cell-strong mono">{inv.id}</td>
                <td>{inv.client}</td>
                <td className="muted">{inv.deal}</td>
                <td className="mono rl-sm">{inv.issued}</td>
                <td className="mono rl-sm">{inv.due}</td>
                <td className="rl-cell-num">{RX.money(inv.amount)}</td>
                <td><span className={cx("rl-badge", RX.INVOICE_STATUS[inv.status])} style={{ textTransform: "capitalize" }}>{inv.status}</span></td>
                <td>
                  <div className="row" style={{ gap: 4, justifyContent: "flex-end" }}>
                    {inv.status !== "paid" && <button className="rl-btn rl-btn--ghost rl-btn--sm" onClick={() => markPaid(inv.id)}>Mark paid</button>}
                    <a className="rl-iconbtn rl-iconbtn--sm" href="Invoice.html" target="_blank" title="Public page"><Icon name="external-link" size={15} /></a>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>}

      {tab === "milestones" && <div className="sect"><div className="sect__body--flush">
        {RX.MILESTONES.map((m) => (
          <div className="rl-listitem" key={m.id}>
            <span className="iccircle" style={{ background: m.status === "paid" ? "var(--color-success-subtle)" : "var(--color-surface-2)", color: m.status === "paid" ? "var(--color-success-text)" : "var(--color-fg-3)" }}><Icon name={m.status === "paid" ? "check" : "flag"} size={16} /></span>
            <div className="rl-listitem__main"><div className="rl-listitem__title">{m.label}</div><div className="rl-listitem__sub">Northwind pilot · due {m.due}</div></div>
            <span className="mono" style={{ fontWeight: 700 }}>{RX.money(m.amount)}</span>
            <span className={cx("rl-badge", RX.INVOICE_STATUS[m.status])} style={{ textTransform: "capitalize" }}>{m.status}</span>
          </div>
        ))}
      </div></div>}

      {tab === "proposals" && <div className="grid grid-3">
        {[["Northwind Labs", "Outbound pilot", "Sent", "rl-badge--info"], ["Cobalt Health", "EU expansion", "Draft", "rl-badge--neutral"], ["Lumen Robotics", "APAC pilot", "Viewed", "rl-badge--success"]].map(([c, t, s, b], i) => (
          <div className="sect" key={i}><div className="sect__body">
            <div className="spread" style={{ marginBottom: 12 }}><span className="iccircle" style={{ background: "var(--color-primary-subtle)", color: "var(--color-primary-text)" }}><Icon name="file-text" size={18} /></span><span className={cx("rl-badge", b)}>{s}</span></div>
            <div className="rl-h4">{c}</div><div className="muted rl-sm">{t} · 6 pages</div>
            <div className="row" style={{ gap: 6, marginTop: 14 }}><button className="rl-btn rl-btn--secondary rl-btn--sm"><Icon name="eye" size={14} />Open</button><button className="rl-btn rl-btn--ghost rl-btn--sm"><Icon name="download" size={14} />PDF</button></div>
          </div></div>
        ))}
      </div>}

      {openModal === "estimate" && <EstimatorModal lead={null} onClose={() => setOpenModal(null)} />}
      {openModal === "invoice" && <InvoiceModal lead={null} onClose={() => setOpenModal(null)} />}
    </div>
  );
}

Object.assign(window, { EstimatorModal, ProposalModal, InvoiceModal, ViewBilling });
