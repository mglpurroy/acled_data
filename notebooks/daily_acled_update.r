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

cat(sprintf(
  "Writing %s records to Delta table: %s\n",
  format(nrow(updated_data), big.mark = ","),
  DELTA_TABLE
))

spark_df <- as.DataFrame(updated_data)
saveAsTable(spark_df, DELTA_TABLE, source = "delta", mode = "overwrite")

cat("Delta table updated successfully.\n")

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
