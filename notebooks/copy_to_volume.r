# Databricks notebook source
# Copy ACLED master file to Unity Catalog Volume
# This runs as a second task after daily_acled_update completes

# COMMAND ----------

source_file <- "/dbfs/acled/data/master/current/acled_data_current.csv"
volume_path <- paste0(
  "/Volumes/prd_datascience_compoundriskmonitor/volumes/",
  "compoundriskmonitor/fcvriskdashboard/acled_data_current.csv"
)

if (!file.exists(source_file)) {
  stop("Source file not found: ", source_file)
}

cat(sprintf("Source : %s\n", source_file))
cat(sprintf("Target : %s\n", volume_path))

success <- file.copy(source_file, volume_path, overwrite = TRUE)

if (success) {
  cat("Copy successful.\n")
} else {
  stop("Failed to copy to Unity Catalog Volume.")
}
