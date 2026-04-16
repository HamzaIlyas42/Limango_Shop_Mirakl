---
name: Salesforce Org Architecture Documentation
overview: Produce org summary from package.xml + force-app using multiple files (one per area). Each file has overall summary plus per-component sections — e.g. Flows (20) then 20 lines, one per flow. Not one difficult single file.
todos: []
isProject: false
---

# Salesforce Org — Summary Plan (Multiple Files, Per-Component Summaries)

## Goal

**Input:** `package.xml` + `force-app` (any org).

**Output:** **Separate summary file per area.** Har area ki apni file; har file ke andar **har component ki alag 1-line summary** (e.g. 20 flows = 20 lines, one per flow). One big file avoid — easy to navigate.

---

## Recommended Structure: Multiple Files

| File                          | What's inside                                                                                                                                                |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **00-Overview.md**            | Executive summary (API version, counts, 1 sentence per area) + links to all files below. Short.                                                              |
| **01-Data-Model-Summary.md**  | Data summary + **per object**: Object 1 (1-line), Object 2 (1-line), … + relationship note.                                                                  |
| **02-Automation-Summary.md**  | Automation summary + **Flows**: Flow 1 (1-line), Flow 2 (1-line), … **Apex classes**: Class 1 (1-line), … **Triggers**: …, then Workflow/PB/Approval if any. |
| **03-UI-Summary.md**          | UI summary + **per component**: Apps, Tabs, Layouts, FlexiPages, LWC, Aura, VF — each listed with 1-line.                                                    |
| **04-Security-Summary.md**    | Security summary + **Profiles** (1-line each if useful), **Permission sets** (1-line each), Sharing summary.                                                 |
| **05-Integration-Summary.md** | Integration summary + **Named credentials**, **External objects**, **Connected apps** — 1-line each.                                                         |
| **06-Org-Health-Summary.md**  | What's in use vs missing, outdated, risks, recommendations (no per-component list).                                                                          |

So: **Flows 20 hain to 02-Automation-Summary.md** mein "Flows (20)" section, phir 20 lines — har flow ka 1-line summary. Same for objects, classes, UI in their own files.

---

## Per-File Content (Detail)

One document (or one main doc + one small appendix) with **short sections**. Each section = summary only: counts, main items, 1–2 lines “what it does,” and (where useful) one-line health note.

### 00-Overview.md

- Org API version (from package.xml).
- Total metadata types in package (how many `<types>`).
- What’s actually in force-app: counts (e.g. X custom objects, Y flows, Z Apex classes).
- One sentence per area: “Data: …”, “Automation: …”, “UI: …”, “Security: …”, “Integration: …”.
- Top 3–5 health/recommendation bullets (outdated, risk, cleanup).

### 01-Data-Model-Summary.md

- Count: custom objects, standard objects extended, external/package objects (if any).
- Table: Object name | Type (custom/standard/package) | 1-line purpose.
- One short paragraph: main relationships (e.g. “Quote → Account, Opportunity; SalesOrder → Account, Quote”).
- Optional: one small diagram (object → object) for core objects only.

### 02-Automation-Summary.md

- Counts: Flows (record-triggered / scheduled / screen / other), Apex classes, Apex triggers, Workflow rules, Process Builder, Approval processes (if any).
- One table: Type | Count | Short note (e.g. “Record-triggered flows on Account, Lead, Quote, …”).
- One short paragraph: how automation is split (e.g. “Mostly Flow; Apex for LWC/approval; no triggers”).
- One-line health: e.g. “Classic workflow present — consider migrating to Flow.”

### 03-UI-Summary.md

- Counts: Apps, Tabs, Layouts, FlexiPages, LWC, Aura, Visualforce (if any).
- One table: Type | Count | Note.
- One short paragraph: main entry points (e.g. “Sales app, Service app; record pages for Quote, SalesOrder”).
- One-line health: e.g. “Mix of LWC and Aura” or “Fully Lightning.”

### 04-Security-Summary.md

- Counts: Profiles, Permission sets, Sharing rules (by object if easy).
- One short paragraph: sharing model for main custom objects (e.g. “SalesOrder: Private; key objects use roles”).
- One-line health: e.g. “X permission sets — review for least privilege.”

### 05-Integration-Summary.md

- Counts: Named credentials, External data sources, Connected apps, Custom sites (if any).
- List: external objects (e.g. `*__x`) and what they’re for (one line).
- One short paragraph: how org connects out (e.g. “SAP, Marketing Cloud, AvaTax” if visible from names/labels).

### 06-Org-Health-Summary.md

- **In use:** What’s in package vs in force-app; any types with zero components (short list).
- **Outdated:** Classic vs Lightning, Workflow/PB vs Flow, old API (2–4 bullets).
- **Risks:** Performance, security, or maintainability (2–4 bullets).
- **Recommendations:** 5–10 short bullets (e.g. “Migrate workflow to Flow,” “Document approval flows,” “Review unused permission sets”).

---

## Optional: Metadata-Types-Summary.md

- One **compact table** for every type in package.xml: **Type name** | **1-line purpose** | **In this org? (Yes/No/Partial)** | **Count (if present)**.
- No long “how it works” — only so you can quickly see what each type is and whether the org has it.

---

## Execution Steps

1. **Parse package.xml** — List all metadata types; get API version.
2. **Scan force-app** — Count and list components per type (objects, flows, classes, triggers, layouts, etc.).
3. **Extract minimal relationships** — Objects (from object meta + key fields); which objects flows/triggers use (from names or quick scan). No need for full dependency graph.
4. **Classify automation** — Flow trigger types; count workflow/PB/approval if present.
5. **Write 00-Overview.md** — counts + links to 01–06.
6. **Write 01–06** — each file: short summary at top, then every component with 1-line summary (e.g. 20 flows → 20 lines in 02-Automation-Summary.md).
7. Optionally write **Metadata-Types-Summary.md**.

---

## What You Get

- **7 files** (00–06) + optional metadata-types file. One file per area — not one difficult single file.
- **Per-area:** Each file lists every component with 1-line summary (e.g. short table of all package.xml types with 1-line purpose and “in org?”.
- No long reference docs, no deep “how it works” per component — only **overall har cheez ki summary** so you can understand and present the org quickly.
