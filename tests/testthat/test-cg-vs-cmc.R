# Cross-source reconciliation: cg_history() vs crypto_history() for BTC.
#
# Catches:
#  * date-convention drift (a 1-day shift would surface as ~1% daily diff)
#  * unit-of-quote bugs in either function (USD vs sats vs cents)
#  * silent column renames that break the join
#
# Tolerance is 1% per day -- loose enough for legitimate
# exchange-weighting differences on BTC (typically <0.05% per day, with
# rare spikes up to ~0.5% in high-volatility windows), tight enough to
# fail loudly on a labelling error.
#
# Skipped on CRAN (two network calls) and on rate-limited CG sessions.

test_that("cg_history(BTC) reconciles with crypto_history(BTC) under default conventions", {
  skip_on_cran()
  skip_if_no_cg()
  skip_if_cg_rate_limited()
  cg_pace(3)

  start_date <- Sys.Date() - 7
  end_date   <- Sys.Date() - 1   # exclude today (incomplete CG snapshot)
  btc <- tibble::tibble(id = 1L, slug = "bitcoin",
                        name = "Bitcoin", symbol = "BTC")

  cmc <- tryCatch(
    crypto2::crypto_history(coin_list = btc, convert = "USD",
                            start_date = start_date, end_date = end_date,
                            finalWait = FALSE),
    error = function(e) NULL
  )
  skip_if(is.null(cmc) || !nrow(cmc), "crypto_history returned no data.")

  withr::local_options(crypto2.cg_what = c("price", "market_cap"))
  cg <- tryCatch(
    crypto2::cg_history(coin_list = btc, convert = "USD",
                        start_date = start_date, end_date = end_date),
    error = function(e) NULL
  )
  skip_if(is.null(cg) || !nrow(cg), "cg_history returned no data.")

  joined <- dplyr::inner_join(
    cmc |> dplyr::transmute(date = as.Date(timestamp), close_cmc = close),
    cg  |> dplyr::transmute(date = as.Date(timestamp), close_cg  = close),
    by = "date"
  ) |>
    dplyr::filter(!is.na(close_cmc), !is.na(close_cg), close_cmc > 0) |>
    dplyr::mutate(pct_diff = abs(close_cg - close_cmc) / close_cmc * 100)

  skip_if(nrow(joined) < 3,
          "fewer than 3 overlapping days; cannot reconcile reliably")

  worst <- max(joined$pct_diff, na.rm = TRUE)

  # 1% tolerance -- a date-convention shift would produce ~1-3% daily diffs.
  expect_lt(
    worst, 1.0,
    label = sprintf(
      "max |pct diff| between cg_history(BTC) and crypto_history(BTC) over %d days",
      nrow(joined)
    )
  )
})

test_that("cg_history(date_convention='raw') reproduces the 1-day start-of-day shift", {
  # Internal consistency: pulling the same window twice -- once with the
  # default end_of_day convention, once with raw -- should yield identical
  # closing prices but with dates differing by exactly 1 day on every
  # midnight-tick row.
  skip_on_cran()
  skip_if_no_cg()
  skip_if_cg_rate_limited()
  cg_pace(3)

  btc <- tibble::tibble(id = 1L, slug = "bitcoin",
                        name = "Bitcoin", symbol = "BTC")
  withr::local_options(crypto2.cg_what = c("price"))

  eod <- crypto2::cg_history(coin_list = btc, convert = "USD",
                             start_date = Sys.Date() - 5,
                             end_date   = Sys.Date() - 1)
  raw <- crypto2::cg_history(coin_list = btc, convert = "USD",
                             start_date = Sys.Date() - 5,
                             end_date   = Sys.Date() - 1,
                             date_convention = "raw")
  skip_if(is.null(eod) || !nrow(eod) ||
          is.null(raw) || !nrow(raw),
          "no CG history returned (likely network blip).")

  # Pair each EOD row with its raw counterpart 1 day later
  m <- dplyr::inner_join(
    eod |> dplyr::transmute(date = as.Date(timestamp), close_eod = close),
    raw |> dplyr::transmute(date_raw = as.Date(timestamp), close_raw = close,
                            date = date_raw - 1),
    by = "date"
  )

  skip_if(nrow(m) < 2,
          "no overlapping rows to compare raw vs end_of_day")

  expect_true(all(m$close_eod == m$close_raw),
              info = "raw and end_of_day prices differ on midnight ticks (they should be identical, only the date label shifts)")
})
