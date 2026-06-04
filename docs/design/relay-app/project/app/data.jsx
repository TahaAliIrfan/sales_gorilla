/* ============================================================
   Relay app — mock data for the Meridian tenant.
   Meridian is a B2B growth & outbound agency that runs Relay
   white-labelled. Reps sell growth retainers to mid-market cos.
   Everything here is fictional. Exposed on window.RX.
   ============================================================ */

/* ---------------- Tenant ---------------- */
const TENANT = {
  name: "Meridian",
  product: "Meridian",
  tagline: "Growth, on tap.",
  brandKey: "teal",
  domain: "meridiangrowth.co",
};

/* ---------------- Users / reps ---------------- */
const USERS = {
  priya:  { id: "priya",  name: "Priya Shah",   first: "Priya",  initials: "PS", role: "associate", title: "Sales associate", av: "rl-avatar--c1", email: "priya@meridiangrowth.co", target: 40, presence: "online" },
  marcus: { id: "marcus", name: "Marcus Bell",  first: "Marcus", initials: "MB", role: "manager",   title: "Sales manager",   av: "rl-avatar--c5", email: "marcus@meridiangrowth.co", target: 0, presence: "online" },
  dana:   { id: "dana",   name: "Dana Okafor",  first: "Dana",   initials: "DO", role: "admin",     title: "Revenue operations", av: "rl-avatar--c4", email: "dana@meridiangrowth.co", target: 0, presence: "busy" },
  theo:   { id: "theo",   name: "Theo Marsh",   first: "Theo",   initials: "TM", role: "associate", title: "Sales associate", av: "av-c6", email: "theo@meridiangrowth.co", target: 35, presence: "away" },
  lena:   { id: "lena",   name: "Lena Vogt",    first: "Lena",   initials: "LV", role: "associate", title: "Sales associate", av: "av-c7", email: "lena@meridiangrowth.co", target: 38, presence: "online" },
  sam:    { id: "sam",    name: "Sam Rivera",   first: "Sam",    initials: "SR", role: "associate", title: "Sales associate", av: "rl-avatar--c2", email: "sam@meridiangrowth.co", target: 35, presence: "offline" },
};
const REP_IDS = ["priya", "theo", "lena", "sam"];

/* ---------------- Lead status + source meta ---------------- */
const STATUS = {
  New:       { pill: "rl-pill--info",    label: "New" },
  Working:   { pill: "rl-pill--brand",   label: "Working" },
  Qualified: { pill: "rl-pill--success", label: "Qualified" },
  Proposal:  { pill: "rl-pill--warning", label: "Proposal" },
  Won:       { pill: "rl-pill--success", label: "Won" },
  Lost:      { pill: "rl-pill--danger",  label: "Lost" },
  Nurture:   { pill: "",                 label: "Nurture" },
};
const SOURCE = {
  "LinkedIn Ads":  "var(--cat-1)",
  "Google Ads":    "var(--cat-3)",
  "Meta Ads":      "var(--cat-5)",
  "Referral":      "var(--cat-2)",
  "Webinar":       "var(--cat-6)",
  "Cold outbound": "var(--cat-7)",
  "Inbound form":  "var(--cat-8)",
};

function scoreColor(s) {
  if (s >= 75) return "var(--color-success)";
  if (s >= 50) return "var(--color-warning)";
  if (s >= 25) return "var(--cat-3)";
  return "var(--color-danger)";
}

/* ---------------- Leads ---------------- */
/* compact factory */
let _ln = 4800;
function lead(o) { return Object.assign({ id: "LEAD-" + (++_ln), docs: [], tags: [], unread: 0, whatsapp: true, linkedin: false }, o); }

