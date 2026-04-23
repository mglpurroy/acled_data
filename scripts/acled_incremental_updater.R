# Load required libraries
library(httr2)       # For making HTTP requests
library(jsonlite)    # For handling JSON data
library(dplyr)       # For data manipulation
library(readr)       # For reading/writing CSV files
library(lubridate)   # For date manipulation

# ============================================================================
# ACLED DATA UPDATE SYSTEM - INCREMENTAL UPDATER
# ============================================================================
#
# UPDATE STRATEGY - COMPLETE MONTH REFRESH:
# 1. Keeps all PREVIOUS months unchanged (stable historical data)
# 2. REMOVES entire current month from existing data
# 3. Downloads COMPLETE current month fresh from ACLED
# 4. Also downloads previous month overlap to catch late corrections
# 5. Merges: stable history + fresh current month + overlap period
# 6. Deduplicates overlap period based on event_id_cnty
#
# WHY THIS APPROACH:
# - Ensures current month is always complete and current
# - No gaps within the month due to reporting delays
# - Captures all late-reported events for current month
# - Previous months remain stable (no changes to historical data)
# - Overlap catches corrections to previous month
#
# EXAMPLE (Today: Jan 18):
# - Existing data: Jan 1-15 (partial)
# - Remove: All January data from existing
# - Download: Jan 1-18 (complete fresh data) + Dec overlap
# - Result: Complete January data + corrected December
#
# NEXT UPDATE (Jan 25):
# - Remove: All January data again
# - Download: Jan 1-25 (complete fresh data) + Dec overlap
# - Result: More complete January (no Jan 16-18 gap!)
#
# ACLED REPORTING DELAY:
# - ACLED has 3-10 day delay before data appears in API
# - Run weekly updates to keep current month fresh
# - By early next month, previous month will be complete
# ============================================================================

# ============================================================================
# FOLDER STRUCTURE SETUP
# ============================================================================

#' Initialize ACLED folder structure
#'
#' Creates organized folder structure for ACLED data management
#' @param base_dir Base directory for ACLED data (default: current directory)
initialize_folder_structure <- function(base_dir = ".") {
  folders <- c(
    file.path(base_dir, "data", "master", "current"),
    file.path(base_dir, "data", "master", "archive"),
    file.path(base_dir, "data", "by_country"),
    file.path(base_dir, "logs")
  )
  
  for (folder in folders) {
    if (!dir.exists(folder)) {
      dir.create(folder, recursive = TRUE)
      cat(sprintf("Created folder: %s\n", folder))
    }
  }
  
  invisible(TRUE)
}

# ============================================================================
# FILE MANAGEMENT FUNCTIONS
# ============================================================================

#' Find the most recent ACLED master file
#'
#' @param base_dir Base directory for ACLED data (default: current directory)
#' @return Path to the most recent master file, or NULL if none found
find_latest_acled_file <- function(base_dir = ".") {
  # Look in the current master folder first
  master_current <- file.path(base_dir, "data", "master", "current")
  
  if (dir.exists(master_current)) {
    files <- list.files(master_current, pattern = "acled_data_all.*\\.csv$", full.names = TRUE)
    
    if (length(files) > 0) {
      # Get file info and sort by modification time
      file_info <- file.info(files)
      latest_file <- rownames(file_info)[which.max(file_info$mtime)]
      
      cat(sprintf("Found latest master file: %s\n", basename(latest_file)))
      cat(sprintf("Last modified: %s\n", file_info[latest_file, "mtime"]))
      
      return(latest_file)
    }
  }
  
  # If no file in master/current, check root directory (for backward compatibility)
  root_files <- list.files(base_dir, pattern = "acled_data_all.*\\.csv$", full.names = TRUE)
  
  if (length(root_files) > 0) {
    file_info <- file.info(root_files)
    latest_file <- rownames(file_info)[which.max(file_info$mtime)]
    
    cat(sprintf("Found file in root (will be moved): %s\n", basename(latest_file)))
    return(latest_file)
  }
  
  cat("No existing ACLED master files found. Will download complete dataset.\n")
  return(NULL)
}

