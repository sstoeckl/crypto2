# Endpoint availability tests.
#
# These probe each of the live CoinGecko endpoints the package depends on
# and verify they return 200 with a parseable payload of the expected shape.
# Run nightly / weekly to detect:
#   * CoinGecko renaming or removing internal routes
#   * Cloudflare blocking the bare User-Agent
#   * Auth changes (e.g. endpoints suddenly requiring a key)
#   * Response-content-type changes (HTML vs JSON)
#
# All tests skip on CRAN — these MUST run online. Rate-limited (HTTP 429)
# responses skip the test rather than fail it, because the rate-limit
# budget is shared across the whole session and easily exhausted by other
# test files in the same run.

# Helper for `missing column` assertions: `expect_length` doesn't accept
# `info=`, so we wrap with expect_true.
expect_no_missing_columns <- function(missing, info_text) {
  testthat::expect_true(
    length(missing) == 0,
    info = paste(info_text, ":", paste(missing, collapse = ", "))
  )
}

test_that("documented API: /ping returns the gecko greeting", {
  skip_if_no_cg()
  skip_if_cg_rate_limited()
  client <- cg_make_client(sleep = 0)
  out <- cg_parse_json(client(cg_url("ping", host = "api")))
  if (is.null(out)) testthat::skip("CG /ping returned nothing (likely 429).")
  expect_true("gecko_says" %in% names(out),
              info = "missing `gecko_says` field — schema change?")
})

test_that("documented API: /coins/list returns >5000 entries with id/symbol/name", {
  skip_if_no_cg()
  skip_if_cg_rate_limited()
  cg_pace(3)
  client <- cg_make_client(sleep = 0)
  out <- cg_parse_json(client(cg_url("coins/list", host = "api")))
  if (is.null(out)) testthat::skip("CG /coins/list returned nothing (likely 429).")
  expect_s3_class(tibble::as_tibble(out), "tbl_df")
  expect_true(nrow(out) > 5000,
              info = sprintf("/coins/list returned only %d entries (expected >5000)",
                             nrow(out)))
  expect_true(all(c("id", "symbol", "name") %in% names(out)),
              info = "missing core column(s) in /coins/list")
})

test_that("documented API: /coins/markets returns the columns we depend on", {
  skip_if_no_cg()
  skip_if_cg_rate_limited()
  cg_pace(3)
  client <- cg_make_client(sleep = 0)
  out <- cg_parse_json(client(
    cg_url("coins/markets", host = "api"),
    query = list(vs_currency = "usd", per_page = 5, page = 1,
                 price_change_percentage = "1h,24h,7d,14d,30d,200d,1y")
  ))
  if (is.null(out)) testthat::skip("CG /coins/markets returned nothing (likely 429).")
  must_have <- c("id", "symbol", "name", "image",
                 "current_price", "market_cap", "market_cap_rank",
                 "total_volume", "circulating_supply", "total_supply",
                 "max_supply", "ath", "atl",
                 "price_change_percentage_24h_in_currency")
  expect_no_missing_columns(setdiff(must_have, names(out)),
                            "missing /coins/markets columns")
})

test_that("documented API: /coins/{slug} returns expected top-level fields", {
  skip_if_no_cg()
  skip_if_cg_rate_limited()
  cg_pace(3)
  client <- cg_make_client(sleep = 0)
  out <- cg_parse_json(client(
    cg_url("coins/bitcoin", host = "api"),
    query = list(localization = "false", tickers = "false",
                 market_data = "false", community_data = "false",
                 developer_data = "false", sparkline = "false")
  ))
  if (is.null(out)) testthat::skip("CG /coins/bitcoin returned nothing (likely 429).")
  must_have <- c("id", "symbol", "name", "image", "links",
                 "asset_platform_id", "categories", "platforms",
                 "description")
  expect_no_missing_columns(setdiff(must_have, names(out)),
                            "missing /coins/{id} top-level fields")
})