const LEADS = [
  lead({ key: "maya", name: "Maya Brennan", company: "Northwind Labs", title: "VP Marketing", status: "Proposal", source: "LinkedIn Ads", score: 88, owner: "priya",
    city: "Austin, TX", country: "USA", tz: "CST", local: "10:42", pref: "Mornings (9–11 CST)", phone: "+1 512 555 0148", email: "maya.brennan@northwindlabs.com", whatsapp: true, linkedin: true,
    value: 48000, tags: ["Enterprise", "Warm"], lastTouch: "2h ago", lastChannel: "whatsapp", unread: 2, createdDays: 18,
    ad: { campaign: "Q2 — Demand Gen / DACH", adset: "VP Marketing · 200–500", keyword: "outbound agency", utm: "li_q2_demandgen" },
    docs: [{ name: "Northwind — discovery notes.pdf", size: "240 KB", kind: "pdf" }, { name: "Scope draft v2.docx", size: "88 KB", kind: "doc" }] }),
  lead({ key: "owen", name: "Owen Castellanos", company: "Bluefin Retail", title: "Head of Growth", status: "Qualified", source: "Referral", score: 79, owner: "priya",
    city: "Denver, CO", country: "USA", tz: "MST", local: "09:42", pref: "Afternoons", phone: "+1 303 555 0192", email: "owen@bluefinretail.com", whatsapp: true, linkedin: true,
    value: 36000, tags: ["Mid-market"], lastTouch: "Yesterday", lastChannel: "call", unread: 0, createdDays: 9,
    ad: { campaign: "Referral — partner", adset: "—", keyword: "—", utm: "ref_partner" } }),
  lead({ key: "sara", name: "Sara Lindqvist", company: "Cobalt Health", title: "CMO", status: "Working", source: "Webinar", score: 71, owner: "priya",
    city: "Stockholm", country: "Sweden", tz: "CET", local: "17:42", pref: "Early morning your time", phone: "+46 8 555 0144", email: "sara.l@cobalthealth.se", whatsapp: true, linkedin: true,
    value: 60000, tags: ["Enterprise", "EU"], lastTouch: "3h ago", lastChannel: "email", unread: 1, createdDays: 5,
    ad: { campaign: "Webinar — Scaling Outbound", adset: "Attendees", keyword: "—", utm: "web_scaling_q2" } }),
  lead({ key: "deshawn", name: "DeShawn Porter", company: "Arcadia Foods", title: "Director of Sales", status: "New", source: "Google Ads", score: 44, owner: "priya",
    city: "Chicago, IL", country: "USA", tz: "CST", local: "10:42", pref: "Unknown", phone: "+1 312 555 0177", email: "dporter@arcadiafoods.com", whatsapp: false, linkedin: false,
    value: 24000, tags: [], lastTouch: "5m ago", lastChannel: "system", unread: 0, createdDays: 0,
    ad: { campaign: "Search — Brand + Generic", adset: "outbound services", keyword: "b2b outbound agency", utm: "gads_generic" } }),
  lead({ key: "hiro", name: "Hiro Tanaka", company: "Vertex Logistics", title: "COO", status: "Working", source: "Cold outbound", score: 58, owner: "theo",
    city: "Singapore", country: "Singapore", tz: "SGT", local: "23:42", pref: "Late evening your time", phone: "+65 6555 0133", email: "h.tanaka@vertexlog.com", whatsapp: true, linkedin: true,
    value: 54000, tags: ["APAC"], lastTouch: "Yesterday", lastChannel: "whatsapp", unread: 0, createdDays: 22,
    ad: { campaign: "Outbound — APAC logistics", adset: "COO · 500+", keyword: "—", utm: "ob_apac" } }),
  lead({ key: "nadia", name: "Nadia Haddad", company: "Halcyon Media", title: "Founder", status: "Qualified", source: "Inbound form", score: 83, owner: "lena",
    city: "Dubai", country: "UAE", tz: "GST", local: "19:42", pref: "Afternoons GST", phone: "+971 4 555 0120", email: "nadia@halcyonmedia.ae", whatsapp: true, linkedin: false,
    value: 42000, tags: ["Founder-led"], lastTouch: "1h ago", lastChannel: "whatsapp", unread: 3, createdDays: 3,
    ad: { campaign: "Inbound — Website", adset: "—", keyword: "—", utm: "site_contact" } }),
  lead({ key: "greg", name: "Greg Mulligan", company: "Pinegrove SaaS", title: "RevOps Lead", status: "Proposal", source: "LinkedIn Ads", score: 76, owner: "theo",
    city: "Toronto", country: "Canada", tz: "EST", local: "11:42", pref: "Mornings", phone: "+1 416 555 0166", email: "greg.m@pinegrove.io", whatsapp: true, linkedin: true,
    value: 33000, tags: ["Mid-market"], lastTouch: "4h ago", lastChannel: "email", unread: 0, createdDays: 14,
    ad: { campaign: "Q2 — Demand Gen / NA", adset: "RevOps · 50–200", keyword: "revops outsourcing", utm: "li_q2_na" } }),
  lead({ key: "priscilla", name: "Priscilla Vance", company: "Tidewater Bank", title: "SVP Customer", status: "Nurture", source: "Webinar", score: 38, owner: "lena",
    city: "Charlotte, NC", country: "USA", tz: "EST", local: "11:42", pref: "Quarterly check-in", phone: "+1 704 555 0109", email: "p.vance@tidewater.com", whatsapp: false, linkedin: true,
    value: 72000, tags: ["Enterprise", "Long cycle"], lastTouch: "2 weeks ago", lastChannel: "email", unread: 0, createdDays: 64,
    ad: { campaign: "Webinar — Compliance Outreach", adset: "Attendees", keyword: "—", utm: "web_compliance" } }),
  lead({ key: "tomas", name: "Tomás Ferreira", company: "Quill & Co", title: "Marketing Manager", status: "Working", source: "Meta Ads", score: 52, owner: "sam",
    city: "Lisbon", country: "Portugal", tz: "WET", local: "16:42", pref: "Afternoons", phone: "+351 21 555 0188", email: "tomas@quillco.pt", whatsapp: true, linkedin: false,
    value: 21000, tags: ["SMB"], lastTouch: "Yesterday", lastChannel: "whatsapp", unread: 0, createdDays: 7,
    ad: { campaign: "Meta — Retargeting", adset: "Site visitors 30d", keyword: "—", utm: "meta_rt" } }),
  lead({ key: "amara", name: "Amara Nwosu", company: "Brightside Fitness", title: "Co-founder", status: "Won", source: "Referral", score: 91, owner: "priya",
    city: "London", country: "UK", tz: "GMT", local: "16:42", pref: "—", phone: "+44 20 555 0151", email: "amara@brightsidefit.co.uk", whatsapp: true, linkedin: true,
    value: 30000, tags: ["Won", "Founder-led"], lastTouch: "3 days ago", lastChannel: "call", unread: 0, createdDays: 41,
    ad: { campaign: "Referral — existing client", adset: "—", keyword: "—", utm: "ref_client" } }),
  lead({ key: "felix", name: "Felix Brandt", company: "Ironclad Security", title: "VP Sales", status: "Lost", source: "Cold outbound", score: 29, owner: "sam",
    city: "Berlin", country: "Germany", tz: "CET", local: "17:42", pref: "—", phone: "+49 30 555 0173", email: "f.brandt@ironclad.de", whatsapp: false, linkedin: true,
    value: 45000, tags: ["Lost — budget"], lastTouch: "1 week ago", lastChannel: "call", unread: 0, createdDays: 33,
    ad: { campaign: "Outbound — DACH security", adset: "VP Sales", keyword: "—", utm: "ob_dach" } }),
  lead({ key: "irene", name: "Irene Sokolova", company: "Sunbeam Solar", title: "Head of Partnerships", status: "Qualified", source: "Google Ads", score: 67, owner: "lena",
    city: "Madrid", country: "Spain", tz: "CET", local: "17:42", pref: "Mornings CET", phone: "+34 91 555 0118", email: "irene@sunbeamsolar.es", whatsapp: true, linkedin: true,
    value: 39000, tags: ["EU", "Green"], lastTouch: "Today", lastChannel: "whatsapp", unread: 1, createdDays: 11,
    ad: { campaign: "Search — Renewables", adset: "partnerships", keyword: "channel partner agency", utm: "gads_green" } }),
  lead({ key: "marcus2", name: "Marcus Cole", company: "Cedar & Stone", title: "Owner", status: "New", source: "Inbound form", score: 49, owner: "theo",
    city: "Portland, OR", country: "USA", tz: "PST", local: "08:42", pref: "Unknown", phone: "+1 503 555 0140", email: "marcus@cedarandstone.com", whatsapp: false, linkedin: false,
    value: 18000, tags: ["SMB"], lastTouch: "20m ago", lastChannel: "system", unread: 0, createdDays: 0,
    ad: { campaign: "Inbound — Website", adset: "—", keyword: "—", utm: "site_contact" } }),
  lead({ key: "yuki", name: "Yuki Sato", company: "Lumen Robotics", title: "VP Marketing", status: "Working", source: "LinkedIn Ads", score: 73, owner: "priya",
    city: "Tokyo", country: "Japan", tz: "JST", local: "00:42", pref: "Late night your time", phone: "+81 3 555 0162", email: "yuki.sato@lumenrobotics.jp", whatsapp: true, linkedin: true,
    value: 51000, tags: ["APAC", "Enterprise"], lastTouch: "6h ago", lastChannel: "email", unread: 0, createdDays: 16,
    ad: { campaign: "Q2 — Demand Gen / APAC", adset: "VP Marketing", keyword: "—", utm: "li_q2_apac" } }),
  lead({ key: "rosa", name: "Rosa Méndez", company: "Meadowlark Travel", title: "CEO", status: "Nurture", source: "Webinar", score: 41, owner: "sam",
    city: "Mexico City", country: "Mexico", tz: "CST", local: "10:42", pref: "Flexible", phone: "+52 55 555 0155", email: "rosa@meadowlark.mx", whatsapp: true, linkedin: false,
    value: 27000, tags: ["LATAM"], lastTouch: "9 days ago", lastChannel: "whatsapp", unread: 0, createdDays: 28,
    ad: { campaign: "Webinar — Scaling Outbound", adset: "Attendees", keyword: "—", utm: "web_scaling_q2" } }),
  lead({ key: "jonah", name: "Jonah Reyes", company: "Forge Athletics", title: "Director Marketing", status: "Working", source: "Meta Ads", score: 62, owner: "theo",
    city: "Miami, FL", country: "USA", tz: "EST", local: "11:42", pref: "Afternoons", phone: "+1 305 555 0129", email: "jonah@forgeathletics.com", whatsapp: true, linkedin: false,
    value: 25000, tags: ["DTC"], lastTouch: "Yesterday", lastChannel: "whatsapp", unread: 0, createdDays: 6,
    ad: { campaign: "Meta — Prospecting", adset: "Lookalike 1%", keyword: "—", utm: "meta_pro" } }),
];
const UNASSIGNED = [
  lead({ key: "u1", name: "Beatrice Lim", company: "Harborview Group", title: "Ops Director", status: "New", source: "Inbound form", score: 55, owner: null,
    city: "Vancouver", country: "Canada", tz: "PST", local: "08:42", pref: "Unknown", phone: "+1 604 555 0101", email: "b.lim@harborview.ca", whatsapp: true, linkedin: false,
    value: 22000, tags: ["Unassigned"], lastTouch: "12m ago", lastChannel: "system", unread: 0, createdDays: 0, ad: { campaign: "Inbound — Website", adset: "—", keyword: "—", utm: "site_contact" } }),
  lead({ key: "u2", name: "Karl Nyström", company: "Glacier Outdoors", title: "Founder", status: "New", source: "Google Ads", score: 48, owner: null,
    city: "Oslo", country: "Norway", tz: "CET", local: "17:42", pref: "Unknown", phone: "+47 22 555 0112", email: "karl@glacieroutdoors.no", whatsapp: false, linkedin: true,
    value: 19000, tags: ["Unassigned"], lastTouch: "44m ago", lastChannel: "system", unread: 0, createdDays: 0, ad: { campaign: "Search — Brand + Generic", adset: "outbound", keyword: "lead gen agency", utm: "gads_generic" } }),
  lead({ key: "u3", name: "Wendy Aboagye", company: "Trailhead Apps", title: "Growth Lead", status: "New", source: "LinkedIn Ads", score: 64, owner: null,
    city: "Accra", country: "Ghana", tz: "GMT", local: "16:42", pref: "Unknown", phone: "+233 30 555 0177", email: "wendy@trailhead.app", whatsapp: true, linkedin: true,
    value: 28000, tags: ["Unassigned"], lastTouch: "1h ago", lastChannel: "system", unread: 0, createdDays: 0, ad: { campaign: "Q2 — Demand Gen / NA", adset: "Growth · 50–200", keyword: "—", utm: "li_q2_na" } }),
];
const ALL_LEADS = LEADS.concat(UNASSIGNED);
const leadByKey = (k) => ALL_LEADS.find((l) => l.key === k);

