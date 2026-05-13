# Tests for cg_history_by_id(): fetch CoinGecko history by numeric ID,
# enabling partial survivorship-bias recovery for delisted coins whose
# slug is no longer routable.

EXPECTED_COLS_recover <- c(
  "id", "slug", "name", "symbol", "timestamp",
  "ref_cur_id", "ref_cur_name",
  "open", "high", "low", "close", "volume", "market_cap"
)

# ---- cg_history_by_id: smoke test on small range --------------------------

test_that("cg_history_by_id() returns CMC-compatible columns for active IDs", {
  skip_if_no_cg()
  cg_pace(2)
  # IDs 1 (BTC), 5 (DOGE), 279 (ETH) — all active, all should return
  # full history. We pass a tiny cached coin_list so the slug join works
  # without burning extra /coins/markets calls.
  cl <- tibble::tibble(
    id     = c(1L, 5L, 279L),
    slug   = c("bitcoin", "dogecoin", "ethereum"),
    symbol = c("btc", "doge", "eth"),
    name   = c("Bitcoin", "Dogecoin", "Ethereum")
  )
  h <- cg_history_by_id(ids = c(1L, 5L, 279L),
                       what = c("price", "market_cap"),
                       coin_list = cl, quiet = TRUE,
                       start_date = Sys.Date() - 14)
  skip_if(is.null(h) || !nrow(h),
          "cg_history_by_id returned no data (network blip).")
  expect_s3_class(h, "tbl_df")
  missing <- setdiff(EXPECTED_COLS_recover, names(h))
  expect_true(length(missing) == 0,
              info = paste("missing columns:", paste(missing, collapse = ", ")))
  expect_setequal(unique(h$id), c(1L, 5L, 279L))
  # Each returned id should have its slug populated from coin_list
  expect_true(all(!is.na(h$slug)))
})

# ---- cg_history_by_id: handles a "dead" numeric ID gracefully -------------

test_that("cg_history_by_id() survives a numeric ID outside the allocated range", {
  skip_if_no_cg()
  cg_pace(2)
  # 9 999 999 is well above the highest allocated id (404 confirmed).
  # The function should return an empty tibble (no rows for that id),
  # not crash, and not include the dead id in the result.
  cl <- tibble::tibble(id = integer(0), slug = character(0),
                      symbol = character(0), name = character(0))
  h <- cg_history_by_id(ids = 9999999L, what = "price",
                       coin_list = cl, quiet = TRUE)
  expect_s3_class(h, "tbl_df")
  expect_equal(nrow(h), 0L,
               info = "dead-id call should yield zero rows, not partial junk")
})

# ---- cg_history_by_id: timestamps are daily UTC ---------------------------

test_that("cg_history_by_id() floors timestamps to daily UTC midnight", {
  skip_if_no_cg()
  cg_pace(2)
  cl <- tibble::tibble(id = 1L, slug = "bitcoin",
                      symbol = "btc", name = "Bitcoin")
  h <- cg_history_by_id(ids = 1L, what = "price", coin_list = cl,
                       quiet = TRUE, start_date = Sys.Date() - 7)
  skip_if(is.null(h) || !nrow(h),
          "cg_history_by_id returned no data (network blip).")
  ts_secs <- as.numeric(h$timestamp) %% 86400
  expect_true(all(ts_secs == 0),
              info = "cg_history_by_id timestamps not all daily UTC midnight")
})
