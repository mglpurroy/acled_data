# acleddata

R package to access ACLED (Armed Conflict Location & Event Data) conflict data
maintained by the World Bank FCV Analytics Team.

Data is updated daily via a Databricks scheduled job and served from a central
Unity Catalog Volume — no manual downloads needed.

---

## Installation

```r
install.packages("remotes")
remotes::install_github("mglpurroy/acled_data")
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

Add these two lines to your `~/.Renviron` file:

```
DATABRICKS_HOST=https://adb-8552758251265347.7.azuredatabricks.net
DATABRICKS_TOKEN=your_token_here
```

Open the file with:
```r
file.edit("~/.Renviron")
```

Then restart R.

---

## Usage

```r
library(acleddata)

# Full dataset (~3 million records)
acled <- read_acled()

# Single country
afghanistan <- read_acled(country = "Afghanistan")

# Multiple countries
horn_of_africa <- read_acled(countries = c("Ethiopia", "Somalia", "Sudan"))
```

### Set credentials within a script (alternative to .Renviron)

```r
library(acleddata)

acled_auth(
  host  = "https://adb-8552758251265347.7.azuredatabricks.net",
  token = "your_token_here"
)

acled <- read_acled()
```

---

## Data structure

The dataset includes the following key columns:

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

The dataset is refreshed every day at 6:00 AM (ET) by a Databricks scheduled
job. Each run downloads the latest events from the ACLED API and overwrites
the central file in the Unity Catalog Volume.

---

## Requirements

- R 4.0 or higher
- Access to the World Bank Databricks workspace
- A valid Databricks personal access token

---

## For pipeline maintainers

See [`docs/`](docs/) for the technical documentation on the Databricks job,
folder structure, and how to update the pipeline scripts.

The pipeline scripts are in [`scripts/`](scripts/) and the Databricks job
notebooks are in [`notebooks/`](notebooks/).

To update the pipeline: edit scripts locally → `git push` → Databricks picks
up the latest version on the next run.

---

## Credits

- Data: [ACLED](https://acleddata.com/) — Armed Conflict Location & Event Data
- Pipeline: World Bank FCV Analytics Team
