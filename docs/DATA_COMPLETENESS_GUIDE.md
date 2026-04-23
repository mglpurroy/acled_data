# ACLED Data Completeness Guide

## Understanding ACLED Data Availability

### ⏱️ Reporting Delay

**ACLED has a typical 3-10 day reporting delay.** This means:
- Events from today won't be in the API yet
- Events from 3-10 days ago may still be incomplete
- Complete, quality-checked data is usually available after ~10 days

### 📅 Your Current Situation (Example)

From your latest update:
- **Today's date:** January 11, 2026
- **Latest data available:** January 2, 2026
- **Gap:** 9 days (normal!)

This is **expected behavior** - ACLED needs time to:
1. Collect reports from multiple sources
2. Verify event details
3. Deduplicate reports
4. Quality-check the data
5. Publish to the API

## 🎯 Ensuring Complete Monthly Coverage

### Best Practices

1. **Run Updates Weekly**
   ```r
   source("scripts/update_acled.R")
   ```
   - Recommended: Every Monday
   - This ensures you capture data as it becomes available

2. **Mid-Month Check**
   - After the 15th of each month, run an update
   - This captures the first half of the previous month

3. **End-of-Month Update**
   - First week of new month (e.g., Jan 7-10 for December data)
   - This ensures complete previous month coverage

### Example Schedule

**For Complete January 2026 Data:**
- ✅ **Jan 11:** Update (gets data through ~Jan 2)
- ⏳ **Jan 18:** Update (gets data through ~Jan 8-9)
- ⏳ **Jan 25:** Update (gets data through ~Jan 15-16)
- ⏳ **Feb 7:** Update (ensures complete January data)

## 🔍 Checking Your Data

### View Latest Date in Your Data

```r
library(readr)
library(dplyr)

# Load master file
data <- read_csv("data/master/current/acled_data_current.csv")

# Check latest date
max_date <- max(data$event_date, na.rm = TRUE)
print(paste("Latest data:", max_date))
print(paste("Days behind:", Sys.Date() - max_date))

# Check events by date (last 30 days)
recent <- data %>%
  filter(event_date >= Sys.Date() - 30) %>%
  group_by(event_date) %>%
  summarize(events = n()) %>%
  arrange(desc(event_date))

print(recent)
```

### Verify Month Completeness

```r
library(lubridate)

# Check December 2025 coverage
december <- data %>%
  filter(year(event_date) == 2025, month(event_date) == 12) %>%
  group_by(event_date) %>%
  summarize(events = n()) %>%
  arrange(event_date)

# Check for gaps
all_days <- seq.Date(as.Date("2025-12-01"), as.Date("2025-12-31"), by = "day")
missing_days <- all_days[!all_days %in% december$event_date]

if (length(missing_days) > 0) {
  print("Missing dates in December 2025:")
  print(missing_days)
} else {
  print("✓ Complete coverage for December 2025")
}
```

## 🔄 The Overlap Strategy

### Why 7 Days?

The 7-day overlap ensures you capture:
1. **Late-reported events:** Events reported days after occurrence
2. **ACLED corrections:** Updates to event details, fatality counts
3. **Source additions:** New sources confirming or adding details
4. **Quality improvements:** Post-publication data refinements

### Example

**Update on Jan 11:**
- Your data has events through Dec 12, 2025
- Script fetches from **Dec 5 to Jan 11** (7-day overlap)
- Gets: Dec 5-12 (duplicates, may have updates) + Dec 13 to Jan 2 (new)
- Result: 7,643 duplicates removed (these were updated events!)

## ⚠️ What the Warnings Mean

### "Latest data is X days old"

**If 3-7 days:** Normal, ACLED is catching up  
**If 7-14 days:** Run another update in a few days  
**If >14 days:** May indicate API issues or your account needs renewal

### "Previous month may be incomplete"

Appears when:
- We're in a new month (e.g., January)
- Latest data is from previous month (e.g., December)
- Recommendation: Run update in 3-5 days to complete the month

## 📊 Data Quality Indicators

### Good Signs ✅
- Latest data is 3-7 days old
- Updates find duplicates (means overlaps are working)
- Consistent event counts across recent days

### Action Needed ⚠️
- Latest data is >10 days old
- Zero duplicates found (may indicate no overlap)
- Large gaps in daily event counts

## 🎯 Recommended Update Strategy

### Conservative (Complete Coverage)
```r
# Run updates every 3-4 days
# Ensures no gaps, maximum data quality
# Good for: Critical analysis, official reports
```

### Balanced (Recommended)
```r
# Run updates weekly (e.g., every Monday)
# Good balance of freshness and completeness
# Good for: Regular analysis, monitoring
```

### Rapid (Near Real-time)
```r
# Run updates every 2-3 days
# Most current data, but may miss late additions
# Good for: Situational awareness, dashboards
```

## 🔧 Customizing Overlap Period

If you want more conservative updates, increase overlap:

Edit `scripts/update_acled.R`:
```r
result <- complete_acled_update(
  username = "mpurroyvitola@worldbank.org",
  overlap_days = 14  # Change from 7 to 14 days
)
```

**Pros:** Catches more late updates  
**Cons:** Downloads more duplicate data

## 📈 Month-End Best Practice

To ensure complete monthly data:

```r
# Example: Getting complete December 2025 data in early January 2026

# Step 1: Early January update (gets most of December)
source("scripts/update_acled.R")  # Jan 7

# Step 2: Mid-January update (completes December)
source("scripts/update_acled.R")  # Jan 15

# Step 3: Verify completeness
data <- read_csv("data/master/current/acled_data_current.csv")
dec_events <- data %>% filter(year(event_date) == 2025, month(event_date) == 12)
cat(sprintf("December 2025: %d events\n", nrow(dec_events)))
```

## 🎓 Understanding the Numbers

From your update:
- **Downloaded:** 27,178 records
- **Removed duplicates:** 7,643 events
- **Net new:** 19,535 events

This means:
- ✅ The overlap worked! (found 7,643 updates)
- ✅ Got 19,535 brand new events
- ✅ System is functioning correctly

## 💡 Pro Tips

1. **Check country summaries** to see which regions have recent updates
2. **Monitor fatality updates** - these often get corrected in overlaps
3. **Document your data version** using the dated backup files
4. **Run updates before major analysis** to ensure current data
5. **Set up scheduled tasks** for automatic weekly updates

## 📞 When to Contact Support

Contact ACLED if:
- Data is consistently >14 days old
- API returns errors repeatedly
- Expected events are missing after 14 days
- Account access issues

## 🎯 Summary

✅ **Normal:** Data is 3-10 days behind today  
✅ **Expected:** Run weekly updates for complete coverage  
✅ **Strategy:** Extra update early in month for previous month completion  
✅ **Overlap:** 7 days catches late updates and corrections  
✅ **Result:** High-quality, complete ACLED data  

**Your system is working perfectly!** The gap you see is ACLED's reporting delay, not a system issue.
