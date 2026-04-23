# Migration Script: Move existing ACLED data to new folder structure
# Run this once to migrate from old structure to new organized structure

library(dplyr)
library(readr)

cat("\n")
cat("=======================================================\n")
cat("ACLED DATA MIGRATION TO NEW STRUCTURE\n")
cat("=======================================================\n")
cat("\n")

# Initialize new folder structure
cat("Step 1: Creating new folder structure...\n")
folders <- c(
  "data/master/current",
  "data/master/archive",
  "data/by_country",
  "logs"
)

for (folder in folders) {
  if (!dir.exists(folder)) {
    dir.create(folder, recursive = TRUE)
    cat(sprintf("  Created: %s\n", folder))
  } else {
    cat(sprintf("  Exists: %s\n", folder))
  }
}

cat("\n")
cat("Step 2: Looking for existing ACLED files in root directory...\n")

# Find all ACLED master files in root
root_files <- list.files(".", pattern = "acled_data_all.*\\.csv$", full.names = FALSE)

if (length(root_files) == 0) {
  cat("  No ACLED master files found in root directory.\n")
  cat("  Nothing to migrate.\n")
} else {
  cat(sprintf("  Found %d file(s):\n", length(root_files)))
  
  for (file in root_files) {
    cat(sprintf("    - %s\n", file))
  }
  
  # Get the most recent file
  file_info <- file.info(root_files)
  latest_file <- rownames(file_info)[which.max(file_info$mtime)]
  
  cat("\n")
  cat(sprintf("Step 3: Moving latest file to master/current...\n"))
  cat(sprintf("  Latest file: %s\n", latest_file))
  
  # Move latest file to current
  new_location <- file.path("data", "master", "current", basename(latest_file))
  file.copy(latest_file, new_location)
  cat(sprintf("  Copied to: %s\n", new_location))
  
  # Also save as current
  current_file <- file.path("data", "master", "current", "acled_data_current.csv")
  file.copy(latest_file, current_file)
  cat(sprintf("  Also saved as: %s\n", basename(current_file)))
  
  # Archive other files
  other_files <- root_files[root_files != latest_file]
  
  if (length(other_files) > 0) {
    cat("\n")
    cat(sprintf("Step 4: Archiving %d older file(s)...\n", length(other_files)))
    
    for (file in other_files) {
      archive_name <- gsub("\\.csv$", 
                          sprintf("_archived_%s.csv", format(Sys.time(), "%Y%m%d_%H%M%S")), 
                          basename(file))
      archive_path <- file.path("data", "master", "archive", archive_name)
      file.copy(file, archive_path)
      cat(sprintf("  Archived: %s -> %s\n", file, archive_name))
    }
  }
}

# Move country files
cat("\n")
cat("Step 5: Looking for country files folder...\n")

old_country_dir <- "acled_by_country"
new_country_dir <- "data/by_country"

if (dir.exists(old_country_dir) && old_country_dir != new_country_dir) {
  country_files <- list.files(old_country_dir, pattern = "*.csv$", full.names = FALSE)
  
  if (length(country_files) > 0) {
    cat(sprintf("  Found %d country files in '%s'\n", length(country_files), old_country_dir))
    cat("  Moving to new location...\n")
    
    for (file in country_files) {
      old_path <- file.path(old_country_dir, file)
      new_path <- file.path(new_country_dir, file)
      file.copy(old_path, new_path, overwrite = TRUE)
    }
    
    cat(sprintf("  Moved %d files to '%s'\n", length(country_files), new_country_dir))
  } else {
    cat("  No files found to move.\n")
  }
} else if (dir.exists(new_country_dir)) {
  country_files <- list.files(new_country_dir, pattern = "*.csv$")
  cat(sprintf("  Country files already in correct location (%d files)\n", length(country_files)))
} else {
  cat("  No existing country files found.\n")
}

# Cleanup prompt
cat("\n")
cat("=======================================================\n")
cat("MIGRATION SUMMARY\n")
cat("=======================================================\n")

# Count files in new structure
master_current <- list.files("data/master/current", pattern = "*.csv$")
master_archive <- list.files("data/master/archive", pattern = "*.csv$")
country_files <- list.files("data/by_country", pattern = "*.csv$")

cat(sprintf("Master files (current): %d\n", length(master_current)))
cat(sprintf("Master files (archive): %d\n", length(master_archive)))
cat(sprintf("Country files: %d\n", length(country_files)))

cat("\n")
cat("New folder structure:\n")
cat("  data/\n")
cat("    master/\n")
cat("      current/     - Latest complete dataset\n")
cat("      archive/     - Previous versions\n")
cat("    by_country/    - Country-specific files\n")
cat("  logs/            - Update logs\n")

cat("\n")
cat("=======================================================\n")
cat("MIGRATION COMPLETE!\n")
cat("=======================================================\n")

if (length(root_files) > 0) {
  cat("\n")
  cat("OPTIONAL CLEANUP:\n")
  cat("Old files in root directory can now be deleted:\n")
  for (file in root_files) {
    cat(sprintf("  - %s\n", file))
  }
  
  if (dir.exists(old_country_dir) && old_country_dir != new_country_dir) {
    cat(sprintf("\nOld country folder can be deleted:\n  - %s/\n", old_country_dir))
  }
  
  cat("\nTo delete them, run:\n")
  cat('  file.remove(c("', paste(root_files, collapse = '", "'), '"))\n', sep = "")
  if (dir.exists(old_country_dir) && old_country_dir != new_country_dir) {
    cat(sprintf('  unlink("%s", recursive = TRUE)\n', old_country_dir))
  }
}

cat("\n")
cat("You can now use update_acled.R as usual.\n")
cat("It will automatically use the new structure.\n")
cat("\n")

