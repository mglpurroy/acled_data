# ACLED Data Management - Quick Start Guide

## 🚀 First Time Setup

### Step 1: Check Your Current Data (Optional)

If you have existing ACLED data files, check their status:

```batch
check_data.bat
```

Or in R:
```r
source("check_acled_data.R")
```

### Step 2: Migrate Existing Data (If Applicable)

If you have old ACLED files in the root directory, migrate them to the new structure:

```r
source("migrate_to_new_structure.R")
```

This will:
- Create organized folder structure
- Move latest file to `data/master/current/`
- Archive older versions
- Move country files to `data/by_country/`

### Step 3: Run First Update

Download or update your ACLED data:

**Option A: Windows (Easiest)**
```batch
update_acled.bat
```

**Option B: R/RStudio**
```r
source("update_acled.R")
```

**What happens:**
- If no data exists: Downloads complete dataset from 1997 to present (10-30 min)
- If data exists: Only downloads new events since last update (1-5 min)

## 📁 Your Data Structure

After running the update, you'll have:

```
acled_data/
├── data/
│   ├── master/
│   │   ├── current/
│   │   │   ├── acled_data_current.csv       ← Use this file
│   │   │   └── acled_data_all_01112026.csv  ← Dated backup
│   │   └── archive/                         ← Old versions
│   └── by_country/
│       ├── acled_Afghanistan.csv
│       ├── acled_Ukraine.csv
│       ├── acled_Sudan.csv
│       ├── ... (one file per country)
│       └── country_summary.csv              ← Countries overview
└── logs/                                     ← Update logs
```

## 📊 Using Your Data

### Load Complete Dataset

```r
library(readr)

# Load all ACLED data
data <- read_csv("data/master/current/acled_data_current.csv")

# View summary
summary(data)
head(data)
```

### Load Specific Country

```r
# Load single country
afghanistan <- read_csv("data/by_country/acled_Afghanistan.csv")

# Load multiple countries
library(dplyr)
countries <- c("Ukraine", "Sudan", "Afghanistan")

data <- data.frame()
for (country in countries) {
  filename <- paste0("data/by_country/acled_", gsub(" ", "_", country), ".csv")
  if (file.exists(filename)) {
    data <- bind_rows(data, read_csv(filename, show_col_types = FALSE))
  }
}
```

### View Country Summary

```r
summary <- read_csv("data/by_country/country_summary.csv")

# Top 20 countries by event count
print(head(summary, 20))

# Countries with recent updates
summary %>% 
  filter(grepl("Updated", status)) %>%
  arrange(desc(records))
```

## 🔄 Regular Updates

### Manual Update

Run whenever you need fresh data:

```batch
update_acled.bat
```

### Automatic Weekly Updates

Set up once, runs every Monday at 2:00 AM:

1. Open PowerShell as Administrator
2. Navigate to your ACLED folder
3. Run:
   ```powershell
   .\schedule_acled_update.ps1
   ```

Check logs in the `logs/` folder.

## 🔍 Data Verification

Check data status anytime:

```batch
check_data.bat
```

This shows:
- ✓ Folder structure
- ✓ Master file info (size, date range, record count)
- ✓ Country file summary
- ✓ Data quality metrics
- ✓ Update recommendations

## 📈 Common Tasks

### Filter by Date Range

```r
library(dplyr)
library(lubridate)

data <- read_csv("data/master/current/acled_data_current.csv")

# Last 30 days
recent <- data %>% 
  filter(event_date >= Sys.Date() - days(30))

# Specific year
data_2024 <- data %>% 
  filter(year(event_date) == 2024)

# Date range
data_range <- data %>%
  filter(event_date >= as.Date("2024-01-01") & 
         event_date <= as.Date("2024-12-31"))
```

### Filter by Event Type

```r
# Get all violence against civilians
violence <- data %>% 
  filter(event_type == "Violence against civilians")

# Get battles only
battles <- data %>%
  filter(event_type == "Battles")

# View all event types
unique(data$event_type)
```

### Aggregate Fatalities

```r
# Total fatalities by country
fatalities_by_country <- data %>%
  group_by(country) %>%
  summarize(
    total_fatalities = sum(fatalities, na.rm = TRUE),
    total_events = n()
  ) %>%
  arrange(desc(total_fatalities))

# Fatalities by month
fatalities_by_month <- data %>%
  mutate(month = floor_date(event_date, "month")) %>%
  group_by(month) %>%
  summarize(
    fatalities = sum(fatalities, na.rm = TRUE),
    events = n()
  )
```

### Create Maps

```r
library(ggplot2)
library(maps)

# Map of recent events
recent_data <- data %>% 
  filter(event_date >= Sys.Date() - days(90))

world <- map_data("world")

ggplot() +
  geom_polygon(data = world, 
               aes(x = long, y = lat, group = group),
               fill = "gray90", color = "white") +
  geom_point(data = recent_data, 
             aes(x = longitude, y = latitude, size = fatalities),
             color = "red", alpha = 0.5) +
  theme_minimal() +
  labs(title = "ACLED Events - Last 90 Days")
```

## ⚙️ Customization

### Change Update Overlap Period

Edit `update_acled.R`:

```r
result <- complete_acled_update(
  username = "your.email@domain.com",
  overlap_days = 14  # Change from 7 to 14 days
)
```

### Update Specific Countries Only

```r
source("acled_incremental_updater.R")
source("acled_country_splitter.R")

result <- complete_acled_update(
  username = "your.email@domain.com",
  countries = c("Ukraine", "Afghanistan", "Sudan")
)
```

### Change Base Directory

```r
result <- complete_acled_update(
  username = "your.email@domain.com",
  base_dir = "C:/Users/YourName/Documents/ACLED"
)
```

## ❓ Troubleshooting

### Issue: "No existing ACLED files found"

**Solution:** This is normal for first run. The script will download the complete dataset.

### Issue: Update is slow

**Solution:** 
- First download: 10-30 minutes (normal)
- Updates: 1-5 minutes (normal)
- Check your internet connection

### Issue: Authentication failed

**Solution:**
1. Verify ACLED account at https://acleddata.com/
2. Check username (should be your email)
3. Try providing password directly:
   ```r
   result <- complete_acled_update(
     username = "your.email@domain.com",
     password = "your_password"
   )
   ```

### Issue: Missing R packages

**Solution:**
```r
install.packages(c("httr2", "jsonlite", "dplyr", "readr", "lubridate", "purrr"))
```

### Issue: Old files in root directory

**Solution:** Run migration script:
```r
source("migrate_to_new_structure.R")
```

## 📞 Quick Reference

| Task | Command |
|------|---------|
| Update data | `update_acled.bat` or `source("update_acled.R")` |
| Check status | `check_data.bat` or `source("check_acled_data.R")` |
| Migrate files | `source("migrate_to_new_structure.R")` |
| Schedule updates | `.\schedule_acled_update.ps1` (PowerShell Admin) |
| Load master file | `read_csv("data/master/current/acled_data_current.csv")` |
| Load country file | `read_csv("data/by_country/acled_CountryName.csv")` |
| View summary | `read_csv("data/by_country/country_summary.csv")` |

## 📚 More Information

- Full documentation: See `README.md`
- ACLED documentation: https://acleddata.com/
- Data codebook: https://acleddata.com/resources/

## 🎯 Next Steps

1. ✅ Run your first update: `update_acled.bat`
2. ✅ Check the data: `check_data.bat`
3. ✅ Load data in R and explore
4. ✅ Set up scheduled updates: `schedule_acled_update.ps1`
5. ✅ Start your analysis!

---

**Happy analyzing! 📊**