#' Archive old master file
#'
#' @param old_file Path to the file to archive
#' @param base_dir Base directory for ACLED data
archive_old_master <- function(old_file, base_dir = ".") {
  if (is.null(old_file) || !file.exists(old_file)) {
    return(invisible(FALSE))
  }
  
  archive_dir <- file.path(base_dir, "data", "master", "archive")
  
  # Create archive directory if it doesn't exist
  if (!dir.exists(archive_dir)) {
    dir.create(archive_dir, recursive = TRUE)
  }
  
  # Add timestamp to archived filename
  filename <- basename(old_file)
  archive_filename <- gsub("\\.csv$", 
                          sprintf("_archived_%s.csv", format(Sys.time(), "%Y%m%d_%H%M%S")), 
                          filename)
  archive_path <- file.path(archive_dir, archive_filename)
  
  # Move or copy the file
  if (dirname(old_file) == file.path(base_dir, "data", "master", "current")) {
    file.rename(old_file, archive_path)
    cat(sprintf("Archived old master file to: %s\n", archive_path))
  } else {
    # If file is in root, just copy it (don't remove original yet)
    file.copy(old_file, archive_path)
    cat(sprintf("Copied old master file to archive: %s\n", archive_path))
  }
  
  invisible(TRUE)
}

# ============================================================================
# DATA RETRIEVAL FUNCTIONS
# ============================================================================

#' Get the latest event date from existing data
#'
#' @param filepath Path to the existing ACLED CSV file
#' @return Latest event date as Date object
get_latest_event_date <- function(filepath) {
  cat("Reading existing data to find latest date...\n")
  
  # Read just the event_date column for efficiency
  data <- read_csv(filepath, col_select = c(event_date), show_col_types = FALSE)
  
  latest_date <- max(as.Date(data$event_date), na.rm = TRUE)
  cat(sprintf("Latest event date in existing data: %s\n", latest_date))
  
  return(latest_date)
}

