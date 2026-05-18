# Structural-change detection on all four exported cg_* functions.
#
# For each function we assert:
#   1. it returns a tibble
#   2. the critical column set from helper-cg.R::EXPECTED_COLS is present
#      (extra columns added by CoinGecko are tolerated — pure removal fails)
#   3. column types are what downstream consumers will assume
#
# If any of these tests fail, the cronjob package's persistence layer will
# almost certainly miswrite/misread its parquet schema and you need to
# update both this package and the downstream package together.

# expect_length does not accept info=, so we wrap it.
expect_no_missing_columns <- function(missing, info_text) {
  testthat::expect_true(
    length(missing) == 0,
    info = paste(info_text, ":", paste(missing, collapse = ", "))
  )
}

# ---- cg_list() -------------------------------------------------------------

test_that("cg_list() schema is stable", {
  # Lightweight: only enrich the top page (top_n=5 still triggers one
  # /coins/markets call, which is the smallest API roundtrip the function
  # supports beyond the bootstrap /coins/list call).
  skip_if_no_cg()
  skip_if_cg_rate_limited()
  cg_pace(3)
  withr::local_options(crypto2.cg_top_n = 5)
  out <- cg_list()
  skip_if(is.null(out) || !nrow(out),
          "cg_list returned no data (likely rate-limited).")
  expect_s3_class(out, "tbl_df")
  # /coins/list is the source of truth; should return thousands of rows.
  expect_true(nrow(out) > 100,
              info = "cg_list returned an implausibly small universe")
  expect_no_missing_columns(setdiff(EXPECTED_COLS$cg_list, names(out)),
                            "cg_list missing columns")

  expect_type(out$id, "integer")
  expect_type(out$name, "character")
  expect_type(out$symbol, "character")
  expect_type(out$slug, "character")
  expect_type(out$rank, "integer")
  expect_s3_class(out$first_historical_data, "Date")
  expect_s3_class(out$last_historical_data, "Date")
})

# ---- cg_listings() ---------------------------------------------------------

test_that("cg_listings() schema is stable", {
  # Lightweight: 3 rows is enough to verify schema; saves one /coins/markets
  # page over the previous 10-row probe.
  skip_if_no_cg()
  skip_if_cg_rate_limited()
  cg_pace(3)
  out <- cg_listings(limit = 3, quote = TRUE)
  skip_if(is.null(out) || !nrow(out),
          "cg_listings returned no data (likely rate-limited).")
  expect_s3_class(out, "tbl_df")
  expect_true(nrow(out) >= 3)
  expect_no_missing_columns(setdiff(EXPECTED_COLS$cg_listings, names(out)),
                            "cg_listings missing columns")

  expect_type(out$id, "integer")
  expect_type(out$name, "character")
  expect_type(out$slug, "character")
  expect_type(out$price, "double")
  expect_type(out$market_cap, "double")
  expect_type(out$volume_24h, "double")
  expect_type(out$percent_change_24h, "double")
  expect_type(out$ref_currency, "character")
})

# ---- cg_history() ----------------------------------------------------------

test_that("cg_history() schema is stable and rows are daily", {
  # Lightweight: 4-day window only. Full price/mcap/ohlc streams still
  # exercise all 3 endpoints (one HTTP call each) but the JSON payload
  # per call is the same regardless of window since CG always returns
  # the full series and we filter client-side. We still pull 3 streams
  # because that's the maximally-different schema shape to verify.
  skip_if_no_cg()
  cg_pace(2)  # /price_charts is on the website host, lighter rate concerns
  u <- tibble::tibble(slug = "bitcoin", id = 1L,
                      name = "Bitcoin", symbol = "btc")
  out <- cg_history(coin_list = u, start_date = Sys.Date() - 4)
  skip_if(is.null(out) || !nrow(out),
          "cg_history returned no data (likely network blip).")
  expect_s3_class(out, "tbl_df")
  expect_true(nrow(out) >= 3,
              info = "cg_history returned too few rows for a 4-day window")
  expect_no_missing_columns(setdiff(EXPECTED_COLS$cg_history, names(out)),
                            "cg_history missing columns")

  expect_s3_class(out$timestamp, "POSIXct")
  expect_type(out$close, "double")
  expect_type(out$volume, "double")
  expect_type(out$market_cap, "double")

  # Daily flooring — every timestamp must be at midnight UTC
  ts_secs <- as.numeric(out$timestamp) %% 86400
  expect_true(all(ts_secs == 0),
              info = "cg_history timestamps are not all daily UTC midnight")

  # Every date should be unique per coin (no duplicate daily bars)
  expect_equal(anyDuplicated(out[, c("slug", "timestamp")]), 0L,
               info = "duplicate (slug, timestamp) rows in cg_history")
})

test_that("cg_history() handles a coin with missing numeric_id (no OHLC)", {
  # Lightweight: only 2 HTTP calls (price + market_cap), 3-day window.
  skip_if_no_cg()
  cg_pace(2)
  # No `id` column at all -> OHLC path is skipped, price+mcap still work
  u <- tibble::tibble(slug = "bitcoin")
  withr::local_options(crypto2.cg_what = c("price", "market_cap"))
  out <- cg_history(coin_list = u, start_date = Sys.Date() - 3)
  skip_if(is.null(out) || !nrow(out),
          "cg_history returned no data (likely network blip).")
  expect_s3_class(out, "tbl_df")
  expect_true(nrow(out) > 0)
  expect_true(all(is.na(out$open)),
              info = "OHLC columns should be NA when 'ohlc' not in `what`")
  expect_true(any(!is.na(out$close)),
              info = "close should be populated from price-charts endpoint")
})

# ---- cg_info() -------------------------------------------------------------

test_that("cg_info() schema is stable", {
  skip_if_no_cg()
  skip_if_cg_rate_limited()
  cg_pace(3)
  out <- cg_info(tibble::tibble(slug = "bitcoin"))
  skip_if(is.null(out) || !nrow(out),
          "cg_info returned no data (likely rate-limited).")
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 1L)
  expect_no_missing_columns(setdiff(EXPECTED_COLS$cg_info, names(out)),
                            "cg_info missing columns")

  expect_type(out$id, "integer")
  expect_type(out$name, "character")
  expect_type(out$description, "character")
  expect_type(out$categories, "list")
  expect_type(out$platforms, "list")
  expect_type(out$url, "list")
})
