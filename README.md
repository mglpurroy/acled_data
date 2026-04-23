# ACLED Data Management System

Automated system for downloading, updating, and managing ACLED (Armed Conflict Location & Event Data) conflict data.

## 📁 Folder Structure

```
acled_data/
├── data/                       # All ACLED data files
│   ├── master/
│   │   ├── current/            # Latest complete dataset
│   │   │   ├── acled_data_current.csv    ← YOUR PRIMARY FILE
│   │   │   └── acled_data_all_[date].csv
│   │   └── archive/            # Previous versions (auto-archived)
│   └── by_country/             # Individual country files
│       ├── acled_Afghanistan.csv
│       ├── acled_Pakistan.csv
│       ├── ... (239 country files)
│       └── country_summary.csv
│
├── scripts/                    # All R and PowerShell scripts
│   ├── update_acled.R          # Main update script
│   ├── acled_incremental_updater.R   # Core update logic
│   ├── acled_country_splitter.R      # Country file generator
│   ├── check_acled_data.R      # Data verification
│   ├── schedule_acled_update.ps1     # Task scheduler setup
│   ├── update_acled_scheduled.bat    # Scheduled batch file
│   └── archive/                # One-time migration scripts
│
├── docs/                       # Documentation
│   ├── QUICK_START.md          # Quick start guide
│   ├── FOLDER_STRUCTURE.txt    # Detailed folder reference
│   └── ORGANIZATION_SUMMARY.txt
│
├── logs/                       # Update logs
├── update_acled.bat            # Quick update (double-click)
├── check_data.bat              # Quick data check
└── README.md                   # This file
```

## 🚀 How It Works

### Intelligent Update System

The system automatically handles two scenarios:

#### 1. **First Time / No Existing Data**
- Downloads **complete ACLED dataset** from 1997 to present
- Creates organized folder structure
- Saves master file and splits by country

#### 2. **Incremental Update**
- Finds latest date in existing data
- Downloads only **new data** from (latest_date - 7 days) to present
- The 7-day overlap catches any late updates or corrections
- Merges with existing data and removes duplicates
- Archives old master file
- Updates country-specific files incrementally

### Data Management

- **Master File**: Always contains complete historical dataset
- **Current Version**: `data/master/current/acled_data_current.csv`
- **Dated Backup**: `data/master/current/acled_data_all_MMDDYYYY.csv`
- **Archives**: Old versions automatically moved to `data/master/archive/`
- **Country Files**: Individual CSV files for each country in `data/by_country/`

## 📖 Usage

### Quick Start

**First time here?** Check out `docs/QUICK_START.md` for a step-by-step guide!

**Check your data:** Run `check_data.bat` anytime to see data status and quality metrics.

### Option 1: Quick Update (Recommended)

Simply run the batch file:

```batch
update_acled.bat
```

Or double-click `update_acled.bat` in Windows Explorer.

### Option 2: Run R Script Directly

In R or RStudio:

```r
source("scripts/update_acled.R")
```

### Option 3: Scheduled Automatic Updates

Set up weekly automatic updates:

1. Run PowerShell as Administrator
2. Navigate to this folder
3. Execute:
   ```powershell
   .\scripts\schedule_acled_update.ps1
   ```
4. Task will run every Monday at 2:00 AM

## 🔧 Advanced Usage

### Custom Update Parameters

```r
source("scripts/acled_incremental_updater.R")
source("scripts/acled_country_splitter.R")

# Update with custom overlap period (14 days instead of 7)
result <- complete_acled_update(
  username = "your.email@domain.com",
  overlap_days = 14
)

# Update specific countries only
result <- complete_acled_update(
  username = "your.email@domain.com",
  countries = c("Afghanistan", "Pakistan", "Ukraine"),
  overlap_days = 7
)

# Just update country files from existing master
summary <- update_country_files()
```

### Access Latest Data

```r
library(readr)

# Load complete dataset
data <- read_csv("data/master/current/acled_data_current.csv")

# Load specific country
afghan_data <- read_csv("data/by_country/acled_Afghanistan.csv")

# View country summary
summary <- read_csv("data/by_country/country_summary.csv")
print(head(summary, 20))  # Top 20 countries
```

## 📊 Data Structure

