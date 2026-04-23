# Load required libraries
library(dplyr)
library(readr)
library(purrr)

#' Update country-specific files incrementally
#'
#' @param master_file Path to the master ACLED data file (if NULL, finds latest)
#' @param base_dir Base directory for ACLED data (default: current directory)
#' @param filename_prefix Prefix for country filenames (default: "acled_")
#' @return A summary data frame showing countries and record counts
update_country_files <- function(master_file = NULL, 
                                 base_dir = ".",
                                 filename_prefix = "acled_") {
  
  # Find master file if not provided
  if (is.null(master_file)) {
    master_current_dir <- file.path(base_dir, "data", "master", "current")
    
    # Look for current file first
    current_file <- file.path(master_current_dir, "acled_data_current.csv")
    
    if (file.exists(current_file)) {
      master_file <- current_file
    } else {
      # Look for any dated file
      files <- list.files(master_current_dir, pattern = "acled_data_all.*\\.csv$", full.names = TRUE)
      
      if (length(files) > 0) {
        file_info <- file.info(files)
        master_file <- rownames(file_info)[which.max(file_info$mtime)]
      } else {
        stop("No master file found. Please run update_acled_data() first.")
      }
    }
  }
  
  # Ensure output directory exists
  output_dir <- file.path(base_dir, "data", "by_country")
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  # Load master data
  cat(sprintf("Loading master file: %s\n", master_file))
  master_data <- read_csv(master_file, show_col_types = FALSE)
  
  # Check if country column exists
  if (!"country" %in% names(master_data)) {
    stop("'country' column not found in data")
  }
  
  # Get unique countries
  countries <- unique(master_data$country)
  cat(sprintf("\nProcessing %d unique countries...\n\n", length(countries)))
  
  # Initialize summary
  summary_data <- data.frame(
    country = character(),
    records = integer(),
    date_range = character(),
    filename = character(),
    status = character(),
    stringsAsFactors = FALSE
  )
  
  # Process each country
  for (country in countries) {
    # Create clean filename
    clean_name <- gsub("[^A-Za-z0-9]", "_", country)
    clean_name <- gsub("_+", "_", clean_name)
    clean_name <- gsub("^_|_$", "", clean_name)
    
    filename <- sprintf("%s%s.csv", filename_prefix, clean_name)
    filepath <- file.path(output_dir, filename)
    
    # Filter data for this country
    country_data <- master_data %>% filter(country == !!country)
    
    # Get date range for this country
    date_range <- sprintf("%s to %s", 
                         min(country_data$event_date, na.rm = TRUE),
                         max(country_data$event_date, na.rm = TRUE))
    
    # Check if file exists and update incrementally
    if (file.exists(filepath)) {
      # Read existing data
      existing_data <- read_csv(filepath, show_col_types = FALSE)
      
      # Combine and deduplicate
      combined <- bind_rows(existing_data, country_data)
      
      if ("event_id_cnty" %in% names(combined)) {
        final_data <- combined %>%
          arrange(desc(timestamp)) %>%
          distinct(event_id_cnty, .keep_all = TRUE) %>%
          arrange(event_date)
      } else {
        final_data <- combined %>%
          distinct() %>%
          arrange(event_date)
      }
      
      # Check if there are changes
      if (nrow(final_data) != nrow(existing_data)) {
        write_csv(final_data, filepath)
        status <- sprintf("Updated (+%d)", nrow(final_data) - nrow(existing_data))
      } else {
        status <- "No change"
      }
      
    } else {
      # New country file
      final_data <- country_data
      write_csv(final_data, filepath)
      status <- "New"
    }
    
    # Add to summary
    summary_data <- rbind(summary_data, data.frame(
      country = country,
      records = nrow(final_data),
      date_range = date_range,
      filename = filename,
      status = status,
      stringsAsFactors = FALSE
    ))
    
    cat(sprintf("%-40s: %6d records [%s]\n", country, nrow(final_data), status))
  }
  
  # Sort summary by number of records (descending)
  summary_data <- summary_data %>% arrange(desc(records))
  
  # Save summary file
  summary_file <- file.path(output_dir, "country_summary.csv")
  write_csv(summary_data, summary_file)
  
  # Print summary statistics
  cat(sprintf("\n=======================================================\n"))
  cat("COUNTRY FILES SUMMARY\n")
  cat("=======================================================\n")
  cat(sprintf("Total countries: %d\n", nrow(summary_data)))
  cat(sprintf("Total records: %s\n", format(sum(summary_data$records), big.mark = ",")))
  cat(sprintf("Average records per country: %.1f\n", mean(summary_data$records)))
  cat(sprintf("New countries: %d\n", sum(summary_data$status == "New")))
  cat(sprintf("Updated countries: %d\n", sum(grepl("Updated", summary_data$status))))
  cat(sprintf("Unchanged countries: %d\n", sum(summary_data$status == "No change")))
  cat(sprintf("\nFiles saved to: %s\n", output_dir))
  cat(sprintf("Summary saved to: %s\n", summary_file))
  cat("=======================================================\n")
  
  return(summary_data)
}

