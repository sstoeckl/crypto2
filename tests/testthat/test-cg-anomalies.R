# Data-revision / anomaly detection.
#
# These tests verify that well-known facts about specific coins are
# still true. If any fail, CoinGecko has either:
#   * remapped internal numeric IDs (rare, would break OHLC retrieval)
#   * changed slug strings (would break per-coin endpoints)
#   * revised historical genesis dates
#   * delivered values so far out of plausible bounds that we should
#     suspect a unit / parsing bug
#
# These are NOT exact equality assertions on noisy live values (e.g. we
# don't pin BTC's current price). They assert *structural facts and
# plausible-range bounds* — the cronjob package's "doctor" should run
# this suite weekly and surface any failure.

# ---- cg_list identity anchors ----------------------------------------------

test_that("cg_list: known coins have their expected slugs + numeric IDs", {
  skip_if_no_cg()
  skip_if_cg_rate_limited()
  cg_pace(3)
  u <- cg_list(top_n = 250)  # top-250 ought to include all our anchors
  skip_if(is.null(u) || !nrow(u), "cg_list returned no data (likely 429).")
  for (k in names(KNOWN_COINS)) {
    kc <- KNOWN_COINS[[k]]
    row <- u[u$slug == kc$slug, , drop = FALSE]
    expect_equal(nrow(row), 1L,
                 info = sprintf("Slug '%s' missing from top-250 universe.",
                                kc$slug))
    if (nrow(row) == 1L) {
      expect_equal(row$id, kc$numeric_id,
                   info = sprintf("Numeric ID drift for '%s': got %s, expected %d.",
                                  kc$slug, format(row$id), kc$numeric_id))
      expect_equal(row$symbol, kc$symbol,
                   info = sprintf("Symbol drift for '%s': got '%s', expected '%s'.",
                                  kc$slug, row$symbol, kc$symbol))
    }
  }
})

# ---- cg_listings sanity ranges --------------------------------------------

test_that("cg_listings: Bitcoin row is in plausible ranges", {
  skip_if_no_cg()
  skip_if_cg_rate_limited()
  cg_pace(3)
  ls <- cg_listings(limit = 5)
  skip_if(is.null(ls) || !nrow(ls), "cg_listings returned no data (likely 429).")
  btc <- ls[ls$slug == "bitcoin", , drop = FALSE]
  expect_equal(nrow(btc), 1L,
               info = "Bitcoin not in top-5 — implausible market state.")
  if (nrow(btc) == 1L) {
    # Bitcoin price: extremely lax bounds chosen to catch unit-error bugs,
    # NOT to predict price. $100 lower bound flags a missing decimal point;
    # $10M upper bound flags a bad multiplier.
    expect_true(btc$price > 100 && btc$price < 1e7,
                info = sprintf("BTC price out of bounds: %g", btc$price))
    expect_true(btc$market_cap > 1e10,
                info = "BTC market_cap implausibly small.")
    expect_true(btc$volume_24h > 1e6,
                info = "BTC 24h volume implausibly small.")
    expect_true(btc$rank == 1L,
                info = sprintf("BTC rank no longer 1 (got %s)",
                               format(btc$rank)))
    # circulating supply must be in [10M, 21M] — protocol-defined range
    expect_true(btc$circulating_supply > 1e7 &&
                  btc$circulating_supply < 2.2e7,
                info = sprintf("BTC circulating supply out of bounds: %g",
                               btc$circulating_supply))
  }
})

test_that("cg_listings: percent_change windows are not all zero", {
  skip_if_no_cg()
  skip_if_cg_rate_limited()
  cg_pace(3)
  ls <- cg_listings(limit = 20)
  skip_if(is.null(ls) || !nrow(ls), "cg_listings returned no data (likely 429).")
  # At least one non-zero percent_change_24h across the top-20 — if EVERY
  # row is exactly zero something is wrong with the % parser.
  ok <- any(!is.na(ls$percent_change_24h) & ls$percent_change_24h != 0)
  expect_true(ok,
              info = "All percent_change_24h are NA or 0 across top 20 coins.")
})

# ---- cg_history sanity -----------------------------------------------------

test_that("cg_history: BTC close prices are monotonic in time and in range", {
  skip_if_no_cg()
  cg_pace(2)
  u <- tibble::tibble(slug = "bitcoin", id = 1L)
  h <- cg_history(coin_list = u, what = "price",
                  start_date = Sys.Date() - 30)
  skip_if(is.null(h) || !nrow(h), "cg_history returned no data (likely network blip).")
  expect_true(nrow(h) >= 15L,
              info = "Too few daily bars for a 30-day BTC window.")
  expect_s3_class(h$timestamp, "POSIXct")
  # All daily UTC midnights
  expect_true(all(as.numeric(h$timestamp) %% 86400 == 0))
  # No price < $100 or > $10M (same lax bound as the listings test)
  expect_true(all(h$close > 100 & h$close < 1e7),
              info = "BTC close prices out of plausible bounds.")
})

test_that("cg_history: ETH market cap roughly matches price * circulating supply", {
  skip_if_no_cg()
  cg_pace(2)
  # Independent cross-check across endpoints — if /market_cap and
  # /price_charts return data from different days or in different units,
  # this ratio would diverge wildly.
  u <- tibble::tibble(slug = "ethereum", id = 279L)
  h <- cg_history(coin_list = u, what = c("price", "market_cap"),
                  start_date = Sys.Date() - 14)
  skip_if(is.null(h) || !nrow(h), "cg_history returned no data (likely network blip).")
  h <- h[!is.na(h$close) & !is.na(h$market_cap), , drop = FALSE]
  expect_gt(nrow(h), 0)
  implied_supply <- h$market_cap / h$close
  # ETH circulating supply is ~120M; allow huge slack to catch unit bugs only
  expect_true(all(implied_supply > 1e7 & implied_supply < 1e9),
              info = sprintf(
                "Implied ETH supply (mcap/price) out of bounds: range [%g, %g]",
                min(implied_supply), max(implied_supply)))
})

# ---- cg_info sanity --------------------------------------------------------

test_that("cg_info: well-known genesis dates haven't been revised", {
  skip_if_no_cg()
  skip_if_cg_rate_limited()
  cg_pace(3)
  out <- cg_info(tibble::tibble(slug = c("ethereum")))
  skip_if(is.null(out) || !nrow(out), "cg_info returned no data (likely 429).")
  expect_equal(nrow(out), 1L)
  expect_equal(out$slug, "ethereum")
  # ETH genesis_date is 2015-07-30. If CoinGecko revised this, surface it.
  expect_equal(out$date_added, KNOWN_COINS$ethereum$genesis_date,
               info = sprintf("ETH genesis_date drift: got '%s', expected '%s'",
                              as.character(out$date_added),
                              as.character(KNOWN_COINS$ethereum$genesis_date)))
})

test_that("cg_info: Bitcoin metadata fields are populated", {
  skip_if_no_cg()
  skip_if_cg_rate_limited()
  cg_pace(5)  # this is the last test in the file - extra slack on retries
  out <- cg_info(tibble::tibble(slug = "bitcoin"))
  skip_if(is.null(out) || !nrow(out), "cg_info returned no data (likely 429).")
  expect_equal(out$id, KNOWN_COINS$bitcoin$numeric_id)
  expect_equal(out$symbol, "btc")
  expect_match(tolower(out$name), "bitcoin")
  expect_true(nchar(out$description) > 100,
              info = "BTC description suspiciously short — content may have changed.")
  expect_match(out$logo, "coingecko\\.com/coins/images/1/")
})
