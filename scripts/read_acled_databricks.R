library(httr2)
library(readr)

#' Read ACLED data from Databricks Unity Catalog Volume
#'
#' Requires DATABRICKS_HOST and DATABRICKS_TOKEN in ~/.Renviron
#'
#' @param country Optional country name to filter (e.g. "Afghanistan")
#' @param countries Optional character vector of countries to filter
#' @return A data frame with ACLED data
read_acled <- function(country = NULL, countries = NULL) {
  host  <- Sys.getenv("DATABRICKS_HOST")
  token <- Sys.getenv("DATABRICKS_TOKEN")

  if (nchar(host) == 0 || nchar(token) == 0) {
    stop(
      "DATABRICKS_HOST and DATABRICKS_TOKEN must be set in ~/.Renviron\n",
      "Run: file.edit('~/.Renviron') to edit the file."
    )
  }

  path <- paste0(
    "/Volumes/prd_datascience_compoundriskmonitor/volumes/",
    "compoundriskmonitor/fcvriskdashboard/acled_data_current.csv"
  )

  cat("Downloading ACLED dataset from Databricks (streaming)...\n")

  # Stream directly to disk — avoids loading 500MB+ into memory as a string
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))

  request(paste0(host, "/api/2.0/fs/files", path)) |>
    req_auth_bearer_token(token) |>
    req_perform(path = tmp)

  df <- read_csv(tmp, show_col_types = FALSE)

  # Filter by country/countries if requested
  filter_countries <- c(country, countries)
  if (length(filter_countries) > 0) {
    df <- df[df$country %in% filter_countries, ]
    cat(sprintf(
      "Filtered to %s: %s records.\n",
      paste(filter_countries, collapse = ", "),
      format(nrow(df), big.mark = ",")
    ))
  } else {
    cat(sprintf("Loaded %s records.\n", format(nrow(df), big.mark = ",")))
  }

  df
}
