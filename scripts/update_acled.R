# =======================================================
# ACLED Data Update Script
# =======================================================
# This script updates ACLED data and splits it by country
# 
# How it works:
# 1. If no ACLED file exists: Downloads complete dataset from 1997
# 2. If ACLED file exists: Downloads only from latest date (with overlap)
# 3. Always creates/updates a master file with ALL data
# 4. Splits data into country-specific files
# 5. Archives old master files
#
# Folder structure:
#   data/
#     master/
#       current/    - Latest complete dataset
#       archive/    - Previous versions
#     by_country/   - Country-specific files
#   logs/           - Log files (if enabled)
# =======================================================

# Get the script directory and project root
script_path <- commandArgs(trailingOnly = FALSE)
script_file <- sub("--file=", "", script_path[grep("--file=", script_path)])
if (length(script_file) > 0) {
  script_dir <- dirname(script_file)
  project_root <- dirname(script_dir)
} else {
  # Fallback if running interactively
  script_dir <- if (basename(getwd()) == "scripts") getwd() else file.path(getwd(), "scripts")
  project_root <- if (basename(getwd()) == "scripts") dirname(getwd()) else getwd()
}

# Set working directory to project root
setwd(project_root)

# Source the required scripts
source(file.path(script_dir, "acled_incremental_updater.R"))
source(file.path(script_dir, "acled_country_splitter.R"))

# Run the complete update workflow
cat("\n")
cat("=======================================================\n")
cat("ACLED DATA UPDATE - STARTING\n")
cat("=======================================================\n")
cat(sprintf("Started at: %s\n", Sys.time()))
cat(sprintf("Working directory: %s\n", getwd()))
cat("\n")

# Read credentials from environment variables
# Set these in Databricks cluster env or local .Renviron
acled_username <- Sys.getenv(
  "ACLED_USERNAME",
  unset = "mpurroyvitola@worldbank.org"
)
acled_password <- Sys.getenv("ACLED_PASSWORD", unset = "")
acled_base_dir <- Sys.getenv("ACLED_BASE_DIR", unset = ".")

# Run complete update
result <- complete_acled_update(
  username = acled_username,
  base_dir = acled_base_dir,
  overlap_days = 360,
  password = if (nchar(acled_password) > 0) acled_password else NULL
)

# Display summary
cat("\n")
cat("=======================================================\n")
cat("TOP 20 COUNTRIES BY EVENT COUNT\n")
cat("=======================================================\n")
print(head(result$summary, 20))

cat("\n")
cat("=======================================================\n")
cat("FILES CREATED/UPDATED\n")
cat("=======================================================\n")
cat("Master file:", result$master_file, "\n")
cat("Country files:", result$country_dir, "\n")
cat("\n")
cat(sprintf("Completed at: %s\n", Sys.time()))
cat("=======================================================\n")
cat("\n")