#' Fetch ACLED data from API
#'
#' @param username Your ACLED username (email)
#' @param start_date Date to start fetching from (as Date object or string "YYYY-MM-DD")
#' @param countries Character vector of country names (use NULL for all countries)
#' @param fields Optional pipe-separated list of fields to return (NULL returns all fields)
#' @param password Optional password (if not provided, a password box will pop up)
#' @return A data frame containing ACLED events from start_date onwards
fetch_acled_data <- function(username, start_date, countries = NULL, 
                            fields = NULL, password = NULL) {
  base_url <- "https://acleddata.com/api/acled/read?_format=json"
  token_url <- "https://acleddata.com/oauth/token"
  all_data <- list()
  page <- 1
  has_more_data <- TRUE
  
  # Ensure start_date is a Date object
  start_date <- as.Date(start_date)
  
  # Set up OAuth client
  client <- oauth_client("acled", token_url)
  
  # Build country parameter string
  if (!is.null(countries) && length(countries) > 0) {
    country_param <- paste(countries, collapse = ":OR:country=")
    cat(sprintf("Fetching data for: %s\n", paste(countries, collapse = ", ")))
  } else {
    country_param <- NULL
    cat("Fetching data for ALL countries\n")
  }
  
  # Set end date to today
  end_date <- Sys.Date()
  
  cat(sprintf("Fetching events from %s to %s\n", start_date, end_date))
  
  while(has_more_data) {
    # Build the parameters with proper date range for BETWEEN operator
    # ACLED API expects: event_date=start|end when using BETWEEN
    date_range <- paste(format(start_date, "%Y-%m-%d"), 
                       format(end_date, "%Y-%m-%d"), 
                       sep = "|")
    
    params <- list(
      page = page,
      event_date = date_range,
      event_date_where = "BETWEEN"
    )
    
    # Add country parameter if specified
    if (!is.null(country_param)) {
      params$country <- country_param
    }
    
    # Add optional parameters
    if (!is.null(fields)) {
      params$fields <- fields
    }
    
    cat(sprintf("Fetching page %d...\n", page))
    
    tryCatch({
      # Build request with OAuth authentication
      req <- request(base_url)
      
      if (!is.null(password)) {
        req <- req_oauth_password(req, client = client, username = username, password = password)
      } else {
        req <- req_oauth_password(req, client = client, username = username)
      }
      
      # Add parameters and execute
      response <- req %>%
        req_url_query(!!!params) %>%
        req_perform()
      
      # Parse the JSON response
      data <- resp_body_json(response, simplifyVector = TRUE)
      
      # Check if we got any data back
      if (is.null(data$data) || length(data$data) == 0 || nrow(data$data) == 0) {
        has_more_data <- FALSE
        cat("No more data to fetch.\n")
      } else {
        # Add the new data to our collection
        all_data <- c(all_data, list(as_tibble(data$data)))
        
        # Print progress
        cat(sprintf("Retrieved %d records. Total so far: %d\n", 
                   nrow(data$data), 
                   sum(sapply(all_data, nrow))))
        
        # Move to the next page
        page <- page + 1
      }
      
      # Add a small delay to avoid hitting rate limits
      Sys.sleep(0.5)
      
    }, error = function(e) {
      cat(sprintf("Error: %s\n", e$message))
      has_more_data <- FALSE
    })
  }
  
  # Process the results
  if (length(all_data) == 0) {
    cat("No new data retrieved.\n")
    return(NULL)
  }
  
  # Combine all data into a single dataframe
  final_data <- bind_rows(all_data)
  
  # Convert date strings to Date objects
  if ("event_date" %in% names(final_data)) {
    final_data$event_date <- as.Date(final_data$event_date)
  }
  
  # Convert numeric strings to actual numbers where appropriate
  numeric_cols <- c("latitude", "longitude", "fatalities", "iso")
  for (col in numeric_cols) {
    if (col %in% names(final_data)) {
      final_data[[col]] <- as.numeric(final_data[[col]])
    }
  }
  
  cat(sprintf("Completed fetching data. Total records: %d\n", nrow(final_data)))
  
  return(final_data)
}

# ============================================================================
# MAIN UPDATE FUNCTION
# ============================================================================