/* ---------------- Conversation timelines ---------------- */
/* Rich timeline for the hero lead (Maya / Northwind). Others get lighter. */
const TIMELINES = {
  maya: [
    { date: "Mon, Jun 2" },
    { type: "system", time: "09:12", icon: "user-plus", text: "Lead created from LinkedIn Ads — Q2 Demand Gen / DACH." },
    { type: "system", time: "09:12", icon: "user-check", text: "Auto-assigned to you (round-robin)." },
    { type: "call", dir: "out", time: "11:04", duration: "6:48", outcome: "Connected · discovery", recording: true,
      summary: "Maya confirmed Northwind is launching outbound for a new product line in Q3 and lacks SDR capacity. Budget signalled around $40–50k for a 3-month pilot. Decision involves their RevOps lead. Next step: send a scoped proposal and a sample call recording.",
      tags: ["Pain: SDR capacity", "Budget: $40–50k", "3-month pilot"],
      transcript: [
        { t: "00:08", who: "rep", name: "You", text: "Thanks for hopping on, Maya. I saw Northwind is spinning up a new product line — is outbound part of that motion?" },
        { t: "00:21", who: "lead", name: "Maya", text: "It is. We're strong on inbound but we have zero outbound muscle, and hiring SDRs in this market is brutal." },
        { t: "01:14", who: "lead", name: "Maya", text: "Honestly if someone could just run a clean pilot for a quarter and show me booked meetings, that's the whole conversation.", mark: true },
        { t: "02:40", who: "rep", name: "You", text: "That's exactly how we start — a 3-month pilot, your ICP, our reps and tooling. What kind of budget envelope are you working with?" },
        { t: "03:02", who: "lead", name: "Maya", text: "For a pilot, somewhere in the forty to fifty range would clear without a big approval cycle.", mark: true },
      ] },
    { date: "Tue, Jun 3" },
    { type: "email", dir: "out", time: "08:30", subject: "Northwind × Meridian — pilot scope + sample call", from: "Priya Shah", to: "Maya Brennan",
      body: "Hi Maya — great speaking yesterday. Attached is a one-page scope for the 3-month outbound pilot plus a sample call recording from a similar SaaS launch. Happy to walk your RevOps lead through it this week. — Priya" },
    { type: "whatsapp", dir: "in", time: "13:18", status: "read", text: "Got the scope, thank you! Sharing with our RevOps lead now. Quick q — can the pilot start mid-month?" },
    { type: "whatsapp", dir: "out", time: "13:24", status: "read", text: "Absolutely — we can kick off the 16th. I'll hold a slot 👍" },
    { date: "Today · Jun 4" },
    { type: "note", author: "Priya Shah", time: "09:50", text: "RevOps lead is Daniel K. Maya wants a joint call Thu. Pull the Brightside case study — similar ICP." },
    { type: "whatsapp", dir: "in", time: "10:38", status: "read", text: "Can we do Thursday 3pm CST for the joint call with Daniel?" },
    { type: "whatsapp", dir: "in", time: "10:38", status: "read", text: "Also — does the pilot price include the WhatsApp channel or just calls + email?" },
  ],
  owen: [
    { date: "Yesterday" },
    { type: "call", dir: "out", time: "15:20", duration: "4:12", outcome: "Connected · qualified", recording: true,
      summary: "Owen wants to add outbound to Bluefin's retail expansion. Smaller scope than Northwind — likely $36k. He's the decision maker. Asked for references.",
      tags: ["Decision maker", "Needs references"], transcript: [
        { t: "00:11", who: "rep", name: "You", text: "What's pushing the timing on outbound for you right now?" },
        { t: "00:29", who: "lead", name: "Owen", text: "We're opening twelve new markets and I need pipeline in each before we sign leases.", mark: true },
      ] },
    { type: "note", author: "Priya Shah", time: "15:40", text: "Send Brightside + Forge references. Owen signs himself — fast cycle." },
  ],
  nadia: [
    { date: "Today" },
    { type: "whatsapp", dir: "in", time: "09:02", status: "read", text: "Hi Lena! Loved the proposal. Two of my co-founders want to see it 🙌" },
    { type: "whatsapp", dir: "out", time: "09:10", status: "read", text: "Amazing 🎉 Want me to run a 20-min walkthrough for all three of you this week?" },
    { type: "whatsapp", dir: "in", time: "09:31", status: "delivered", text: "Yes please. Thursday works." },
  ],
};
function timelineFor(key) {
  if (TIMELINES[key]) return TIMELINES[key];
  const l = leadByKey(key);
  return [
    { date: "Recent" },
    { type: "system", time: "—", icon: "user-plus", text: "Lead created from " + (l ? l.source : "—") + "." },
    { type: l && l.lastChannel === "whatsapp" ? "whatsapp" : "email", dir: "out", time: "—", status: "delivered",
      subject: "Intro — " + (l ? l.company : "") + " × Meridian", from: "You", to: l ? l.name : "",
      text: "Hi " + (l ? l.name.split(" ")[0] : "") + " — following up on your interest. Do you have 15 minutes this week to scope a pilot?",
      body: "Hi " + (l ? l.name.split(" ")[0] : "") + " — following up on your interest. Do you have 15 minutes this week to scope a pilot?" },
    { type: "note", author: "Owner", time: "—", text: "First touch logged. Awaiting reply." },
  ];
}