test_that("website: /price_charts/{slug}/{vs}/30_days.json returns price + volume series", {
  skip_if_no_cg()
  client <- cg_make_client(sleep = 0)
  out <- cg_parse_json(client(
    cg_url("price_charts/bitcoin/usd/30_days.json", host = "web")
  ))
  if (is.null(out)) testthat::skip("CG /price_charts/ returned nothing.")
  expect_true("stats" %in% names(out),
              info = "missing `stats` array — schema change?")
  expect_true("total_volumes" %in% names(out),
              info = "missing `total_volumes` array — schema change?")
  expect_true(nrow(out$stats) > 100,
              info = "stats array suspiciously small for 30-day window")
  expect_equal(ncol(out$stats), 2,
               info = "stats no longer 2-col — schema change")
})

test_that("website: slug-based /price_charts also works", {
  skip_if_no_cg()
  client <- cg_make_client(sleep = 0)
  out <- cg_parse_json(client(
    cg_url("price_charts/ethereum/usd/7_days.json", host = "web")
  ))
  if (is.null(out)) testthat::skip("CG slug-based price_charts returned nothing.")
  expect_true("stats" %in% names(out))
})

test_that("website: /market_cap/{slug}/{vs}/30_days.json returns mcap series", {
  skip_if_no_cg()
  client <- cg_make_client(sleep = 0)
  out <- cg_parse_json(client(
    cg_url("market_cap/bitcoin/usd/30_days.json", host = "web")
  ))
  if (is.null(out)) testthat::skip("CG /market_cap/ returned nothing.")
  expect_true("stats" %in% names(out),
              info = "/market_cap missing stats — schema change?")
})

test_that("website: /ohlc/{numeric}/series/{vs}/365_days.json returns OHLC array", {
  skip_if_no_cg()
  client <- cg_make_client(sleep = 0)
  out <- cg_parse_json(client(
    cg_url("ohlc/1/series/usd/365_days.json", host = "web")
  ))
  if (is.null(out)) testthat::skip("CG /ohlc/ returned nothing.")
  expect_true("ohlc" %in% names(out),
              info = "missing `ohlc` array — schema change?")
  expect_true(nrow(out$ohlc) > 0,
              info = "OHLC array is empty")
  expect_equal(ncol(out$ohlc), 5,
               info = "OHLC array no longer 5-col [ts, o, h, l, c]")
})

test_that("website: /coins/price_percentage_change batched endpoint works", {
  skip_if_no_cg()
  client <- cg_make_client(sleep = 0)
  txt <- client(
    cg_url("coins/price_percentage_change", host = "web"),
    query = list(ids = "1,279,5", vs_currency = "usd")
  )
  out <- cg_parse_json(txt)
  if (is.null(out)) testthat::skip("CG /price_percentage_change returned nothing.")
  expect_true(all(c("1", "279", "5") %in% names(out)),
              info = "missing coin keys — schema change?")
  expected_metrics <- c(
    "price_change_percentage_1h", "price_change_percentage_24h",
    "price_change_percentage_7d", "price_change_percentage_30d"
  )
  expect_no_missing_columns(setdiff(expected_metrics, names(out[["1"]])),
                            "missing metric fields on price_percentage_change")
})

test_that("known delisted coins still 404 (survivorship bias check)", {
  # If this test ever passes — i.e., bitconnect starts returning 200 —
  # then CoinGecko has changed their delisting policy and the survivorship-
  # bias workaround in the cronjob package needs revisiting.
  skip_if_no_cg()
  skip_if_cg_rate_limited()
  cg_pace(3)
  resp <- tryCatch(
    httr::GET(cg_url("coins/bitconnect", host = "api"),
              httr::user_agent(cg_user_agent()),
              httr::timeout(30)),
    error = function(e) NULL
  )
  skip_if(is.null(resp), "Network error on delisted-coin probe.")
  sc <- httr::status_code(resp)
  if (sc == 429) testthat::skip("Rate-limited on delisted-coin probe.")
  expect_true(sc %in% c(404, 410),
              info = sprintf(
                "Delisted coin returned %d — has CoinGecko's delisting policy changed?",
                sc))
})
