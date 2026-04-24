library(httr2)
library(readr)

#' Read ACLED data from Databricks Unity Catalog Volume
#'
#' Requires DATABRICKS_HOST and DATABRICKS_TOKEN in ~/.Renviron
#'
#' @param country Optional country name to filter (e.g. "Afghanistan")
#' @return A data frame with ACLED data
read_acled <- function(country = NULL) {
  host  <- Sys.getenv("DATABRICKS_HOST")
  token <- Sys.getenv("DATABRICKS_TOKEN")

  if (nchar(host) == 0 || nchar(token) == 0) {
    stop(
      "DATABRICKS_HOST and DATABRICKS_TOKEN must be set in ~/.Renviron\n",
      "Run: file.edit('~/.Renviron') to edit the file."
    )
  }

  if (!is.null(country)) {
    # Read country-specific file
    clean_name <- gsub("[^A-Za-z0-9]", "_", country)
    clean_name <- gsub("_+", "_", clean_name)
    path <- paste0(
      "/Volumes/prd_datascience_compoundriskmonitor/volumes/",
      "compoundriskmonitor/fcvriskdashboard/acled_data_current.csv"
    )
    # Note: filter after download for country files on DBFS instead
    cat(sprintf("Fetching full dataset and filtering for: %s\n", country))
  } else {
    path <- paste0(
      "/Volumes/prd_datascience_compoundriskmonitor/volumes/",
      "compoundriskmonitor/fcvriskdashboard/acled_data_current.csv"
    )
    cat("Fetching full ACLED dataset from Databricks...\n")
  }

  response <- request(paste0(host, "/api/2.0/fs/files", path)) |>
    req_auth_bearer_token(token) |>
    req_perform()

  df <- read_csv(resp_body_string(response), show_col_types = FALSE)

  if (!is.null(country)) {
    df <- df[df$country == country, ]
  }

  cat(sprintf("Loaded %s records.\n", format(nrow(df), big.mark = ",")))
  df
}
