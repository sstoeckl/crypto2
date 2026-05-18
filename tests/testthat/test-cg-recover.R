# Tests for cg_history_by_id(): fetch CoinGecko history by numeric ID,
# enabling partial survivorship-bias recovery for delisted coins whose
# slug is no longer routable.
#
# Sparse on API calls: each test pulls the smallest payload that
# exercises the check (single coin, single stream, tiny date window).

EXPECTED_COLS_recover <- c(
  "id", "slug", "name", "symbol", "timestamp",
  "ref_cur_id", "ref_cur_name",
  "open", "high", "low", "close", "volume", "market_cap"
)

# ---- cg_history_by_id: smoke test on small range --------------------------

test_that("cg_history_by_id() returns CMC-compatible columns + joins slug for active IDs", {
  # Two active ids, one stream (price), trivial date window. 2 HTTP calls
  # total. Verifies: numeric-id addressing works, schema is right, the
  # coin_list slug join populates slug/name/symbol for active ids.
  skip_if_no_cg()
  cg_pace(2)
  cl <- tibble::tibble(
    id     = c(1L, 279L),
    slug   = c("bitcoin", "ethereum"),
    symbol = c("btc", "eth"),
    name   = c("Bitcoin", "Ethereum")
  )
  h <- cg_history_by_id(ids = c(1L, 279L),
                        what = "price",
                        coin_list = cl, quiet = TRUE,
                        start_date = Sys.Date() - 3)
  skip_if(is.null(h) || !nrow(h),
          "cg_history_by_id returned no data (network blip).")
  expect_s3_class(h, "tbl_df")
  missing <- setdiff(EXPECTED_COLS_recover, names(h))
  expect_true(length(missing) == 0,
              info = paste("missing columns:", paste(missing, collapse = ", ")))
  expect_setequal(unique(h$id), c(1L, 279L))
  expect_true(all(!is.na(h$slug)),
              info = "slug join failed for known-active ids")

  # While we have this tibble, also assert the daily UTC flooring contract
  # (saves writing a second test that pulls another coin).
  expect_s3_class(h$timestamp, "POSIXct")
  ts_secs <- as.numeric(h$timestamp) %% 86400
  expect_true(all(ts_secs == 0),
              info = "cg_history_by_id timestamps not all daily UTC midnight")
})

# ---- cg_history_by_id: handles a "dead" numeric ID gracefully -------------

test_that("cg_history_by_id() survives a numeric ID outside the allocated range", {
  # 1 HTTP call (returns 404). Verifies the function does not crash when
  # an id has no data and yields a valid empty tibble.
  skip_if_no_cg()
  cg_pace(2)
  # 9 999 999 is well above the highest allocated id (404 confirmed).
  cl <- tibble::tibble(id = integer(0), slug = character(0),
                       symbol = character(0), name = character(0))
  h <- cg_history_by_id(ids = 9999999L, what = "price",
                        coin_list = cl, quiet = TRUE)
  expect_s3_class(h, "tbl_df")
  expect_equal(nrow(h), 0L,
               info = "dead-id call should yield zero rows, not partial junk")
})
