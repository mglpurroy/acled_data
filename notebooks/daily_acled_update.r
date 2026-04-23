# Databricks notebook source
# ACLED Daily Update Job
# Schedule this notebook via Databricks Jobs (Workflows > Create Job)

# COMMAND ----------

# Resolve paths: Git Folder root and data storage on DBFS
repo_root <- dirname(dirname(sys.frame(1)$ofile %||% "/Workspace/placeholder"))
scripts_dir <- file.path(repo_root, "scripts")

# Fallback: hardcode if path detection fails (update username if needed)
if (!dir.exists(scripts_dir)) {
  scripts_dir <- "/Workspace/Repos/mglpurroy@gmail.com/acled_data/scripts"
}

# Data goes to DBFS so it persists across cluster restarts
base_dir <- "/dbfs/acled"

# COMMAND ----------

# Get credentials
# Option A: Databricks secret (recommended)
#   dbutils.secrets.get(scope="acled", key="password")  <- run this in Python cell
# Option B: Cluster environment variable ACLED_PASSWORD
acled_password <- Sys.getenv("ACLED_PASSWORD", unset = "")
acled_username <- Sys.getenv(
  "ACLED_USERNAME",
  unset = "mpurroyvitola@worldbank.org"
)

if (nchar(acled_password) == 0) {
  stop("ACLED_PASSWORD env var not set. Add it to the cluster environment variables.")
}

# COMMAND ----------

# Source scripts from the Git Folder
source(file.path(scripts_dir, "acled_incremental_updater.R"))
source(file.path(scripts_dir, "acled_country_splitter.R"))

# COMMAND ----------

# Run the full update
result <- complete_acled_update(
  username = acled_username,
  base_dir = base_dir,
  overlap_days = 360,
  password = acled_password
)

# COMMAND ----------

cat("=== TOP 20 COUNTRIES BY EVENT COUNT ===\n")
print(head(result$summary, 20))
cat(sprintf("\nMaster file: %s\n", result$master_file))
cat(sprintf("Completed at: %s\n", Sys.time()))