### Master File Columns

The ACLED dataset includes:
- `event_id_cnty`: Unique event identifier
- `event_date`: Date of the event
- `country`: Country name
- `region`: Geographic region
- `event_type`: Type of conflict event
- `sub_event_type`: More specific event classification
- `actor1`, `actor2`: Actors involved
- `latitude`, `longitude`: Geographic coordinates
- `fatalities`: Number of fatalities
- `notes`: Additional information
- And more...

## ⚙️ Configuration

### Change Update Frequency

Edit `overlap_days` parameter:
- **7 days** (default): Good balance for catching updates
- **14 days**: More conservative, catches more late updates
- **3 days**: Faster updates, may miss some corrections

### Change ACLED Username

Edit in `scripts/update_acled.R`:
```r
result <- complete_acled_update(
  username = "your.email@domain.com",  # Change this
  overlap_days = 7
)
```

## 🔐 Authentication

The system uses OAuth authentication with ACLED API. You'll need:
1. An ACLED account (register at https://acleddata.com/)
2. Your username (email) will be prompted when running the script
3. Password will be requested securely via pop-up

## 📝 Features

✅ **Automatic Mode Detection**: First download vs. incremental update  
✅ **Overlap Period**: Catches late updates and corrections  
✅ **Deduplication**: Keeps most recent version of events  
✅ **Automatic Archiving**: Previous versions saved automatically  
✅ **Country Splitting**: Individual files for each country  
✅ **Progress Tracking**: Detailed console output  
✅ **Error Handling**: Robust error management  
✅ **Scheduled Updates**: Windows Task Scheduler integration  

## 🛠️ Requirements

### R Packages

```r
install.packages(c(
  "httr2",       # API requests
  "jsonlite",    # JSON parsing
  "dplyr",       # Data manipulation
  "readr",       # CSV reading/writing
  "lubridate",   # Date handling
  "purrr"        # Functional programming
))
```

### System Requirements

- R version 4.0 or higher
- Windows 10/11 (for scheduled updates)
- Internet connection
- ACLED account

## 📞 Support

### Common Issues

**Q: Script says "No existing ACLED files found"**  
A: This is normal for first run. It will download the complete dataset.

**Q: Update is taking a long time**  
A: First download can take 10-30 minutes. Subsequent updates are much faster (1-5 minutes).

**Q: Password prompt doesn't appear**  
A: You can provide password in the script:
```r
result <- complete_acled_update(
  username = "your.email@domain.com",
  password = "your_password"
)
```

**Q: How do I check what data I have?**  
A: Check `data/master/current/acled_data_current.csv` or view the summary:
```r
summary <- read_csv("data/by_country/country_summary.csv")
print(summary)
```

## 📈 Data Updates

ACLED updates their data:
- **Real-time**: New events added continuously
- **Revisions**: Past events may be updated with new information
- **Quality control**: Data undergoes regular quality checks

Our system's 7-day overlap ensures you capture these updates and revisions.

## 🔄 Update History

Old master files are automatically archived with timestamps:
- `data/master/archive/acled_data_all_12182024_archived_20250111_143052.csv`

This allows you to:
- Track data changes over time
- Revert to previous versions if needed
- Compare datasets across different time periods

## 📄 License

This management system is provided as-is. ACLED data is subject to ACLED's terms of use.
Visit https://acleddata.com/ for more information about ACLED data licensing.

## 📂 Project Organization

This project follows best practices for data science projects:

- **`data/`** - All data files (never committed to version control)
- **`scripts/`** - All analysis and processing scripts
- **`docs/`** - Project documentation
- **`logs/`** - Automated logs and outputs
- **Root** - Quick access batch files and main README

### Documentation

- **README.md** (this file) - Main documentation
- **docs/QUICK_START.md** - Quick start guide with examples
- **docs/FOLDER_STRUCTURE.txt** - Detailed folder reference
- **docs/ORGANIZATION_SUMMARY.txt** - Organization details

### Archived Scripts

One-time migration scripts are archived in `scripts/archive/` and no longer needed for regular operations.

## 🙏 Credits

- **ACLED**: Armed Conflict Location & Event Data Project (https://acleddata.com/)
- **System**: World Bank FCV Analytics Team