#' Update ACLED data incrementally or perform full download
#'
#' This function intelligently handles both scenarios:
#' 1. No existing file: Downloads complete dataset from 1997 to present
#' 2. Existing file: Downloads only new data with overlap period for updates
#'
#' @param username Your ACLED username (email)
#' @param base_dir Base directory for ACLED data (default: current directory)
#' @param existing_file Path to existing ACLED file (if NULL, searches for latest)
#' @param countries Character vector of country names (use NULL for all countries)
#' @param overlap_days Number of days to overlap to catch late updates (default: 7)
#' @param password Optional password
#' @return Updated data frame
update_acled_data <- function(username, base_dir = ".", existing_file = NULL, 
                              countries = NULL, overlap_days = 7, password = NULL) {
  
  # Initialize folder structure
  cat("\n=== Initializing folder structure ===\n")
  initialize_folder_structure(base_dir)
  
  # Find existing file if not provided
  if (is.null(existing_file)) {
    existing_file <- find_latest_acled_file(base_dir)
  }
  
  # Determine starting point and mode
  is_full_download <- FALSE
  
  if (!is.null(existing_file) && file.exists(existing_file)) {
    # INCREMENTAL UPDATE MODE
    cat("\n=== INCREMENTAL UPDATE MODE WITH MONTH REFRESH ===\n")
    cat("Loading existing data...\n")
    existing_data <- read_csv(existing_file, show_col_types = FALSE)
    cat(sprintf("Loaded %d existing records\n", nrow(existing_data)))
    
    # Get latest date for information
    latest_date <- get_latest_event_date(existing_file)
    
    # Calculate start of current month to ensure complete month coverage
    current_month_start <- floor_date(Sys.Date(), "month")
    
    # Use either start of current month OR (latest_date - overlap), whichever is earlier
    # This ensures we get the entire current month plus any recent previous month updates
    overlap_start <- latest_date - days(overlap_days)
    start_date <- min(current_month_start, overlap_start)
    
    cat(sprintf("Will fetch from %s to ensure complete current month\n", start_date))
    cat(sprintf("(Current month starts: %s, Latest date in data: %s)\n", 
               current_month_start, latest_date))
    cat("Strategy: Re-download entire current month + overlap for previous month\n")
    
  } else {
    # FULL DOWNLOAD MODE
    cat("\n=== FULL DOWNLOAD MODE ===\n")
    cat("No existing file found.\n")
    cat("Downloading complete ACLED dataset from 1997 to present...\n")
    cat("This may take several minutes...\n\n")
    
    existing_data <- NULL
    start_date <- as.Date("1997-01-01")  # ACLED data starts from 1997
    is_full_download <- TRUE
  }
  
  # Fetch new/updated data
  cat("\n=== Fetching data from ACLED API ===\n")
  new_data <- fetch_acled_data(username, start_date, countries, password = password)
  
  if (is.null(new_data)) {
    cat("No new data to add.\n")
    if (!is.null(existing_data)) {
      return(existing_data)
    } else {
      stop("Failed to fetch data and no existing data available.")
    }
  }
  
  # Combine and deduplicate
  cat("\n=== Processing and deduplicating data ===\n")
  
  if (!is.null(existing_data)) {
    # Fix data type mismatches before combining
    # Convert problematic columns to character in both datasets
    if ("time_precision" %in% names(existing_data)) {
      existing_data$time_precision <- as.character(existing_data$time_precision)
    }
    if ("time_precision" %in% names(new_data)) {
      new_data$time_precision <- as.character(new_data$time_precision)
    }
    
    # Remove current month from existing data to ensure complete month replacement
    current_month_start <- floor_date(Sys.Date(), "month")
    existing_data_filtered <- existing_data %>%
      filter(event_date < current_month_start)
    
    removed_count <- nrow(existing_data) - nrow(existing_data_filtered)
    if (removed_count > 0) {
      cat(sprintf("Removed %d existing events from current month (will be replaced with fresh data)\n", 
                 removed_count))
    }
    
    # Combine: stable historical data + fresh current month + overlap period
    combined_data <- bind_rows(existing_data_filtered, new_data)
    cat(sprintf("Combined total before deduplication: %d records\n", nrow(combined_data)))
    
    # Remove duplicates based on event_id_cnty (ACLED's unique identifier)
    # This catches any overlapping events from the previous month
    if ("event_id_cnty" %in% names(combined_data)) {
      updated_data <- combined_data %>%
        arrange(desc(timestamp)) %>%  # Keep most recent version if duplicate
        distinct(event_id_cnty, .keep_all = TRUE) %>%
        arrange(event_date)
      
      duplicates_removed <- nrow(combined_data) - nrow(updated_data)
      cat(sprintf("Removed %d duplicate events from overlap period\n", duplicates_removed))
    } else {
      warning("event_id_cnty not found - using all columns for deduplication")
      updated_data <- combined_data %>%
        distinct() %>%
        arrange(event_date)
    }
  } else {
    # First time download - just use new data
    updated_data <- new_data %>% arrange(event_date)
  }
  
  cat(sprintf("Final dataset: %s records\n", format(nrow(updated_data), big.mark = ",")))
  
  # Archive old master file if it exists
  if (!is.null(existing_file) && file.exists(existing_file)) {
    cat("\n=== Archiving previous master file ===\n")
    archive_old_master(existing_file, base_dir)
  }
  
  # Save updated master file to current folder
  output_file <- file.path(base_dir, "data", "master", "current", 
                           sprintf("acled_data_all_%s.csv", format(Sys.Date(), "%m%d%Y")))
  
  cat(sprintf("\n=== Saving updated master file ===\n"))
  cat(sprintf("Output: %s\n", output_file))
  write_csv(updated_data, output_file)
  
  # Also save a copy without date for easy access
  current_file <- file.path(base_dir, "data", "master", "current", "acled_data_current.csv")
  write_csv(updated_data, current_file)
  cat(sprintf("Also saved as: %s\n", basename(current_file)))
  
  # Clean up old file from root if it was there
  if (!is.null(existing_file) && dirname(existing_file) == base_dir) {
    unlink(existing_file)
    cat(sprintf("Removed old file from root directory\n"))
  }
  
  # Print summary statistics
  cat("\n=======================================================\n")
  cat("UPDATE SUMMARY\n")
  cat("=======================================================\n")
  cat(sprintf("Mode: %s\n", ifelse(is_full_download, "Full Download", "Incremental Update with Month Refresh")))
  
  latest_data_date <- max(updated_data$event_date, na.rm = TRUE)
  cat(sprintf("Date range: %s to %s\n", 
             min(updated_data$event_date, na.rm = TRUE),
             latest_data_date))
  cat(sprintf("Total events: %s\n", format(nrow(updated_data), big.mark = ",")))
  
  if (!is.null(existing_data)) {
    net_new <- nrow(updated_data) - nrow(existing_data)
    cat(sprintf("Net change: %+d events\n", net_new))
  }
  
  if ("country" %in% names(updated_data)) {
    cat(sprintf("Countries covered: %d\n", length(unique(updated_data$country))))
  }
  
  # Current month info
  current_month <- format(Sys.Date(), "%B %Y")
  current_month_events <- updated_data %>%
    filter(year(event_date) == year(Sys.Date()), 
           month(event_date) == month(Sys.Date())) %>%
    nrow()
  
  if (current_month_events > 0) {
    cat(sprintf("\nCurrent month (%s): %s events\n", 
               current_month, format(current_month_events, big.mark = ",")))
    cat("✓ Current month data refreshed from ACLED API\n")
  }
  
  # Check for data availability gap
  days_behind <- as.numeric(Sys.Date() - latest_data_date)
  if (days_behind > 3) {
    cat(sprintf("\n⚠ Latest data is from %s (%d days ago)\n", 
               latest_data_date, days_behind))
    cat("ACLED typically has a 3-10 day reporting delay.\n")
    cat("Run weekly updates to keep current month complete.\n")
  } else if (days_behind >= 0) {
    cat(sprintf("\n✓ Data is current (latest: %s, %d days ago)\n", 
               latest_data_date, days_behind))
  }
  
  cat("=======================================================\n")
  
  return(updated_data)
}

# ============================================================================
# USAGE EXAMPLES
# ============================================================================

# Example 1: Simple update - finds latest file automatically
# data <- update_acled_data(username = "mpurroyvitola@worldbank.org")

# Example 2: Update with specific overlap period (14 days)
# data <- update_acled_data(
#   username = "mpurroyvitola@worldbank.org",
#   overlap_days = 14
# )

# Example 3: Update specific countries only
# data <- update_acled_data(
#   username = "mpurroyvitola@worldbank.org",
#   countries = c("Afghanistan", "Pakistan"),
#   overlap_days = 7
# )

# Example 4: Specify existing file explicitly
# data <- update_acled_data(
#   username = "mpurroyvitola@worldbank.org",
#   existing_file = "data/master/current/acled_data_all_20251210.csv",
#   overlap_days = 7
# )

# Example 5: With password provided (no prompt)
# data <- update_acled_data(
#   username = "mpurroyvitola@worldbank.org",
#   password = "your_password_here",
#   overlap_days = 7
# )