/* ---------------- Deals (pipeline) ---------------- */
const STAGES = [
  { id: "qualifying",  name: "Qualifying",  color: "var(--cat-1)" },
  { id: "proposal",    name: "Proposal sent", color: "var(--cat-3)" },
  { id: "negotiation", name: "Negotiation", color: "var(--cat-5)" },
  { id: "won",         name: "Won",         color: "var(--color-success)" },
  { id: "lost",        name: "Lost",        color: "var(--color-danger)" },
];
let _dn = 300;
function deal(o) { return Object.assign({ id: "DEAL-" + (++_dn) }, o); }
const DEALS = [
  deal({ leadKey: "maya", title: "Northwind — Q3 outbound pilot", company: "Northwind Labs", value: 48000, owner: "priya", stage: "proposal", prob: 65, age: 18, next: "Joint call Thu 3pm" }),
  deal({ leadKey: "owen", title: "Bluefin — multi-market outbound", company: "Bluefin Retail", value: 36000, owner: "priya", stage: "qualifying", prob: 45, age: 9, next: "Send references" }),
  deal({ leadKey: "sara", title: "Cobalt Health — EU expansion", company: "Cobalt Health", value: 60000, owner: "priya", stage: "qualifying", prob: 40, age: 5, next: "Scope call" }),
  deal({ leadKey: "nadia", title: "Halcyon — founder package", company: "Halcyon Media", value: 42000, owner: "lena", stage: "proposal", prob: 70, age: 3, next: "Walkthrough Thu" }),
  deal({ leadKey: "greg", title: "Pinegrove — RevOps retainer", company: "Pinegrove SaaS", value: 33000, owner: "theo", stage: "negotiation", prob: 80, age: 14, next: "Redlines on MSA" }),
  deal({ leadKey: "irene", title: "Sunbeam — channel partner motion", company: "Sunbeam Solar", value: 39000, owner: "lena", stage: "qualifying", prob: 50, age: 11, next: "Confirm budget" }),
  deal({ leadKey: "yuki", title: "Lumen Robotics — APAC pilot", company: "Lumen Robotics", value: 51000, owner: "priya", stage: "proposal", prob: 55, age: 16, next: "Localised deck" }),
  deal({ leadKey: "hiro", title: "Vertex — logistics outbound", company: "Vertex Logistics", value: 54000, owner: "theo", stage: "qualifying", prob: 35, age: 22, next: "Re-engage COO" }),
  deal({ leadKey: "amara", title: "Brightside — retainer", company: "Brightside Fitness", value: 30000, owner: "priya", stage: "won", prob: 100, age: 41, next: "Kickoff booked" }),
  deal({ leadKey: "jonah", title: "Forge — DTC outbound", company: "Forge Athletics", value: 25000, owner: "theo", stage: "negotiation", prob: 75, age: 6, next: "Final pricing" }),
  deal({ leadKey: "felix", title: "Ironclad — DACH outbound", company: "Ironclad Security", value: 45000, owner: "sam", stage: "lost", prob: 0, age: 33, next: "Lost — budget cut" }),
];

