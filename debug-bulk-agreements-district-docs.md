# [OPEN] Session: bulk-agreements-district-docs

| Field | Value |
|---|---|
| sessionId | bulk-agreements-district-docs |
| Created | 2026-07-27 |
| Environment | PHP web server (XAMPP/local or production) + `new_aggrement_All.php` |
| Scope | Two bugs: (1) selecting project doesn't show all SDP districts; (2) Download Bulk Agreements yields only 1-2 docs per learner instead of all before moving to next learner |
| Status | [OPEN] Step 1 — Hypothesize |

---

## Hypotheses (3-5 Falsifiable)

| # | Hypothesis | Predicted Observation | Test / Evidence | Result |
|---|---|---|---|---|
| H1 | **District filter broken because SQL uses wrong filter (Bug #1) | The district dropdown AJAX call after project change doesn't use the correct `project_id or `sdp_id`/`sdp` or uses a variable that was not defined / was mis-assigned for the district WHERE clause. | Instrument `get_districts` / district SQL in the file, log input vars + raw SQL rows. | PENDING |
| H2 | **District filter JOIN uses learners or sites table instead of a dedicated sdp-district mapping** — the query returns districts only where there are already learners for that project+district, skipping empty districts. | Compare number of rows with real district count for the SDP. | PENDING |
| H3 | **Bulk docs #2: `continue` / early return inside per-learner inner loop breaks out of the doc-type loop after 1-2** | Inside per-learner doc-type iteration, a conditional calls `continue`/`return`/`throw` without reset on non-fatal condition (missing data check / if block missing else goto next doc). | Instrument inner loop: count loop entries vs zip entries and log each doc_type id's, doc generation, $pdf output. | PENDING |
| H4 | **Bulk docs #2: ZipArchive `addFile/addFromString called but file handle/string is stale (same filename overwrites per learner OR zip only keeps last 1-2 docs because learner_id not in name? No — "1-2 docs PER LEARNER" so must be loop-through-learner doc-type count ≤ 2 actually happening due to array_filter over doc_type list being limited source. Not zip filename issue) ** → **Doc list for learner is actually ≤2. Check if the $agreementTemplates or doc-types config array actually enumerates 1-2 only. | Log the count of items inside foreach "docs to generate for learner X": if ≤2 the source list is filtered short. If count >2, then generation aborts mid-loop (H3 wins over H4). | PENDING |
| H5 | **Bulk docs #2: silent `die` / `exit` / `false` return from FPDF write + no `set_time_limit`** FPDF/FPDI memory_limit / max_execution_time aborts the PHP mid-learner after first 1-2 docs before learner loop silently without throwing catch able no error to logs. | PHP error_log .log entries & instrument before/after each PDF: ok memory_get_usage, peak mem. check execution time. | PENDING |

---

## Instrumentation Plan

Add error_log() lines at:
1. district SQL execution: input $_POST vars (project_id, sdp_id), sql string, rowcount → php `error_log(...)` + network report to debug server when we get it running.
2. per-learner start: log learner_id + doc list count to generate
3. per-doc-type: doc type, success bool, filename, memory delta
4. zip->addFile return value logged each time; zip->close logged

---

## Steps

- [x] Hypothesize: H1-H5
- [ ] Read source, find district + bulk loop code
- [ ] Instrument: log H1-H5 markers (no biz logic change)
- [ ] Reproduce: instruct user to trigger page actions on page → collect evidence from logs/network
- [ ] Analyse + fix minimally
- [ ] Verify post-fix
- [ ] User confirm → cleanup
