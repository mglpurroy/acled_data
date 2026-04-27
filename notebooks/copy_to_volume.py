# Databricks notebook source
# Copy ACLED master file to Unity Catalog Volume
# Runs as second task after daily_acled_update completes

# COMMAND ----------

source = "dbfs:/acled/data/master/current/acled_data_current.csv"

targets = [
    "/Volumes/prd_datascience_compoundriskmonitor/volumes/compoundriskmonitor/fcvriskdashboard/acled_data_current.csv",
    "/Volumes/qa_datascience_compoundriskmonitor/volumes/compoundriskmonitor/fcvriskdashboard/acled_data_current.csv",
]

print(f"Source: {source}")

for target in targets:
    print(f"Copying to: {target}")
    dbutils.fs.cp(source, target, recurse=False)
    print("  Done.")

print("All copies successful.")
