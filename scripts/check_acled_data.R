# Script to check and verify ACLED data structure and contents
# Provides detailed information about your ACLED data

library(dplyr)
library(readr)

cat("\n")
cat("=======================================================\n")
cat("ACLED DATA STRUCTURE CHECK\n")
cat("=======================================================\n")
cat(sprintf("Date: %s\n", Sys.time()))
cat("=======================================================\n\n")

# Check folder structure
cat("1. FOLDER STRUCTURE\n")
cat("-------------------------------------------------------\n")

folders <- list(
  "Master (Current)" = "data/master/current",
  "Master (Archive)" = "data/master/archive",
  "By Country" = "data/by_country",
  "Logs" = "logs"
)

for (name in names(folders)) {
  path <- folders[[name]]
  if (dir.exists(path)) {
    files <- list.files(path, pattern = "*.csv$")
    cat(sprintf("✓ %-20s: %s (%d files)\n", name, path, length(files)))
  } else {
    cat(sprintf("✗ %-20s: %s (missing)\n", name, path))
  }
}

cat("\n")
cat("2. MASTER FILES\n")
cat("-------------------------------------------------------\n")

master_current_dir <- "data/master/current"
master_archive_dir <- "data/master/archive"

if (dir.exists(master_current_dir)) {
  current_files <- list.files(master_current_dir, pattern = "*.csv$", full.names = TRUE)
  
  if (length(current_files) > 0) {
    for (file in current_files) {
      file_info <- file.info(file)
      size_mb <- round(file_info$size / 1024 / 1024, 2)
      cat(sprintf("  %s\n", basename(file)))
      cat(sprintf("    Size: %.2f MB\n", size_mb))
      cat(sprintf("    Modified: %s\n", file_info$mtime))
      
      # Try to read and get basic stats
      tryCatch({
        data <- read_csv(file, show_col_types = FALSE, n_max = 1)
        total_rows <- nrow(read_csv(file, show_col_types = FALSE))
        cat(sprintf("    Records: %,d\n", total_rows))
        
        # Get date range
        date_data <- read_csv(file, col_select = c(event_date), show_col_types = FALSE)
        cat(sprintf("    Date range: %s to %s\n", 
                   min(date_data$event_date, na.rm = TRUE),
                   max(date_data$event_date, na.rm = TRUE)))
      }, error = function(e) {
        cat("    (Could not read file details)\n")
      })
      cat("\n")
    }
  } else {
    cat("  No master files found.\n\n")
  }
} else {
  cat("  Master current directory not found.\n\n")
}

# Check archive
if (dir.exists(master_archive_dir)) {
  archive_files <- list.files(master_archive_dir, pattern = "*.csv$")
  cat(sprintf("  Archived versions: %d\n", length(archive_files)))
  
  if (length(archive_files) > 0) {
    cat("  Most recent archives:\n")
    archive_files_full <- list.files(master_archive_dir, pattern = "*.csv$", full.names = TRUE)
    file_info <- file.info(archive_files_full)
    sorted_files <- archive_files_full[order(file_info$mtime, decreasing = TRUE)]
    
    for (i in 1:min(3, length(sorted_files))) {
      file <- sorted_files[i]
      info <- file.info(file)
      size_mb <- round(info$size / 1024 / 1024, 2)
      cat(sprintf("    - %s (%.2f MB, %s)\n", 
                 basename(file), size_mb, format(info$mtime, "%Y-%m-%d %H:%M")))
    }
  }
}

cat("\n")
cat("3. COUNTRY FILES\n")
cat("-------------------------------------------------------\n")

country_dir <- "data/by_country"

if (dir.exists(country_dir)) {
  # Check for summary file
  summary_file <- file.path(country_dir, "country_summary.csv")
  
  if (file.exists(summary_file)) {
    summary <- read_csv(summary_file, show_col_types = FALSE)
    
    cat(sprintf("Total countries: %d\n", nrow(summary)))
    cat(sprintf("Total records across all countries: %,d\n", sum(summary$records)))
    cat(sprintf("Average records per country: %.1f\n\n", mean(summary$records)))
    
    cat("Top 10 countries by event count:\n")
    top10 <- head(summary %>% arrange(desc(records)), 10)
    for (i in 1:nrow(top10)) {
      cat(sprintf("  %2d. %-30s: %,8d events\n", 
                 i, top10$country[i], top10$records[i]))
    }
    
    cat("\n")
    cat("Recent updates:\n")
    updated <- summary %>% filter(grepl("Updated", status)) %>% arrange(desc(records))
    if (nrow(updated) > 0) {
      for (i in 1:min(5, nrow(updated))) {
        cat(sprintf("  - %-30s: %s\n", updated$country[i], updated$status[i]))
      }
    } else {
      cat("  No recent updates found.\n")
    }
    
  } else {
    country_files <- list.files(country_dir, pattern = "^acled_.*\\.csv$")
    cat(sprintf("Country files: %d\n", length(country_files)))
    cat("Note: Run update to generate country_summary.csv\n")
  }
} else {
  cat("Country directory not found.\n")
}

