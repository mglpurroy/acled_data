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

# DBFS used as working storage for incremental updates
base_dir <- "/dbfs/acled"

# COMMAND ----------

acled_password <- Sys.getenv("ACLED_PASSWORD", unset = "")
acled_username <- Sys.getenv(
  "ACLED_USERNAME",
  unset = "mpurroyvitola@worldbank.org"
)

if (nchar(acled_password) == 0) {
  stop("ACLED_PASSWORD env var not set. Add it to the cluster environment variables.")
}

# COMMAND ----------

# Download and merge ACLED data (incremental update)
source(file.path(scripts_dir, "acled_incremental_updater.R"))

updated_data <- update_acled_data(
  username  = acled_username,
  base_dir  = base_dir,
  overlap_days = 30,
  password  = acled_password
)

# COMMAND ----------

# Write to Delta table in Unity Catalog
library(SparkR)

DELTA_TABLE <- paste0(
  "prd_datascience_compoundriskmonitor.",
  "compoundriskmonitor.acled"
)

# Create schema if it doesn't exist
sql("CREATE SCHEMA IF NOT EXISTS prd_datascience_compoundriskmonitor.compoundriskmonitor")

cat(sprintf(
  "Merging %s records into Delta table: %s\n",
  format(nrow(updated_data), big.mark = ","),
  DELTA_TABLE
))

spark_df <- as.DataFrame(updated_data)

# First run: table doesn't exist yet — create it
table_exists <- tryCatch({
  sql(sprintf("DESCRIBE %s", DELTA_TABLE))
  TRUE
}, error = function(e) FALSE)

if (!table_exists) {
  cat("Table not found — creating for the first time.\n")
  saveAsTable(spark_df, DELTA_TABLE, source = "delta", mode = "overwrite")
} else {
  # Subsequent runs: merge — insert new events, update changed ones
  createOrReplaceTempView(spark_df, "acled_updates")
  sql(sprintf("
    MERGE INTO %s AS target
    USING acled_updates AS source
    ON target.event_id_cnty = source.event_id_cnty
    WHEN MATCHED THEN UPDATE SET *
    WHEN NOT MATCHED THEN INSERT *
  ", DELTA_TABLE))
}

cat("Delta table updated successfully.\n")

# COMMAND ----------

# Export CSV to Unity Catalog Volume for R/Python package access
volume_path <- paste0(
  "/Volumes/prd_datascience_compoundriskmonitor/volumes/",
  "compoundriskmonitor/fcvriskdashboard/acled_data_current.csv"
)
current_csv <- file.path(
  base_dir, "data", "master", "current", "acled_data_current.csv"
)

cat(sprintf("Exporting CSV to Volume: %s\n", volume_path))
tryCatch({
  file.copy(current_csv, volume_path, overwrite = TRUE)
  cat("Volume export successful.\n")
}, error = function(e) {
  cat(sprintf("Warning: Volume export failed: %s\n", e$message))
})

# COMMAND ----------

# Clean up old archives — keep only the 2 most recent
archive_dir <- file.path(base_dir, "data", "master", "archive")
if (dir.exists(archive_dir)) {
  archives <- sort(
    list.files(archive_dir, full.names = TRUE),
    decreasing = TRUE
  )
  to_delete <- archives[-(1:2)]
  if (length(to_delete) > 0) {
    file.remove(to_delete)
    cat(sprintf("Cleaned up %d old archive(s).\n", length(to_delete)))
  }
}

cat(sprintf("Completed at: %s\n", Sys.time()))
