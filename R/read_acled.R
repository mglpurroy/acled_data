DELTA_TABLE <- paste0(
  "prd_datascience_compoundriskmonitor.",
  "compoundriskmonitor.acled"
)

#' Set Databricks credentials for the session
#'
#' Alternatively, set environment variables in ~/.Renviron:
#'   DATABRICKS_HOST, DATABRICKS_TOKEN, DATABRICKS_WAREHOUSE_ID
#'
#' @param host Databricks workspace URL
#' @param token Personal access token (all-apis scope)
#' @param warehouse_id SQL Warehouse ID (find it in SQL -> SQL Warehouses)
#' @export
acled_auth <- function(host, token, warehouse_id) {
  Sys.setenv(
    DATABRICKS_HOST         = host,
    DATABRICKS_TOKEN        = token,
    DATABRICKS_WAREHOUSE_ID = warehouse_id
  )
  invisible(NULL)
}

#' Read ACLED conflict data from Databricks Delta table
#'
#' Queries the central ACLED Delta table via Databricks SQL.
#' Credentials must be set via `acled_auth()` or `~/.Renviron`.
#'
#' @param country   Single country name (e.g. `"Afghanistan"`)
#' @param countries Character vector of country names
#' @param start_date Start date as string `"YYYY-MM-DD"` or Date object
#' @param end_date   End date as string `"YYYY-MM-DD"` or Date object
#' @return A data frame with ACLED event data
#' @export
#'
#' @examples
#' \dontrun{
#' acled_auth(
#'   host         = "https://adb-8552758251265347.7.azuredatabricks.net",
#'   token        = "your_token",
#'   warehouse_id = "your_warehouse_id"
#' )
#'
#' # Full dataset
#' acled <- read_acled()
#'
#' # Single country
#' afg <- read_acled(country = "Afghanistan")
#'
#' # Multiple countries with date range
#' df <- read_acled(
#'   countries   = c("Sudan", "Yemen"),
#'   start_date  = "2020-01-01",
#'   end_date    = "2024-12-31"
#' )
#' }
read_acled <- function(country    = NULL,
                       countries  = NULL,
                       start_date = NULL,
                       end_date   = NULL) {
  host         <- Sys.getenv("DATABRICKS_HOST")
  token        <- Sys.getenv("DATABRICKS_TOKEN")
  warehouse_id <- Sys.getenv("DATABRICKS_WAREHOUSE_ID")

  if (nchar(host) == 0 || nchar(token) == 0 || nchar(warehouse_id) == 0) {
    stop(
      "Credentials not set. Run acled_auth(host, token, warehouse_id) ",
      "or add to ~/.Renviron:\n",
      "  DATABRICKS_HOST=https://adb-8552758251265347.7.azuredatabricks.net\n",
      "  DATABRICKS_TOKEN=your_token\n",
      "  DATABRICKS_WAREHOUSE_ID=your_warehouse_id"
    )
  }

  sql <- .build_query(country, countries, start_date, end_date)
  cat(sprintf("Running: %s\n", sql))

  .run_sql(sql, host, token, warehouse_id)
}

.build_query <- function(country, countries, start_date, end_date) {
  filters <- character(0)

  filter_countries <- c(country, countries)
  if (length(filter_countries) > 0) {
    in_list  <- paste(sprintf("'%s'", filter_countries), collapse = ", ")
    filters  <- c(filters, sprintf("country IN (%s)", in_list))
  }
  if (!is.null(start_date)) {
    filters <- c(filters, sprintf("event_date >= '%s'", as.Date(start_date)))
  }
  if (!is.null(end_date)) {
    filters <- c(filters, sprintf("event_date <= '%s'", as.Date(end_date)))
  }

  where <- if (length(filters) > 0) {
    paste("WHERE", paste(filters, collapse = " AND "))
  } else ""

  sprintf("SELECT * FROM %s %s", DELTA_TABLE, where)
}

.run_sql <- function(sql, host, token, warehouse_id) {
  url <- paste0(host, "/api/2.0/sql/statements")

  body <- list(
    warehouse_id = warehouse_id,
    statement    = sql,
    wait_timeout = "50s",
    disposition  = "EXTERNAL_LINKS",
    format       = "CSV"
  )

  resp <- request(url) |>
    req_auth_bearer_token(token) |>
    req_body_json(body) |>
    req_perform() |>
    resp_body_json()

  # Poll if still running
  while (resp$status$state %in% c("PENDING", "RUNNING")) {
    Sys.sleep(2)
    resp <- request(
      paste0(host, "/api/2.0/sql/statements/", resp$statement_id)
    ) |>
      req_auth_bearer_token(token) |>
      req_perform() |>
      resp_body_json()
  }

  if (resp$status$state != "SUCCEEDED") {
    stop("Query failed: ", resp$status$error$message)
  }

  # Download each chunk and combine
  chunks <- lapply(resp$result$external_links, function(link) {
    tmp <- tempfile(fileext = ".csv")
    on.exit(unlink(tmp), add = TRUE)
    download.file(link$external_link, tmp, quiet = TRUE, mode = "wb")
    read_csv(tmp, show_col_types = FALSE)
  })

  df <- do.call(rbind, chunks)
  cat(sprintf("Loaded %s records.\n", format(nrow(df), big.mark = ",")))
  df
}
