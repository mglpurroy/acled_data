# acleddata

R and Python package to access ACLED (Armed Conflict Location & Event Data)
conflict data maintained by the World Bank FCV Analytics Team.

Data is updated daily and stored in a Databricks Delta table and Unity Catalog
Volume — no manual downloads needed, always up to date.

---

## Installation

**R:**
```r
install.packages("remotes")
remotes::install_github("mglpurroy/acled_data")
```

**Python:**
```bash
pip install "git+https://github.com/mglpurroy/acled_data.git#subdirectory=python"
```

---

## Setup (one-time)

You need a Databricks personal access token with `all-apis` scope.

**Step 1 — Generate a token**

In the Databricks workspace:
`User Settings → Developer → Access Tokens → Generate new token`
- Scope: **Other APIs**
- API scope: **all-apis**

Copy the token — it is only shown once.

**Step 2 — Save your credentials**

Add these two lines to your `~/.Renviron` file (R) or environment variables (Python):

```
DATABRICKS_HOST=https://adb-8552758251265347.7.azuredatabricks.net
DATABRICKS_TOKEN=your_token_here
```

Open `.Renviron` in R with:
```r
file.edit("~/.Renviron")
```

Then restart R.

---

## Usage

### R

```r
library(acleddata)

# Full dataset (~3 million records)
acled <- read_acled()

# Single country
afghanistan <- read_acled(country = "Afghanistan")

# Multiple countries
horn <- read_acled(countries = c("Ethiopia", "Somalia", "Sudan"))

# Date range
df <- read_acled(
  countries  = c("Sudan", "Yemen"),
  start_date = "2020-01-01",
  end_date   = "2024-12-31"
)
```

Set credentials within a script (alternative to `.Renviron`):
```r
acled_auth(
  host  = "https://adb-8552758251265347.7.azuredatabricks.net",
  token = "your_token_here"
)
```

### Python

```python
from acleddata import acled_auth, read_acled

acled_auth(
    host  = "https://adb-8552758251265347.7.azuredatabricks.net",
    token = "your_token"
)

# Full dataset
df = read_acled()

# Single country
df = read_acled(country="Afghanistan")

# Multiple countries with date range
df = read_acled(
    countries  = ["Sudan", "Yemen", "Syria"],
    start_date = "2020-01-01",
    end_date   = "2024-12-31"
)
```

---

## Querying directly in Databricks notebooks

The data is also available as a Delta table for direct SQL/Spark queries:

```sql
SELECT * FROM prd_datascience_compoundriskmonitor.compoundriskmonitor.acled
WHERE country = 'Sudan'
AND event_date >= '2020-01-01'
```

Time travel — query historical versions:
```sql
-- See full change history
DESCRIBE HISTORY prd_datascience_compoundriskmonitor.compoundriskmonitor.acled

-- Data as of a specific date
SELECT * FROM prd_datascience_compoundriskmonitor.compoundriskmonitor.acled
TIMESTAMP AS OF '2026-01-01'
WHERE country = 'Sudan'
```

---

## Data structure

| Column | Description |
|---|---|
| `event_id_cnty` | Unique event identifier |
| `event_date` | Date of the event |
| `country` | Country name |
| `region` | Geographic region |
| `event_type` | Type of conflict event |
| `sub_event_type` | Specific event classification |
| `actor1`, `actor2` | Actors involved |
| `latitude`, `longitude` | Geographic coordinates |
| `fatalities` | Number of fatalities |
| `notes` | Additional information |

Full documentation at [ACLED Data Guide](https://acleddata.com/resources/general-guides/).

---

## Data updates

Two scheduled Databricks jobs keep the data current:

| Job | Schedule | What it does |
|---|---|---|
| `ACLED Data` | Daily at 4:00 AM ET | Downloads last 30 days, merges new and updated events |
| `ACLED Monthly Refresh` | 1st of month at 2:00 AM ET | Full download from 1997, catches all historical corrections |

The daily job runs at 4 AM to avoid overlap with the monthly refresh (which
starts at 2 AM and takes ~1 hour). Both jobs write to the same Delta table
using `MERGE` — no data is ever overwritten or lost.

---

## Requirements

- R 4.0 or higher (for R package)
- Python 3.10 or higher (for Python package)
- Access to the World Bank Databricks workspace
- A valid Databricks personal access token

---

## For pipeline maintainers

**Architecture:**
- Scripts: [`scripts/`](scripts/) — R download and merge logic
- Notebooks: [`notebooks/`](notebooks/) — Databricks job entry points
- Daily job notebook: [`notebooks/daily_acled_update.r`](notebooks/daily_acled_update.r)
- Monthly job notebook: [`notebooks/monthly_acled_refresh.r`](notebooks/monthly_acled_refresh.r)

**To update the pipeline:**
```bash
# Edit scripts locally in VS Code
git add .
git commit -m "your message"
git push
# Then pull in Databricks Git Folder — changes take effect on next run
```

**Cluster environment variables** (set on the Databricks cluster):
```
ACLED_USERNAME=mpurroyvitola@worldbank.org
ACLED_PASSWORD=your_acled_password
```

**Scheduling note:** The monthly refresh (2 AM) and daily job (4 AM) are
staggered intentionally to prevent simultaneous writes to the Delta table.
Do not change these times without considering the overlap risk.

---

## Credits

- Data: [ACLED](https://acleddata.com/) — Armed Conflict Location & Event Data
- Pipeline: World Bank FCV Analytics Team
