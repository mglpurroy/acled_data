VOLUME_PATH <- paste0(
  "/Volumes/prd_datascience_compoundriskmonitor/volumes/",
  "compoundriskmonitor/fcvriskdashboard/acled_data_current.csv"
)

#' Set Databricks credentials for the session
#'
#' Alternatively, set DATABRICKS_HOST and DATABRICKS_TOKEN in `~/.Renviron`
#'
#' @param host  Databricks workspace URL
#' @param token Personal access token (all-apis scope)
#' @export
acled_auth <- function(host, token) {
  Sys.setenv(DATABRICKS_HOST = host, DATABRICKS_TOKEN = token)
  invisible(NULL)
}

#' Read ACLED conflict data from Databricks
#'
#' Downloads the latest ACLED dataset from the World Bank Databricks workspace.
#' Credentials must be set via `acled_auth()` or `~/.Renviron`.
#'
#' @param country    Single country name (e.g. `"Afghanistan"`)
#' @param countries  Character vector of country names
#' @param start_date Start date as `"YYYY-MM-DD"` string or Date object
#' @param end_date   End date as `"YYYY-MM-DD"` string or Date object
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
#' acled <- read_acled()
#' afg   <- read_acled(country = "Afghanistan")
#' df    <- read_acled(
#'   countries  = c("Sudan", "Yemen"),
#'   start_date = "2020-01-01",
#'   end_date   = "2024-12-31"
#' )
#' }
read_acled <- function(country    = NULL,
                       countries  = NULL,
                       start_date = NULL,
                       end_date   = NULL) {
  host  <- Sys.getenv("DATABRICKS_HOST")
  token <- Sys.getenv("DATABRICKS_TOKEN")

  if (nchar(host) == 0 || nchar(token) == 0) {
    stop(
      "Credentials not set. Run acled_auth(host, token) or add to ",
      "~/.Renviron:\n",
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

  # Apply filters locally
  filter_countries <- c(country, countries)
  if (length(filter_countries) > 0) {
    df <- df[df$country %in% filter_countries, ]
  }
  if (!is.null(start_date)) {
    df <- df[as.Date(df$event_date) >= as.Date(start_date), ]
  }
  if (!is.null(end_date)) {
    df <- df[as.Date(df$event_date) <= as.Date(end_date), ]
  }

  cat(sprintf("Loaded %s records.\n", format(nrow(df), big.mark = ",")))
  df
}
