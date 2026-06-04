/* ============================================================
   Relay app — Leads: dense filterable list, bulk actions,
   CSV import (upload -> column map -> import), add-lead modal.
   ============================================================ */

function LeadFilters({ q, setQ, status, setStatus, owner, setOwner, source, setSource, count }) {
  const app = useApp();
  return (
    <div className="filterbar">
      <div className="rl-inputwrap" style={{ width: 280 }}>
        <span className="rl-affix"><Icon name="search" size={16} /></span>
        <input className="rl-input" placeholder="Search name, company, email…" value={q} onChange={(e) => setQ(e.target.value)} />
      </div>
      <select className="rl-select" style={{ width: 150 }} value={status} onChange={(e) => setStatus(e.target.value)}>
        <option value="">All statuses</option>
        {Object.keys(RX.STATUS).map((s) => <option key={s} value={s}>{s}</option>)}
      </select>
      <select className="rl-select" style={{ width: 150 }} value={source} onChange={(e) => setSource(e.target.value)}>
        <option value="">All sources</option>
        {Object.keys(RX.SOURCE).map((s) => <option key={s} value={s}>{s}</option>)}
      </select>
      {app.role !== "associate" && <select className="rl-select" style={{ width: 150 }} value={owner} onChange={(e) => setOwner(e.target.value)}>
        <option value="">All owners</option>
        <option value="me">Owned by me</option>
        {RX.REP_IDS.map((id) => <option key={id} value={id}>{RX.USERS[id].name}</option>)}
      </select>}
      <div className="grow" />
      <span className="muted rl-sm nowrap">{count} leads</span>
      <button className="rl-iconbtn rl-iconbtn--bordered" title="Saved views"><Icon name="bookmark" size={16} /></button>
    </div>
  );
}

