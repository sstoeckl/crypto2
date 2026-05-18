# Shared fixtures + skip helpers for the CoinGecko test suite.
# This file is loaded automatically by testthat for any test-cg-*.R file.

# ---- known-good identifiers (these have been stable for years) --------------
# If any of these change unexpectedly, the upstream platform has restructured
# its data model and the anomaly tests will surface that.
KNOWN_COINS <- list(
  bitcoin  = list(slug = "bitcoin",  symbol = "btc",  numeric_id = 1L,
                  genesis_date = as.Date("2013-04-28")),  # CG's earliest
  ethereum = list(slug = "ethereum", symbol = "eth",  numeric_id = 279L,
                  genesis_date = as.Date("2015-07-30")),
  tether   = list(slug = "tether",   symbol = "usdt", numeric_id = 325L),
  xrp      = list(slug = "ripple",   symbol = "xrp",  numeric_id = 44L),
  dogecoin = list(slug = "dogecoin", symbol = "doge", numeric_id = 5L)
)

# Expected critical columns per function. These are columns the downstream
# cronjob package depends on; CoinGecko adding new columns is fine, but
# *removing* any of these should fail the test loudly.
EXPECTED_COLS <- list(
  cg_list = c(
    "id", "name", "symbol", "slug", "rank", "is_active",
    "first_historical_data", "last_historical_data"
  ),
  cg_listings = c(
    "id", "name", "symbol", "slug", "rank", "last_updated",
    "market_cap", "fully_diluted_market_cap",
    "circulating_supply", "total_supply", "max_supply",
    "price", "volume_24h",
    "percent_change_1h", "percent_change_24h", "percent_change_7d",
    "percent_change_30d",
    "ath", "atl", "ref_currency"
  ),
  cg_history = c(
    "id", "slug", "name", "symbol", "timestamp",
    "ref_cur_id", "ref_cur_name",
    "open", "high", "low", "close", "volume", "market_cap"
  ),
  cg_info = c(
    "id", "name", "symbol", "slug", "category", "description",
    "logo", "date_added", "categories", "platforms", "url"
  )
)

# ---- skip helpers ----------------------------------------------------------
skip_if_no_internet <- function() {
  # Cheap connectivity check: ping CoinGecko's docs host, not the API itself,
  # so we don't burn API quota on a check.
  ok <- tryCatch({
    con <- url("https://www.coingecko.com/robots.txt", open = "rt")
    on.exit(close(con), add = TRUE)
    !is.null(readLines(con, n = 1, warn = FALSE))
  }, error = function(e) FALSE, warning = function(w) FALSE)
  if (!isTRUE(ok)) testthat::skip("No internet / CoinGecko unreachable.")
}

# Many CoinGecko tests touch the live API and are slow. Skip on CRAN.
skip_if_no_cg <- function() {
  testthat::skip_on_cran()
  skip_if_no_internet()
}

# Lightweight check: hit the documented host and skip if rate-limited.
# Run at the top of every test that depends on the documented API host
# (api.coingecko.com), so transient 429s don't get reported as failures.
skip_if_cg_rate_limited <- function(url = "https://api.coingecko.com/api/v3/ping") {
  resp <- tryCatch(
    httr::GET(url,
              httr::user_agent(cg_user_agent()),
              httr::timeout(10)),
    error = function(e) NULL
  )
  if (is.null(resp)) {
    testthat::skip("CG ping failed (network unreachable).")
  }
  if (httr::status_code(resp) == 429) {
    testthat::skip("CG rate-limited (HTTP 429) — backing off.")
  }
  if (httr::status_code(resp) >= 500) {
    testthat::skip(sprintf("CG upstream error (HTTP %d).",
                           httr::status_code(resp)))
  }
}

# Pre-test pause to amortize across the per-minute budget. Use at the top
# of each test that hits the documented API host so multi-test files don't
# blow the 30 req/min limit.
cg_pace <- function(seconds = 3) {
  Sys.sleep(seconds)
}