#' Complete workflow: Update master file and split by country
#'
#' @param username Your ACLED username
#' @param base_dir Base directory for ACLED data (default: current directory)
#' @param countries Countries to fetch (NULL for all)
#' @param overlap_days Days of overlap for incremental update
#' @param master_file Existing master file (NULL to auto-detect)
#' @param password Optional password
#' @return List containing updated data, summary, and file paths
complete_acled_update <- function(username,
                                  base_dir = ".",
                                  countries = NULL,
                                  overlap_days = 7,
                                  master_file = NULL,
                                  password = NULL) {
  
  # Source the updater script if not already loaded
  if (!exists("update_acled_data")) {
    # Try to find the script in the same directory
    script_path <- if (file.exists("acled_incremental_updater.R")) {
      "acled_incremental_updater.R"
    } else if (file.exists("scripts/acled_incremental_updater.R")) {
      "scripts/acled_incremental_updater.R"
    } else {
      stop("Cannot find acled_incremental_updater.R")
    }
    source(script_path)
  }
  
  cat("\n")
  cat("=======================================================\n")
  cat("ACLED DATA COMPLETE UPDATE WORKFLOW\n")
  cat("=======================================================\n")
  cat(sprintf("Date: %s\n", Sys.time()))
  cat(sprintf("User: %s\n", username))
  cat("=======================================================\n\n")
  
  # Step 1: Update master file
  cat("STEP 1: Updating master ACLED data file\n")
  cat("-------------------------------------------------------\n")
  
  updated_data <- update_acled_data(
    username = username,
    base_dir = base_dir,
    existing_file = master_file,
    countries = countries,
    overlap_days = overlap_days,
    password = password
  )
  
  # Get the output filename
  output_master <- file.path(base_dir, "data", "master", "current", "acled_data_current.csv")
  
  cat("\n\n")
  cat("STEP 2: Splitting data by country\n")
  cat("-------------------------------------------------------\n")
  
  # Step 2: Split by country
  summary <- update_country_files(
    master_file = output_master,
    base_dir = base_dir
  )
  
  cat("\n")
  cat("=======================================================\n")
  cat("COMPLETE WORKFLOW FINISHED SUCCESSFULLY\n")
  cat("=======================================================\n")
  cat(sprintf("Master file: %s\n", output_master))
  cat(sprintf("Country files: %s\n", file.path(base_dir, "data", "by_country")))
  cat(sprintf("Archive: %s\n", file.path(base_dir, "data", "master", "archive")))
  cat("=======================================================\n\n")
  
  return(list(
    data = updated_data,
    summary = summary,
    master_file = output_master,
    country_dir = file.path(base_dir, "data", "by_country")
  ))
}

# ============================================================================
# USAGE EXAMPLES
# ============================================================================

# Example 1: Complete workflow - update everything
# result <- complete_acled_update(
#   username = "mpurroyvitola@worldbank.org"
# )

# Example 2: Update with custom overlap
# result <- complete_acled_update(
#   username = "mpurroyvitola@worldbank.org",
#   overlap_days = 14
# )

# Example 3: Update only specific countries
# result <- complete_acled_update(
#   username = "mpurroyvitola@worldbank.org",
#   countries = c("Ukraine", "Afghanistan", "Sudan"),
#   overlap_days = 7
# )

# Example 4: Just update country files from existing master
# summary <- update_country_files()

# Example 5: View top 20 countries by event count
# summary <- update_country_files()
# head(summary, 20)
