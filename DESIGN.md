# Design

This document captures the design rationale behind the patient
data-migration app: what was built, what was deliberately left out, and
why each major trade-off was made.

## Goals

The brief: ingest a clinic's patient demographics CSV, persist each
patient to a relational database, and give a data-migration specialist
enough feedback to verify a run was correct. The app needed to be:

1. **Idempotent** — re-running the same file must not duplicate
   patients or skew counts.
2. **Resilient to messy headers** — source EMRs rename columns
   constantly; a brittle parser would be useless in practice.
3. **Auditable** — every run produces a permanent record with stats
   and per-row errors a human can triage.
4. **Boring** — plain Rails 7, no background-job infrastructure, no
   bespoke DSLs. A reviewer should be able to read it end-to-end in
   one sitting.

## Domain model

Three tables, one service:

| Table                   | Role                                          |
|-------------------------|-----------------------------------------------|
| `patients`              | Canonical patient record                      |
| `data_migrations`       | One row per CSV upload (the audit record)     |
| `data_migration_errors` | Per-row failures attached to a migration      |

`PatientCsvImporter` is the only piece of behaviour worth its own
class. The controller is thin: receive file → call importer →
redirect to the report page.

### Why a separate `data_migrations` table?

Counts could have been computed on demand by re-reading the file, but
a persisted run record gives us:

- a stable URL to share with the team (`/data_migrations/42`),
- file SHA-256 so a re-upload can be recognised,
- start/finish timestamps and duration for performance trending,
- a parent for `data_migration_errors`, which is what makes triage
  practical.

## Identifier strategy & idempotency

A patient is uniquely identified by
**`(health_number, health_number_province)`**.

Why the composite key:

- Health numbers are issued per province; the same digits can — and
  do — collide across provinces.
- Using a natural composite key (rather than an opaque surrogate)
  means the importer can deterministically locate an existing patient
  from the CSV row alone, no matching heuristics needed.

Enforced in two places, on purpose:

1. A **unique DB index** on `(health_number, health_number_province)`
   — the source of truth, race-safe.
2. An ActiveRecord `uniqueness` validation scoped on the same pair —
   gives a friendly error message before hitting the DB.

The importer uses `find_or_initialize_by`, assigns the incoming
attributes, and **only saves when `patient.changed?` is true**. That
single check is what turns the report into something useful: re-running
the same file produces a row of `unchanged` counts and zero writes,
which is the strongest possible signal that the import is
deterministic.

`source_row_digest` (SHA-256 of the normalised attribute set) is
stored on each patient so we can later prove which exact CSV row
produced the current state of a record.

## Header mapping

Source EMRs use wildly inconsistent column names: `HIN`, `Health #`,
`health_no`, `Patient Health Number`, `address 1`, `Address Line 1`,
`Address City`, etc. A literal header-to-attribute map would break on
the first new export.

Instead, each canonical attribute has a list of regex aliases in
`COLUMN_ALIASES`:

```ruby
health_number: [/\Ahealth[\s_-]*(number|no|num|id|identifier|#)\z/i, /\Ahin\z/i, /\Aphn\z/i],
address_line:  [/\A(address|street|address[\s_-]*line|address[\s_-]*1|address[\s_-]*line[\s_-]*1)\z/i],
city:          [/\A(address[\s_-]*)?(city|town|municipality)\z/i],
```

`build_header_map` walks the CSV's actual headers once and picks the
first match per attribute. New variants are a one-line addition; no
parser changes required.

Only `health_number` and `health_number_province` are required. Every
other field is optional — a missing `email` column is normal, not an
error.

## Normalisation

Applied at the importer boundary, before the value reaches the model:

| Field                    | Normalisation                                 |
|--------------------------|-----------------------------------------------|
| `health_number_province` | upcased (`on` → `ON`)                         |
| `sex`                    | mapped to `F` / `M` / `X` / `U`               |
| `date_of_birth`          | parsed with `Date.parse`, nil on failure      |
| `email`                  | downcased                                     |
| `phone`                  | digits only (`(416) 555-0123` → `4165550123`) |

This keeps the database canonical (`Patient.where(email: "x@y.z")`
just works) and keeps the model free of input-format guesswork.

## Statistics

The importer maintains six counters:

- `total` — every data row seen
- `created` — new patients inserted
- `updated` — existing patients with at least one changed attribute
- `unchanged` — existing patients whose data already matched
- `skipped` — rows missing the required identifier pair
- `failed` — rows that raised a validation error on save

`imported = created + updated + unchanged`. Splitting **updated** vs
**unchanged** is the single most useful piece of feedback: if a
specialist re-imports the same file and sees non-zero `updated`, the
source has drifted and they need to know.

Per-failure detail (line number, identifier, validation messages)
lands in `data_migration_errors` and is shown on the report page,
capped at 200 rows so a pathological file can't OOM the view.

## Error handling

Three layers, intentionally distinct:

1. **Skipped rows** (missing identifier) — recorded as errors but do
   not abort the run. The migration completes with a non-zero
   `skipped` count.
2. **Failed rows** (validation errors at save time) — same: recorded,
   counted, run continues.
3. **Fatal errors** (e.g. missing required column, unreadable file)
   — caught by a top-level `rescue`, which marks the migration
   `failed` and stores the exception class and message. The run
   record still exists and is still viewable.

A bad row never poisons the rest of the file. A bad *file* is
recorded as a failed run instead of a 500.

## Encoding

CSVs from EMRs come in inconsistent encodings. The importer reads the
whole file, force-encodes UTF-8, and runs `scrub!("?")` to replace
invalid bytes. This prevents `CSV.parse` from raising on mixed-encoding
exports — the cost is that genuinely garbled bytes show up as `?`,
which is acceptable for a demographics import.

## Trade-offs (what this app deliberately does **not** do)

- **No background jobs.** The importer runs synchronously in the
  request. The provided file is small enough that this is fine, and
  it keeps the deployment story to "one Rails process". For
  multi-megabyte files the same `PatientCsvImporter` would be invoked
  from an ActiveJob with no logic changes.
- **No streaming parser.** `CSV.parse` reads the whole file into
  memory. Same justification as above, same fix when needed
  (`CSV.foreach`).
- **No authentication.** The brief is an internal data-migration tool;
  adding Devise would be busywork. In production this would sit
  behind the same SSO as the rest of the clinic's tooling.
- **No soft-delete / history table.** Updates overwrite. If audit
  history is needed, `paper_trail` slots in cleanly because every
  write goes through ActiveRecord.
- **No fuzzy patient matching.** Matching is strictly by the
  `(health_number, province)` pair. Probabilistic matching
  (name + DOB) is a different problem and is intentionally out of
  scope.
- **SQLite in development.** Chosen so the app boots on a stock
  Windows machine with no external services. The schema uses nothing
  Postgres-specific, so swapping back to `pg` is a Gemfile change and
  a `database.yml` edit.
