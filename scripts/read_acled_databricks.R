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

  # Use country-specific file if requested (much smaller download)
  if (!is.null(country)) {
    clean_name <- gsub("[^A-Za-z0-9]", "_", country)
    clean_name <- gsub("_+", "_", clean_name)
    clean_name <- gsub("^_|_$", "", clean_name)
    path <- paste0("/dbfs/acled/data/by_country/acled_", clean_name, ".csv")
    cat(sprintf("Fetching data for: %s\n", country))
  } else {
    path <- paste0(
      "/Volumes/prd_datascience_compoundriskmonitor/volumes/",
      "compoundriskmonitor/fcvriskdashboard/acled_data_current.csv"
    )
    cat("Fetching full ACLED dataset from Databricks...\n")
  }

  # Stream response to a temp file to avoid loading into memory as string
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))

  request(paste0(host, "/api/2.0/fs/files", path)) |>
    req_auth_bearer_token(token) |>
    req_perform(path = tmp)

  df <- read_csv(tmp, show_col_types = FALSE)

  cat(sprintf("Loaded %s records.\n", format(nrow(df), big.mark = ",")))
  df
}
