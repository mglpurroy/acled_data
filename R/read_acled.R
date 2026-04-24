VOLUME_PATH <- paste0(
  "/Volumes/prd_datascience_compoundriskmonitor/volumes/",
  "compoundriskmonitor/fcvriskdashboard/acled_data_current.csv"
)

#' Set Databricks credentials for the session
#'
#' Alternatively, set DATABRICKS_HOST and DATABRICKS_TOKEN in ~/.Renviron
#'
#' @param host Databricks workspace URL
#' @param token Personal access token (all-apis scope)
#' @export
acled_auth <- function(host, token) {
  Sys.setenv(DATABRICKS_HOST = host, DATABRICKS_TOKEN = token)
  invisible(NULL)
}

#' Read ACLED conflict data from Databricks
#'
#' Downloads the latest ACLED dataset from the World Bank Databricks workspace.
#' Credentials must be configured via `acled_auth()` or ~/.Renviron.
#'
#' @param country Single country name to filter (e.g. `"Afghanistan"`)
#' @param countries Character vector of country names to filter
#' @return A data frame with ACLED event data
#' @export
#'
#' @examples
#' \dontrun{
#' acled_auth(
#'   host  = "https://adb-8552758251265347.7.azuredatabricks.net",
#'   token = "your_token"
#' )
#'
#' # Full dataset
#' acled <- read_acled()
#'
#' # Single country
#' afg <- read_acled(country = "Afghanistan")
#'
#' # Multiple countries
#' df <- read_acled(countries = c("Sudan", "Yemen", "Syria"))
#' }
read_acled <- function(country = NULL, countries = NULL) {
  host  <- Sys.getenv("DATABRICKS_HOST")
  token <- Sys.getenv("DATABRICKS_TOKEN")

  if (nchar(host) == 0 || nchar(token) == 0) {
    stop(
      "Credentials not set. Run acled_auth(host, token) or add to ~/.Renviron:\n",
      "  DATABRICKS_HOST=https://adb-8552758251265347.7.azuredatabricks.net\n",
      "  DATABRICKS_TOKEN=your_token"
    )
  }

  cat("Downloading ACLED dataset from Databricks...\n")

  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))

  request(paste0(host, "/api/2.0/fs/files", VOLUME_PATH)) |>
    req_auth_bearer_token(token) |>
    req_perform(path = tmp)

  df <- read_csv(tmp, show_col_types = FALSE)

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
