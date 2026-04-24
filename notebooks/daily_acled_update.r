# Databricks notebook source
# ACLED Daily Update Job
# Schedule this notebook via Databricks Jobs (Workflows > Create Job)

# COMMAND ----------

# Find scripts dir by checking known Databricks Repo paths
candidate_dirs <- c(
  Sys.getenv("ACLED_SCRIPTS_DIR", unset = ""),
  "/Workspace/Repos/mpurroyvitola@worldbank.org/acled_data/scripts",
  "/Workspace/Repos/mglpurroy@gmail.com/acled_data/scripts",
  "/Workspace/Users/mpurroyvitola@worldbank.org/acled_data/scripts"
)

scripts_dir <- NULL
for (d in candidate_dirs) {
  if (nchar(d) > 0 &&
      file.exists(file.path(d, "acled_incremental_updater.R"))) {
    scripts_dir <- d
    break
  }
}

if (is.null(scripts_dir)) {
  stop(
    "Cannot find scripts. Tried: ",
    paste(candidate_dirs[nchar(candidate_dirs) > 0], collapse = ", ")
  )
}
cat(sprintf("Using scripts from: %s\n", scripts_dir))

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

