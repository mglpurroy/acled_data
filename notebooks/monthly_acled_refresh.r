# Databricks notebook source
# ACLED Monthly Full Refresh
# Runs on the 1st of each month via a separate Databricks Job
# Downloads complete dataset from 1997 and merges all corrections into Delta

# COMMAND ----------

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

base_dir <- "/dbfs/acled"

# COMMAND ----------

acled_password <- Sys.getenv("ACLED_PASSWORD", unset = "")
acled_username <- Sys.getenv(
  "ACLED_USERNAME",
  unset = "mpurroyvitola@worldbank.org"
)

if (nchar(acled_password) == 0) {
  stop("ACLED_PASSWORD env var not set.")
}

# COMMAND ----------

# Full download from 1997 — ignores existing file to force complete refresh
source(file.path(scripts_dir, "acled_incremental_updater.R"))

cat("\n=== MONTHLY FULL REFRESH — downloading complete dataset from 1997 ===\n")

full_data <- fetch_acled_data(
  username   = acled_username,
  start_date = as.Date("1997-01-01"),
  password   = acled_password
)

cat(sprintf("Downloaded %s records.\n", format(nrow(full_data), big.mark = ",")))

# COMMAND ----------

# Merge full dataset into Delta — updates ALL historical corrections
library(SparkR)

DELTA_TABLE <- paste0(
  "prd_datascience_compoundriskmonitor.",
  "compoundriskmonitor.acled"
)

sql("CREATE SCHEMA IF NOT EXISTS prd_datascience_compoundriskmonitor.compoundriskmonitor")

spark_df <- as.DataFrame(full_data)

table_exists <- tryCatch({
  sql(sprintf("DESCRIBE %s", DELTA_TABLE))
  TRUE
}, error = function(e) FALSE)

if (!table_exists) {
  cat("Table not found — creating for the first time.\n")
  saveAsTable(spark_df, DELTA_TABLE, source = "delta", mode = "overwrite")
} else {
  createOrReplaceTempView(spark_df, "acled_full_refresh")
  sql(sprintf("
    MERGE INTO %s AS target
    USING acled_full_refresh AS source
    ON target.event_id_cnty = source.event_id_cnty
    WHEN MATCHED THEN UPDATE SET *
    WHEN NOT MATCHED THEN INSERT *
  ", DELTA_TABLE))
}

cat("Delta table fully refreshed.\n")

# COMMAND ----------

# Save master CSV and update Volume
output_file <- file.path(
  base_dir, "data", "master", "current",
  sprintf("acled_data_all_%s.csv", format(Sys.Date(), "%m%d%Y"))
)
readr::write_csv(full_data, output_file)

current_csv <- file.path(
  base_dir, "data", "master", "current", "acled_data_current.csv"
)
readr::write_csv(full_data, current_csv)

volume_path <- paste0(
  "/Volumes/prd_datascience_compoundriskmonitor/volumes/",
  "compoundriskmonitor/fcvriskdashboard/acled_data_current.csv"
)
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

cat(sprintf("\nMonthly refresh completed at: %s\n", Sys.time()))
