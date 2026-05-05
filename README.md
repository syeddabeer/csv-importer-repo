# Patient Data Migration

A small Rails 7 application that ingests a CSV of patient demographics
exported from a clinic's source EMR, persists each patient into a
PostgreSQL database, and reports per-migration statistics so a
data-migration specialist can verify each run.

Built for the Ava take-home challenge.

## Quick start

Prerequisites: Ruby 3.2.x, PostgreSQL 14+, a local Postgres role that can
create databases.

```bash
bundle install
bin/rails db:prepare
bin/rails server
```

Open <http://localhost:3000>, click **New migration**, upload
`Health For You Clinic Patient Demographics - patient_demographics.csv`,
and review the resulting statistics page.

## What the app does

1. **Upload** — `GET /data_migrations/new` shows a simple form that
   accepts a CSV file.
2. **Import** — `POST /data_migrations` invokes `PatientCsvImporter`,
   which parses the file, normalizes values (province codes, sex, phone
   digits, lower-cased emails) and upserts each row into the `patients`
   table.
3. **Report** — `GET /data_migrations/:id` shows per-run statistics:
   total / created / updated / unchanged / skipped / failed rows,
   duration, file SHA-256, and a per-row error table for triage.

## Idempotency

Patients are uniquely identified by the composite key
`(health_number, health_number_province)`, enforced by:

- a unique DB index on the pair, and
- an ActiveRecord `uniqueness` validation scoped on the same pair.

The importer uses `find_or_initialize_by` and only persists when the
row's values actually differ from what is already stored. Re-running
the same file therefore produces identical DB state and a report
dominated by the **unchanged** counter.

## Routes

| Verb | Path                  | Action                          |
|------|-----------------------|---------------------------------|
| GET  | `/`                   | `data_migrations#index` (root)  |
| GET  | `/data_migrations`    | List recent migrations          |
| GET  | `/data_migrations/new`| Upload form                     |
| POST | `/data_migrations`    | Run a migration                 |
| GET  | `/data_migrations/:id`| Statistics for one migration    |

## Project layout

```
app/
  controllers/data_migrations_controller.rb
  models/{patient,data_migration,data_migration_error}.rb
  services/patient_csv_importer.rb
  views/data_migrations/{index,new,show}.html.erb
config/                # standard Rails 7 configuration
db/migrate/            # patients + data_migrations + data_migration_errors
DESIGN.md              # design rationale
```

## Database schema

- **patients** — health number, province, name, DOB, sex, email,
  phone, address, source clinic, source row digest.
  Unique composite index on `(health_number, health_number_province)`.
- **data_migrations** — one row per upload: filename, file SHA-256,
  status, started/finished timestamps, duration, and counters
  (total / imported / created / updated / unchanged / skipped / failed).
- **data_migration_errors** — per-row failures with line number and
  validation messages, for line-by-line triage.

## CSV format

The importer matches headers loosely via regex aliases (e.g. `HIN`,
`Health #`, `health_no` all map to `health_number`). The only required
columns are `health_number` and `health_number_province` (a 2-letter
Canadian province/territory code). All other demographic fields are
optional.

Minimal example:

```csv
health_number,health_number_province,first_name,last_name,sex,email,phone,address
1234567890,ON,John,Doe,M,john@example.com,4165550123,123 Main St
```

## Design notes

See [DESIGN.md](DESIGN.md) for the full design rationale: identifier
strategy, idempotency, header mapping, statistics chosen, and
trade-offs.
