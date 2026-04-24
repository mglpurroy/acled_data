# Databricks notebook source
# Copy ACLED master file to Unity Catalog Volume
# Runs as second task after daily_acled_update completes

# COMMAND ----------

source = "dbfs:/acled/data/master/current/acled_data_current.csv"
target = (
    "/Volumes/prd_datascience_compoundriskmonitor/volumes"
    "/compoundriskmonitor/fcvriskdashboard/acled_data_current.csv"
)

print(f"Source : {source}")
print(f"Target : {target}")

dbutils.fs.cp(source, target, recurse=False)

print("Copy successful.")
