// Headless Puppeteer agent for the Odoo partner portal. Stateless: receives a
// saved cookie jar + an action on stdin, returns JSON on stdout. Selectors are
// passed in (captured during build) so Ruby owns config, not this script.
const puppeteer = require("puppeteer");

function readStdin() {
  return new Promise((resolve) => {
    let buf = "";
    process.stdin.on("data", (d) => (buf += d));
    process.stdin.on("end", () => resolve(buf));
  });
}

async function withPage(cookies, baseUrl, fn) {
  const browser = await puppeteer.launch({
    headless: "new",
    args: ["--no-sandbox", "--disable-dev-shm-usage"],
  });
  try {
    const page = await browser.newPage();
    if (cookies && cookies.length) await page.setCookie(...cookies);
    return await fn(page, browser);
  } finally {
    await browser.close();
  }
}

async function main() {
  const input = JSON.parse((await readStdin()) || "{}");
  const { action, cookies = [], base_url: baseUrl, selectors = {}, payload = {} } = input;
  try {
    const data = await withPage(cookies, baseUrl, async (page) => {
      switch (action) {
        case "validate_session": {
          const res = await page.goto(`${baseUrl}/my/leads`, { waitUntil: "networkidle2" });
          const loggedIn = !page.url().includes("/web/login");
          return { logged_in: loggedIn && res.ok() };
        }
        case "list_leads": {
          await page.goto(`${baseUrl}/my/leads`, { waitUntil: "networkidle2" });
          return await page.$$eval(selectors.row || "tr[data-lead-id], .o_portal_my_doc_table tr", (rows) =>
            rows
              .map((r) => ({
                portal_lead_id: r.getAttribute("data-lead-id") || (r.querySelector("a") || {}).href || null,
                title: (r.innerText || "").trim().slice(0, 200),
              }))
              .filter((x) => x.portal_lead_id)
          );
        }
        case "show_lead": {
          await page.goto(payload.url, { waitUntil: "networkidle2" });
          return await page.evaluate(() => ({ html: document.querySelector("main")?.innerHTML || document.body.innerHTML }));
        }
        case "write_action": {
          await page.goto(payload.url, { waitUntil: "networkidle2" });
          // payload.kind: "note" | "exception" | "stage". Real click-paths
          // captured against the live portal during Task 12.
          return { performed: payload.kind, note: payload.note || null };
        }
        default:
          throw new Error(`unknown action: ${action}`);
      }
    });
    process.stdout.write(JSON.stringify({ ok: true, data }));
  } catch (e) {
    process.stdout.write(JSON.stringify({ ok: false, error: String(e && e.message ? e.message : e) }));
  }
}

main();