/* ---------------- Tasks / follow-ups ---------------- */
let _tn = 0;
function task(o) { return Object.assign({ id: "T" + (++_tn), done: false }, o); }
const TASKS = [
  task({ title: "Call Maya — confirm Thu joint call", leadKey: "maya", owner: "priya", due: "overdue", dueLabel: "Yesterday 4:00 PM", priority: "high", type: "call" }),
  task({ title: "Send Brightside case study to Maya", leadKey: "maya", owner: "priya", due: "today", dueLabel: "Today 11:00 AM", priority: "high", type: "email" }),
  task({ title: "WhatsApp Nadia the walkthrough invite", leadKey: "nadia", owner: "lena", due: "today", dueLabel: "Today 1:00 PM", priority: "med", type: "whatsapp" }),
  task({ title: "Send references to Owen", leadKey: "owen", owner: "priya", due: "today", dueLabel: "Today 2:30 PM", priority: "med", type: "email" }),
  task({ title: "Re-engage Hiro — pilot stalled", leadKey: "hiro", owner: "theo", due: "today", dueLabel: "Today 5:00 PM", priority: "low", type: "whatsapp" }),
  task({ title: "Localised deck for Lumen Robotics", leadKey: "yuki", owner: "priya", due: "upcoming", dueLabel: "Tomorrow 10:00 AM", priority: "med", type: "meeting" }),
  task({ title: "Quarterly check-in — Tidewater", leadKey: "priscilla", owner: "lena", due: "upcoming", dueLabel: "Fri 9:00 AM", priority: "low", type: "call" }),
  task({ title: "Confirm budget with Irene", leadKey: "irene", owner: "lena", due: "upcoming", dueLabel: "Fri 3:00 PM", priority: "med", type: "call" }),
];

