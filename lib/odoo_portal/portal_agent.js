// Headless Puppeteer agent for the odoo.com partner portal. Stateless: receives
// a saved cookie jar + an action on stdin, returns JSON on stdout.
//
// Selectors below were captured against the LIVE portal (2026-06):
//   - Leads list:  GET /my/leads  -> a single <table>, one <tr> per lead.
//       row link:  a[href*="/my/lead/<id>"]   (id = trailing digits)
//       cells:     [Date, Lead title, Contact Name, Email, Phone]
//   - Lead detail: GET /my/lead/<id>  -> schema.org microdata in the Customer row.
//   - Write-back:  two POST modal forms on the detail page:
//       disqualify ("I'm not interested"): form.desinterested_partner_assign_form
//         fields: comment (reason), customer_mark_spam (checkbox), confirm button
//       accept ("I'll contact them"):      form.interested_partner_assign_form
//         fields: comment (qualification), customer_contacted, confirm button
const puppeteer = require("puppeteer");

function readStdin() {
  return new Promise((resolve) => {
    let buf = "";
    process.stdin.on("data", (d) => (buf += d));
    process.stdin.on("end", () => resolve(buf));
  });
}

async function withPage(cookies, fn) {
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
  const rowSel = selectors.row || "table tbody tr";
  try {
    const data = await withPage(cookies, async (page) => {
      switch (action) {
        case "validate_session": {
          const res = await page.goto(`${baseUrl}/my/leads`, { waitUntil: "networkidle2" });
          const loggedIn = !page.url().includes("/web/login") && !page.url().includes("/web/signup");
          return { logged_in: loggedIn && !!res && res.ok() };
        }

        case "list_leads": {
          await page.goto(`${baseUrl}/my/leads`, { waitUntil: "networkidle2" });
          return await page.$$eval(rowSel, (rows) =>
            rows
              .map((r) => {
                const link = r.querySelector('a[href*="/my/lead/"]');
                if (!link) return null;
                const href = link.getAttribute("href") || "";
                const m = href.match(/(\d+)\/?(?:[?#]|$)/);
                const cells = Array.from(r.querySelectorAll("td")).map((td) => (td.innerText || "").trim());
                return {
                  portal_lead_id: m ? m[1] : href,
                  url: href.startsWith("http") ? href : location.origin + href,
                  title: cells[1] || (link.innerText || "").trim(),
                  contact_name: cells[2] || null,
                  email: cells[3] || null,
                  phone: cells[4] || null,
                };
              })
              .filter(Boolean)
          );
        }

        case "show_lead": {
          await page.goto(payload.url, { waitUntil: "networkidle2" });
          return await page.evaluate(() => ({
            html: (document.querySelector("main") || document.body).innerHTML,
          }));
        }

        case "write_action": {
          // kind "exception" -> "I'm not interested" (disqualify); anything else
          // -> "I'll contact them" (accept with a note). Both are AJAX POST forms.
          await page.goto(payload.url, { waitUntil: "networkidle2" });
          const isException = payload.kind === "exception";
          const formSel = isException
            ? "form.desinterested_partner_assign_form"
            : "form.interested_partner_assign_form";
          const confirmSel = isException
            ? ".desinterested_partner_assign_confirm"
            : ".interested_partner_assign_confirm";

          await page.evaluate(
            (sel, note, spam) => {
              const form = document.querySelector(sel);
              if (!form) throw new Error("write-back form not found: " + sel);
              const comment = form.querySelector('[name="comment"]');
              if (comment && note) comment.value = note;
              const contacted = form.querySelector('[name="customer_contacted"], [name="contacted_desinterested"]');
              if (contacted) contacted.checked = true;
              if (spam) {
                const s = form.querySelector(".customer_mark_spam");
                if (s) s.checked = true;
              }
            },
            formSel,
            payload.note,
            payload.spam
          );

          await page.click(confirmSel);
          // Give the AJAX submit time to land.
          await new Promise((r) => setTimeout(r, 1500));
          return { performed: payload.kind, lead_id: payload.lead_id || null };
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