function ViewLeads() {
  const app = useApp();
  const { navigate, toast, role, me, startCall, stateMode } = app;
  const params = app.route.params;
  const [q, setQ] = useState("");
  const [status, setStatus] = useState("");
  const [owner, setOwner] = useState("");
  const [source, setSource] = useState("");
  const [sel, setSel] = useState({});
  const [sort, setSort] = useState({ k: "score", dir: -1 });
  const [addOpen, setAddOpen] = useState(!!params.add);
  const [importOpen, setImportOpen] = useState(!!params.importCsv);
  const [leads, setLeads] = useState(RX.ALL_LEADS);

  useEffect(() => { if (params.add) setAddOpen(true); if (params.importCsv) setImportOpen(true); }, [params]);

  const filtered = useMemo(() => {
    let r = leads.filter((l) => {
      if (q && !(l.name + l.company + l.email).toLowerCase().includes(q.toLowerCase())) return false;
      if (status && l.status !== status) return false;
      if (source && l.source !== source) return false;
      if (owner === "me" && l.owner !== me.id) return false;
      if (owner && owner !== "me" && l.owner !== owner) return false;
      return true;
    });
    r = [...r].sort((a, b) => { const av = a[sort.k], bv = b[sort.k]; return (av > bv ? 1 : av < bv ? -1 : 0) * sort.dir; });
    return r;
  }, [leads, q, status, source, owner, sort, me]);

  const selIds = Object.keys(sel).filter((k) => sel[k]);
  const allChecked = filtered.length > 0 && filtered.every((l) => sel[l.id]);
  const toggleAll = () => { if (allChecked) setSel({}); else { const n = {}; filtered.forEach((l) => n[l.id] = true); setSel(n); } };
  const setSortK = (k) => setSort((s) => s.k === k ? { k, dir: -s.dir } : { k, dir: 1 });

  const bulk = (label) => { toast(label + " · " + selIds.length + " leads", "success"); setSel({}); };

  return (
    <div className="page page--wide">
      <div className="pagehead">
        <div>
          <div className="pagehead__title">Leads</div>
          <div className="pagehead__sub">Your book of {RX.ALL_LEADS.filter((l) => role === "associate" ? l.owner === me.id : true).length} leads · color-coded by status, scored, multi-channel.</div>
        </div>
        <div className="pagehead__actions">
          <button className="rl-btn rl-btn--secondary" onClick={() => setImportOpen(true)}><Icon name="upload" size={15} />Import CSV</button>
          <button className="rl-btn rl-btn--secondary"><Icon name="download" size={15} />Export</button>
          <button className="rl-btn rl-btn--primary" onClick={() => setAddOpen(true)}><Icon name="user-plus" size={15} />Add lead</button>
        </div>
      </div>

      <LeadFilters q={q} setQ={setQ} status={status} setStatus={setStatus} owner={owner} setOwner={setOwner} source={source} setSource={setSource} count={filtered.length} />

      <div className="rl-table-wrap">
        {selIds.length > 0 && (
          <div className="rl-bulkbar">
            <span><b>{selIds.length}</b> selected</span>
            <div className="row" style={{ gap: 6 }}>
              <button className="rl-btn rl-btn--secondary rl-btn--sm" onClick={() => bulk("Assigned")}><Icon name="user-check" size={14} />Assign</button>
              <button className="rl-btn rl-btn--secondary rl-btn--sm" onClick={() => bulk("Status changed")}><Icon name="tag" size={14} />Set status</button>
              <button className="rl-btn rl-btn--secondary rl-btn--sm" onClick={() => bulk("Added to campaign")}><Icon name="megaphone" size={14} />Add to campaign</button>
              <button className="rl-btn rl-btn--secondary rl-btn--sm" onClick={() => bulk("Exported")}><Icon name="download" size={14} />Export</button>
              <button className="rl-btn rl-btn--ghost rl-btn--sm" onClick={() => setSel({})}>Clear</button>
            </div>
          </div>
        )}
        {stateMode === "loading" ? <SkeletonRows rows={10} /> :
          stateMode === "empty" || filtered.length === 0 ? <Empty icon="users" title="No leads match" body="Try clearing filters, or import a fresh list to get started." action={<button className="rl-btn rl-btn--primary rl-btn--sm" onClick={() => setImportOpen(true)}>Import CSV</button>} /> :
            <div className="rl-table-scroll">
              <table className="rl-table">
                <thead>
                  <tr>
                    <th style={{ width: 40 }}><label className="rl-check"><input type="checkbox" checked={allChecked} onChange={toggleAll} /><span className="rl-box">{allChecked && <Icon name="check" size={13} />}</span></label></th>
                    <th className="is-sortable" onClick={() => setSortK("name")}><span className="rl-sort">Lead <Icon name="chevrons-up-down" size={13} /></span></th>
                    <th>Channels</th>
                    <th className="is-sortable" onClick={() => setSortK("status")}>Status</th>
                    <th className="is-sortable" onClick={() => setSortK("score")}><span className="rl-sort">Score <Icon name="chevrons-up-down" size={13} /></span></th>
                    <th>Source</th>
                    <th>Owner</th>
                    <th className="is-sortable" onClick={() => setSortK("value")} style={{ textAlign: "right" }}>Value</th>
                    <th>Local time</th>
                    <th style={{ width: 44 }}></th>
                  </tr>
                </thead>
                <tbody>
                  {filtered.map((l) => (
                    <tr key={l.id} className={sel[l.id] ? "is-selected" : ""}>
                      <td onClick={(e) => e.stopPropagation()}><label className="rl-check"><input type="checkbox" checked={!!sel[l.id]} onChange={() => setSel((s) => ({ ...s, [l.id]: !s[l.id] }))} /><span className="rl-box">{sel[l.id] && <Icon name="check" size={13} />}</span></label></td>
                      <td className="clickable" onClick={() => navigate("lead", { key: l.key })}>
                        <div className="row" style={{ gap: 10 }}>
                          <Avatar name={l.name} av={"rl-avatar--c" + ((l.name.length % 5) + 1)} size="sm" />
                          <div style={{ minWidth: 0 }}>
                            <div className="rl-cell-strong">{l.name} {l.unread > 0 && <span className="rl-convo__unread" style={{ marginLeft: 4, verticalAlign: "middle" }}>{l.unread}</span>}</div>
                            <div className="muted" style={{ fontSize: 12 }}>{l.title} · {l.company}</div>
                          </div>
                        </div>
                      </td>
                      <td>
                        <div className="row" style={{ gap: 4 }}>
                          <ChannelPip type="call" />
                          {l.whatsapp && <ChannelPip type="whatsapp" />}
                          <ChannelPip type="email" />
                          {l.linkedin && <ChannelPip type="linkedin" />}
                        </div>
                      </td>
                      <td><StatusPill status={l.status} /></td>
                      <td><Score value={l.score} /></td>
                      <td><SourceMini source={l.source} /></td>
                      <td>{l.owner ? <div className="rl-tooltip"><Avatar user={RX.USERS[l.owner]} size="xs" /></div> : <span className="rl-badge rl-badge--warning">Unassigned</span>}</td>
                      <td className="rl-cell-num">{RX.money(l.value)}</td>
                      <td><div className="row" style={{ gap: 6 }}><span className="mono" style={{ fontSize: 12 }}>{l.local}</span><span className="muted" style={{ fontSize: 11 }}>{l.tz}</span></div></td>
                      <td onClick={(e) => e.stopPropagation()}>
                        <Dropdown align="right" trigger={(o, t) => <button className="rl-iconbtn rl-iconbtn--sm" onClick={t}><Icon name="more-horizontal" size={16} /></button>}>
                          <div className="rl-menuitem" onClick={() => navigate("lead", { key: l.key })}><Icon name="square-arrow-out-up-right" />Open workspace</div>
                          <div className="rl-menuitem" onClick={() => startCall(l)}><Icon name="phone" />Call now</div>
                          <div className="rl-menuitem"><Icon name="user-check" />Assign…</div>
                          <div className="rl-menuitem"><Icon name="tag" />Change status</div>
                          <div className="rl-menu__sep" />
                          <div className="rl-menuitem is-danger"><Icon name="archive" />Archive</div>
                        </Dropdown>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>}
        {filtered.length > 0 && stateMode === "normal" && (
          <div className="rl-pagination">
            <span>Showing 1–{filtered.length} of {filtered.length}</span>
            <div className="rl-pagebtns">
              <button className="rl-pagebtn"><Icon name="chevron-left" size={15} /></button>
              <button className="rl-pagebtn is-active">1</button>
              <button className="rl-pagebtn">2</button>
              <button className="rl-pagebtn">3</button>
              <button className="rl-pagebtn"><Icon name="chevron-right" size={15} /></button>
            </div>
          </div>
        )}
      </div>

      {addOpen && <AddLeadModal onClose={() => setAddOpen(false)} onSave={() => { setAddOpen(false); toast("Lead added", "success"); }} />}
      {importOpen && <ImportModal onClose={() => setImportOpen(false)} onDone={(n) => { setImportOpen(false); toast(n + " leads imported", "success"); }} />}
    </div>
  );
}

/* ---------- Add lead modal ---------- */
function AddLeadModal({ onClose, onSave }) {
  return (
    <Modal onClose={onClose} width={560}>
      <div className="rl-modal__head">
        <div className="rl-modal__icon rl-modal__icon--brand"><Icon name="user-plus" size={20} /></div>
        <div><div className="rl-modal__title">Add lead</div><div className="muted rl-sm" style={{ marginTop: 2 }}>Create a single lead manually.</div></div>
        <button className="rl-iconbtn rl-modal__close" onClick={onClose}><Icon name="x" size={18} /></button>
      </div>
      <div className="rl-modal__body">
        <div className="grid grid-2" style={{ gap: 14 }}>
          <div className="rl-field"><label className="rl-label">Full name <span className="rl-req">*</span></label><input className="rl-input" placeholder="Jordan Avery" /></div>
          <div className="rl-field"><label className="rl-label">Company <span className="rl-req">*</span></label><input className="rl-input" placeholder="Acme Inc" /></div>
          <div className="rl-field"><label className="rl-label">Email</label><input className="rl-input" placeholder="jordan@acme.com" /></div>
          <div className="rl-field"><label className="rl-label">Phone</label><input className="rl-input" placeholder="+1 555 0100" /></div>
          <div className="rl-field"><label className="rl-label">Source</label><select className="rl-select">{Object.keys(RX.SOURCE).map((s) => <option key={s}>{s}</option>)}</select></div>
          <div className="rl-field"><label className="rl-label">Owner</label><select className="rl-select"><option>Assign to me</option>{RX.REP_IDS.map((id) => <option key={id}>{RX.USERS[id].name}</option>)}<option>Leave unassigned</option></select></div>
        </div>
        <div className="rl-field" style={{ marginTop: 14 }}><label className="rl-label">Notes</label><textarea className="rl-textarea" placeholder="Context from first touch…" /></div>
      </div>
      <div className="rl-modal__foot">
        <button className="rl-btn rl-btn--ghost" onClick={onClose}>Cancel</button>
        <button className="rl-btn rl-btn--primary" onClick={onSave}><Icon name="check" size={15} />Add lead</button>
      </div>
    </Modal>
  );
}

/* ---------- CSV import: upload -> map -> import ---------- */
const CSV_COLS = ["Full name", "Company", "Email", "Phone", "Job title", "Source", "Country"];
const RELAY_FIELDS = ["name", "company", "email", "phone", "title", "source", "country", "— skip —"];
function ImportModal({ onClose, onDone }) {
  const [step, setStep] = useState(0); // 0 upload, 1 map, 2 importing, 3 done
  const [map, setMap] = useState(() => { const m = {}; CSV_COLS.forEach((c, i) => m[c] = RELAY_FIELDS[i] || "— skip —"); return m; });
  const [pct, setPct] = useState(0);
  const rows = 248;
  useEffect(() => { if (step !== 2) return; setPct(0); const t = setInterval(() => setPct((p) => { if (p >= 100) { clearInterval(t); setStep(3); return 100; } return p + 8; }), 110); return () => clearInterval(t); }, [step]);

  return (
    <Modal onClose={onClose} width={640}>
      <div className="rl-modal__head">
        <div className="rl-modal__icon rl-modal__icon--brand"><Icon name="upload" size={20} /></div>
        <div><div className="rl-modal__title">Import leads from CSV</div><div className="muted rl-sm" style={{ marginTop: 2 }}>Step {Math.min(step + 1, 3)} of 3 · {["Upload", "Map columns", "Importing", "Done"][step]}</div></div>
        <button className="rl-iconbtn rl-modal__close" onClick={onClose}><Icon name="x" size={18} /></button>
      </div>
      <div className="rl-modal__body">
        {step === 0 && <>
          <div onClick={() => setStep(1)} className="clickable" style={{ border: "2px dashed var(--color-border-strong)", borderRadius: "var(--radius-lg)", padding: 36, textAlign: "center", background: "var(--color-surface-2)" }}>
            <div className="empty__ic" style={{ margin: "0 auto 12px" }}><Icon name="file-up" size={26} /></div>
            <div className="rl-h4">Drop a CSV here, or click to browse</div>
            <div className="muted rl-sm" style={{ marginTop: 4 }}>Up to 10,000 rows · .csv up to 20 MB</div>
          </div>
          <div className="row" style={{ gap: 8, marginTop: 14, color: "var(--color-fg-3)", fontSize: 13 }}><Icon name="info" size={15} />First row should contain column headers.</div>
        </>}
        {step === 1 && <>
          <div className="row spread" style={{ marginBottom: 12 }}>
            <div className="row" style={{ gap: 8 }}><Icon name="file-check-2" size={18} style={{ color: "var(--color-success)" }} /><b className="rl-sm">leads_q2_export.csv</b><span className="rl-badge">{rows} rows</span></div>
            <button className="rl-btn rl-btn--ghost rl-btn--sm" onClick={() => setStep(0)}>Replace</button>
          </div>
          <div style={{ border: "1px solid var(--color-border)", borderRadius: "var(--radius-md)", overflow: "hidden" }}>
            <div className="spread" style={{ padding: "8px 14px", background: "var(--color-surface-2)", borderBottom: "1px solid var(--color-border)", fontSize: 12, fontWeight: 700, color: "var(--color-fg-3)", textTransform: "uppercase", letterSpacing: ".04em" }}><span>CSV column</span><span>Maps to Relay field</span></div>
            {CSV_COLS.map((c) => (
              <div className="spread" key={c} style={{ padding: "9px 14px", borderBottom: "1px solid var(--color-divider)" }}>
                <span className="row" style={{ gap: 8 }}><Icon name="columns-2" size={15} style={{ color: "var(--color-fg-4)" }} /><b className="rl-sm">{c}</b></span>
                <select className="rl-select rl-input--sm" style={{ width: 180 }} value={map[c]} onChange={(e) => setMap((m) => ({ ...m, [c]: e.target.value }))}>
                  {RELAY_FIELDS.map((f) => <option key={f}>{f}</option>)}
                </select>
              </div>
            ))}
          </div>
        </>}
        {step === 2 && <div style={{ padding: "20px 0" }}>
          <div className="row spread" style={{ marginBottom: 10 }}><b className="rl-sm">Importing {rows} leads…</b><span className="mono rl-sm">{pct}%</span></div>
          <div className="rl-progress"><i style={{ width: pct + "%" }} /></div>
          <div className="muted rl-sm" style={{ marginTop: 10 }}>Deduplicating by email · assigning round-robin · enriching timezones.</div>
        </div>}
        {step === 3 && <div style={{ textAlign: "center", padding: "16px 0" }}>
          <div className="empty__ic" style={{ margin: "0 auto 12px", background: "var(--color-success-subtle)", borderColor: "var(--color-success-border)", color: "var(--color-success-text)" }}><Icon name="check" size={28} /></div>
          <div className="rl-h3">241 leads imported</div>
          <div className="muted rl-sm" style={{ marginTop: 6 }}>7 duplicates skipped · 241 assigned across 4 reps.</div>
        </div>}
      </div>
      <div className="rl-modal__foot">
        {step === 1 && <button className="rl-btn rl-btn--ghost" onClick={() => setStep(0)}>Back</button>}
        <button className="rl-btn rl-btn--ghost" onClick={onClose}>{step === 3 ? "Close" : "Cancel"}</button>
        {step === 0 && <button className="rl-btn rl-btn--secondary" onClick={() => setStep(1)}>Use sample file</button>}
        {step === 1 && <button className="rl-btn rl-btn--primary" onClick={() => setStep(2)}><Icon name="upload" size={15} />Import {rows} leads</button>}
        {step === 3 && <button className="rl-btn rl-btn--primary" onClick={() => onDone(241)}>Done</button>}
      </div>
    </Modal>
  );
}

window.ViewLeads = ViewLeads;