/* ---------------- Customer groups + campaigns ---------------- */
const GROUPS = [
  { id: "g1", name: "Webinar attendees — no reply", count: 142, filter: "Source = Webinar · Status = Nurture · No touch 14d", updated: "2 days ago" },
  { id: "g2", name: "Proposal sent — follow up", count: 23, filter: "Stage = Proposal · Last touch > 5d", updated: "Today" },
  { id: "g3", name: "EU mid-market — Q2", count: 318, filter: "Region = EU · Value 20k–60k", updated: "1 week ago" },
  { id: "g4", name: "Cold outbound — APAC", count: 204, filter: "Source = Cold outbound · Region = APAC", updated: "3 days ago" },
];
const CAMPAIGNS = [
  { id: "c1", name: "Webinar re-engagement", group: "Webinar attendees — no reply", template: "webinar_followup", channel: "whatsapp", status: "sending", recipients: 142,
    counts: { read: 61, delivered: 38, sent: 18, queued: 19, replied: 14, failed: 6 }, scheduled: "Today 09:00", owner: "lena" },
  { id: "c2", name: "Proposal nudge — June", group: "Proposal sent — follow up", template: "proposal_nudge", channel: "whatsapp", status: "scheduled", recipients: 23,
    counts: { read: 0, delivered: 0, sent: 0, queued: 23, replied: 0, failed: 0 }, scheduled: "Tomorrow 10:00", owner: "priya" },
  { id: "c3", name: "EU mid-market intro", group: "EU mid-market — Q2", template: "intro_eu", channel: "whatsapp", status: "completed", recipients: 318,
    counts: { read: 188, delivered: 64, sent: 0, queued: 0, replied: 41, failed: 25 }, scheduled: "May 28 09:00", owner: "lena" },
  { id: "c4", name: "APAC cold wave 2", group: "Cold outbound — APAC", template: "intro_apac", channel: "whatsapp", status: "paused", recipients: 204,
    counts: { read: 33, delivered: 21, sent: 0, queued: 150, replied: 7, failed: 0 }, scheduled: "Paused at 26%", owner: "theo" },
];

