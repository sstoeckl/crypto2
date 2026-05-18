# Data-revision / anomaly detection.
#
# These tests verify that well-known facts about specific coins are still
# true. If any fail, CoinGecko has either:
#   * remapped internal numeric IDs (rare, would break OHLC retrieval)
#   * changed slug strings (would break per-coin endpoints)
#   * revised historical genesis dates
#   * delivered values so far out of plausible bounds that we should
#     suspect a unit / parsing bug
#
# Tests assert structural facts and plausible-range bounds, never exact
# values on noisy live data. Designed to be sparse on API calls: each
# test pulls the smallest payload that exercises the check. Multi-coin
# pulls share a single API call (cg_info() takes a tibble of slugs).

# ---- cg_list identity anchors ----------------------------------------------

test_that("cg_list: known coins have their expected slugs + numeric IDs", {
  # 1 markets page (top 10) is enough — all KNOWN_COINS are top-10.
  skip_if_no_cg()
  skip_if_cg_rate_limited()
  cg_pace(3)
  u <- cg_list(top_n = 10)
  skip_if(is.null(u) || !nrow(u), "cg_list returned no data (likely 429).")
  for (k in names(KNOWN_COINS)) {
    kc <- KNOWN_COINS[[k]]
    row <- u[u$slug == kc$slug, , drop = FALSE]
    expect_equal(nrow(row), 1L,
                 info = sprintf("Slug '%s' missing from top-10 universe.",
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
#
# Both following tests use a SINGLE cg_listings(limit = 10) call (cached
# per-test-session in withr::defer to avoid duplicate API calls). One
# /coins/markets page (250 coins per page) covers both checks below.

test_that("cg_listings: Bitcoin row is in plausible ranges + percent_change parses", {
  skip_if_no_cg()
  skip_if_cg_rate_limited()
  cg_pace(3)
  ls <- cg_listings(limit = 10)
  skip_if(is.null(ls) || !nrow(ls), "cg_listings returned no data (likely 429).")

  btc <- ls[ls$slug == "bitcoin", , drop = FALSE]
  expect_equal(nrow(btc), 1L,
               info = "Bitcoin not in top-10 - implausible market state.")
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
    # circulating supply must be in [10M, 21M] - protocol-defined range
    expect_true(btc$circulating_supply > 1e7 &&
                  btc$circulating_supply < 2.2e7,
                info = sprintf("BTC circulating supply out of bounds: %g",
                               btc$circulating_supply))
  }

  # Percent-change parser sanity: at least one non-zero / non-NA 24h
  # change across the top-10 - protects against silent NA fields.
  ok <- any(!is.na(ls$percent_change_24h) & ls$percent_change_24h != 0)
  expect_true(ok,
              info = "All percent_change_24h are NA or 0 across top 10 coins.")
})

# ---- cg_history sanity -----------------------------------------------------
#
# ONE cg_history() call covers both BTC and ETH (the previous suite made
# two separate calls). Pulls only price+market_cap (saves the OHLC HTTP
# call) over a tiny 4-day window. cg_history filters client-side, so the
# date range doesn't change the per-call payload; just keeps things
# semantically minimal.

test_that("cg_history: BTC + ETH price/mcap sanity (single batched call)", {
  skip_if_no_cg()
  cg_pace(2)
  u <- tibble::tibble(slug = c("bitcoin", "ethereum"), id = c(1L, 279L))
  h <- cg_history(coin_list = u, what = c("price", "market_cap"),
                  start_date = Sys.Date() - 4)
  skip_if(is.null(h) || !nrow(h),
          "cg_history returned no data (likely network blip).")
  expect_s3_class(h$timestamp, "POSIXct")
  expect_true(all(as.numeric(h$timestamp) %% 86400 == 0),
              info = "cg_history timestamps not all daily UTC midnight")

  # --- BTC bounds (catches unit-parser bugs) ---
  btc <- h[h$slug == "bitcoin", , drop = FALSE]
  expect_gt(nrow(btc), 0)
  expect_true(all(btc$close > 100 & btc$close < 1e7),
              info = "BTC close prices out of plausible bounds.")

  # --- ETH cross-stream consistency: market_cap / price ~ supply ---
  # If /market_cap and /price_charts return data from different days or
  # in different units, the implied supply diverges wildly.
  eth <- h[h$slug == "ethereum" &
             !is.na(h$close) & !is.na(h$market_cap), , drop = FALSE]
  expect_gt(nrow(eth), 0)
  implied_supply <- eth$market_cap / eth$close
  expect_true(all(implied_supply > 1e7 & implied_supply < 1e9),
              info = sprintf(
                "Implied ETH supply (mcap/price) out of bounds: range [%g, %g]",
                min(implied_supply), max(implied_supply)))
})

# ---- cg_info sanity --------------------------------------------------------
#
# Single cg_info() call covers both BTC + ETH (cg_info takes a tibble of
# slugs). Was previously two calls.

test_that("cg_info: BTC + ETH genesis dates, slug-to-id mapping, metadata populated", {
  skip_if_no_cg()
  skip_if_cg_rate_limited()
  cg_pace(3)
  out <- cg_info(tibble::tibble(slug = c("bitcoin", "ethereum")))
  skip_if(is.null(out) || nrow(out) < 2,
          "cg_info returned no data (likely 429).")

  eth <- out[out$slug == "ethereum", , drop = FALSE]
  expect_equal(nrow(eth), 1L)
  # ETH genesis_date is 2015-07-30. If CoinGecko revised this, surface it.
  expect_equal(eth$date_added, KNOWN_COINS$ethereum$genesis_date,
               info = sprintf("ETH genesis_date drift: got '%s', expected '%s'",
                              as.character(eth$date_added),
                              as.character(KNOWN_COINS$ethereum$genesis_date)))

  btc <- out[out$slug == "bitcoin", , drop = FALSE]
  expect_equal(nrow(btc), 1L)
  expect_equal(btc$id, KNOWN_COINS$bitcoin$numeric_id)
  expect_equal(btc$symbol, "btc")
  expect_match(tolower(btc$name), "bitcoin")
  expect_true(nchar(btc$description) > 100,
              info = "BTC description suspiciously short - content may have changed.")
  expect_match(btc$logo, "coingecko\\.com/coins/images/1/")
})