cat("\n")
cat("4. DATA QUALITY CHECK\n")
cat("-------------------------------------------------------\n")

# Try to load current master file
current_file <- file.path("data", "master", "current", "acled_data_current.csv")

if (file.exists(current_file)) {
  cat("Loading master file for quality checks...\n")
  
  tryCatch({
    data <- read_csv(current_file, show_col_types = FALSE)
    
    cat(sprintf("\nDataset overview:\n"))
    cat(sprintf("  Total records: %,d\n", nrow(data)))
    cat(sprintf("  Total columns: %d\n", ncol(data)))
    
    # Check for key columns
    key_columns <- c("event_id_cnty", "event_date", "country", "event_type", 
                    "latitude", "longitude", "fatalities")
    
    cat("\nKey columns present:\n")
    for (col in key_columns) {
      if (col %in% names(data)) {
        non_na <- sum(!is.na(data[[col]]))
        pct <- round(non_na / nrow(data) * 100, 1)
        cat(sprintf("  ✓ %-15s: %,d non-NA values (%.1f%%)\n", col, non_na, pct))
      } else {
        cat(sprintf("  ✗ %-15s : Missing\n", col))
      }
    }
    
    # Date range
    if ("event_date" %in% names(data)) {
      cat("\nDate coverage:\n")
      cat(sprintf("  First event: %s\n", min(data$event_date, na.rm = TRUE)))
      cat(sprintf("  Latest event: %s\n", max(data$event_date, na.rm = TRUE)))
      cat(sprintf("  Days covered: %d\n", 
                 as.numeric(difftime(max(data$event_date, na.rm = TRUE), 
                                    min(data$event_date, na.rm = TRUE), 
                                    units = "days"))))
    }
    
    # Check for duplicates
    if ("event_id_cnty" %in% names(data)) {
      duplicates <- sum(duplicated(data$event_id_cnty))
      if (duplicates > 0) {
        cat(sprintf("\n⚠ Warning: %d duplicate event IDs found\n", duplicates))
      } else {
        cat("\n✓ No duplicate event IDs found\n")
      }
    }
    
    # Fatalities stats
    if ("fatalities" %in% names(data)) {
      cat("\nFatalities statistics:\n")
      cat(sprintf("  Total fatalities: %,d\n", sum(data$fatalities, na.rm = TRUE)))
      cat(sprintf("  Events with fatalities: %,d (%.1f%%)\n", 
                 sum(data$fatalities > 0, na.rm = TRUE),
                 sum(data$fatalities > 0, na.rm = TRUE) / nrow(data) * 100))
      cat(sprintf("  Average fatalities per event: %.2f\n", 
                 mean(data$fatalities, na.rm = TRUE)))
    }
    
  }, error = function(e) {
    cat(sprintf("Error loading master file: %s\n", e$message))
  })
  
} else {
  cat("No master file found.\n")
  cat("Run update_acled.R to download data.\n")
}

cat("\n")
cat("5. RECOMMENDATIONS\n")
cat("-------------------------------------------------------\n")

# Check if data is outdated
if (file.exists(current_file)) {
  file_info <- file.info(current_file)
  days_since_update <- as.numeric(difftime(Sys.time(), file_info$mtime, units = "days"))
  
  if (days_since_update > 7) {
    cat(sprintf("⚠ Data was last updated %.0f days ago\n", days_since_update))
    cat("  Recommendation: Run update_acled.R to get latest data\n")
  } else {
    cat(sprintf("✓ Data is up to date (updated %.0f days ago)\n", days_since_update))
  }
} else {
  cat("⚠ No master data file found\n")
  cat("  Recommendation: Run update_acled.R to download ACLED data\n")
}

# Check for old root files
root_files <- list.files(".", pattern = "acled_data.*\\.csv$", full.names = FALSE)
if (length(root_files) > 0) {
  cat("\n⚠ Old ACLED files found in root directory:\n")
  for (file in root_files) {
    cat(sprintf("  - %s\n", file))
  }
  cat("  Recommendation: Run migrate_to_new_structure.R to organize files\n")
}

cat("\n")
cat("=======================================================\n")
cat("CHECK COMPLETE\n")
cat("=======================================================\n")
cat("\n")
cat("To update data: Run update_acled.R or update_acled.bat\n")
cat("To view summary: check data/by_country/country_summary.csv\n")
cat("\n")