/* ---------------- Templates ---------------- */
const TEMPLATES = [
  { id: "webinar_followup", name: "Webinar follow-up", channel: "whatsapp", category: "Marketing", status: "approved", vars: ["first_name", "webinar"], body: "Hi {{first_name}}, thanks for joining our {{webinar}} session! Want a quick 15-min walkthrough of how we'd run this for your team?" },
  { id: "proposal_nudge", name: "Proposal nudge", channel: "whatsapp", category: "Utility", status: "approved", vars: ["first_name"], body: "Hi {{first_name}}, just checking in on the proposal we sent — happy to answer any questions or jump on a quick call." },
  { id: "intro_eu", name: "EU intro", channel: "whatsapp", category: "Marketing", status: "approved", vars: ["first_name", "company"], body: "Hi {{first_name}}, I help growth teams like {{company}} add outbound without hiring. Open to a quick chat this week?" },
  { id: "intro_apac", name: "APAC intro", channel: "whatsapp", category: "Marketing", status: "pending", vars: ["first_name"], body: "Hi {{first_name}}, reaching out from Meridian — we run outbound pilots for B2B teams across APAC. Worth a conversation?" },
  { id: "email_scope", name: "Pilot scope email", channel: "email", category: "Sales", status: "approved", vars: ["first_name"], body: "Hi {{first_name}} — attached is a one-page scope for the 3-month outbound pilot..." },
];

/* ---------------- Billing: milestones + invoices ---------------- */
const MILESTONES = [
  { id: "m1", deal: "DEAL-310", label: "Pilot — month 1", amount: 16000, status: "paid", due: "Jun 1" },
  { id: "m2", deal: "DEAL-310", label: "Pilot — month 2", amount: 16000, status: "sent", due: "Jul 1" },
  { id: "m3", deal: "DEAL-310", label: "Pilot — month 3", amount: 16000, status: "draft", due: "Aug 1" },
];
const INVOICES = [
  { id: "INV-2041", client: "Brightside Fitness", amount: 16000, status: "paid", issued: "Jun 1", due: "Jun 15", deal: "Brightside — retainer" },
  { id: "INV-2042", client: "Pinegrove SaaS", amount: 11000, status: "sent", issued: "Jun 2", due: "Jun 16", deal: "Pinegrove — RevOps retainer" },
  { id: "INV-2039", client: "Forge Athletics", amount: 8500, status: "overdue", issued: "May 20", due: "Jun 3", deal: "Forge — DTC outbound" },
  { id: "INV-2043", client: "Halcyon Media", amount: 14000, status: "draft", issued: "—", due: "Jun 20", deal: "Halcyon — founder package" },
];
const INVOICE_STATUS = { paid: "rl-badge--success", sent: "rl-badge--info", overdue: "rl-badge--danger", draft: "rl-badge--neutral" };

/* ---------------- KPIs / reporting ---------------- */
const KPIS = {
  callsToday: 23, callsDelta: +12,
  leadsWorked: 31, leadsDelta: +5,
  dealsWon: 4, dealsWonValue: 138000, dealsDelta: +1,
  conversion: 24, conversionDelta: +3,
  pipelineValue: 471000,
  responseRate: 68,
};
const SPARK = [12, 18, 15, 22, 19, 26, 23, 28, 24, 31, 27, 34];
const PER_REP = [
  { id: "priya", calls: 23, leads: 31, won: 4, wonValue: 138000, conv: 24, target: 40, attainment: 96 },
  { id: "theo", calls: 18, leads: 26, won: 2, wonValue: 58000, conv: 19, target: 35, attainment: 74 },
  { id: "lena", calls: 21, leads: 29, won: 3, wonValue: 102000, conv: 22, target: 38, attainment: 88 },
  { id: "sam", calls: 9, leads: 14, won: 1, wonValue: 21000, conv: 11, target: 35, attainment: 41 },
];
const FUNNEL = [
  { stage: "New leads", value: 318, pct: 100 },
  { stage: "Worked", value: 214, pct: 67 },
  { stage: "Qualified", value: 122, pct: 38 },
  { stage: "Proposal", value: 64, pct: 20 },
  { stage: "Won", value: 38, pct: 12 },
];

/* ---------------- Notifications ---------------- */
const NOTIFS = [
  { id: "n1", icon: "message-circle", chan: "whatsapp", title: "Maya Brennan replied", body: "Can we do Thursday 3pm CST…", time: "2m", unread: true, leadKey: "maya" },
  { id: "n2", icon: "phone-missed", chan: "call", title: "Missed call — Hiro Tanaka", body: "Vertex Logistics · no voicemail", time: "26m", unread: true, leadKey: "hiro" },
  { id: "n3", icon: "user-plus", chan: "sms", title: "3 new unassigned leads", body: "From Inbound form & Google Ads", time: "1h", unread: true, leadKey: null },
  { id: "n4", icon: "check-circle-2", chan: "email", title: "Invoice INV-2041 paid", body: "Brightside Fitness · $16,000", time: "3h", unread: false, leadKey: null },
  { id: "n5", icon: "trending-up", chan: "call", title: "Pinegrove moved to Negotiation", body: "Theo Marsh updated the deal", time: "5h", unread: false, leadKey: "greg" },
];

/* ---------------- Helpers ---------------- */
function money(n) { return "$" + n.toLocaleString("en-US"); }
function moneyK(n) { return n >= 1000 ? "$" + (n / 1000).toFixed(n % 1000 ? 1 : 0) + "k" : "$" + n; }
function initialsOf(name) { return name.split(" ").map((w) => w[0]).slice(0, 2).join("").toUpperCase(); }

window.RX = {
  TENANT, USERS, REP_IDS, STATUS, SOURCE, scoreColor,
  LEADS, UNASSIGNED, ALL_LEADS, leadByKey, timelineFor, TIMELINES,
  STAGES, DEALS, TASKS, GROUPS, CAMPAIGNS, TEMPLATES,
  MILESTONES, INVOICES, INVOICE_STATUS, KPIS, SPARK, PER_REP, FUNNEL, NOTIFS,
  money, moneyK, initialsOf,
};
