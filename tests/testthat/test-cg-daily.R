# Offline tests for the daily-series internals behind cg_history() and
# cg_history_by_id() (R/cg_daily.R).

utc <- function(x) as.POSIXct(x, tz = "UTC")
day_ms <- function(x) as.numeric(utc(x)) * 1000

# Mirrors the etl2 chart JSON: midnight ticks plus a trailing "now" point.
fake_chart_json <- function(values) as.character(jsonlite::toJSON(list(
  stats = rbind(c(day_ms("2026-09-27"), values[1]), c(day_ms("2026-09-28"), values[2]),
                c(day_ms("2026-09-28") + 3600e3, 99)),
  total_volumes = rbind(c(day_ms("2026-09-27"), 5), c(day_ms("2026-09-28"), 6),
                        c(day_ms("2026-09-28") + 3600e3, 99))), digits = NA))

fake_web <- function(coin, vs, close, mcap) {
  seen <- new.env()
  seen$urls <- character()
  fn <- function(url, ...) {
    seen$urls <- c(seen$urls, url)
    if (endsWith(url, sprintf("etl2/price_charts/%s/%s/max.json", coin, vs))) fake_chart_json(close)
    else if (endsWith(url, sprintf("etl2/market_cap/%s/%s/max.json", coin, vs))) fake_chart_json(mcap)
  }
  list(fn = fn, seen = seen)
}

test_that("cg_fetch_daily() aligns close, volume and market cap per trading day", {
  w <- fake_web("bitcoin", "usd", c(100, 110), c(1000, 1100))
  r <- cg_fetch_daily("bitcoin", "usd", c("price", "market_cap"), w$fn, "end_of_day")
  d <- r$data
  expect_true(r$price_ok)
  expect_true(is.na(r$ohlc_ok))
  # the 00:00 tick of date X is the close of X-1; the running point is dropped
  expect_equal(d$date, as.Date(c("2026-09-26", "2026-09-27")))
  expect_equal(d$close, c(100, 110))
  expect_equal(d$market_cap, c(1000, 1100))
  expect_equal(d$volume, c(5, 6))
  expect_true(all(is.na(d$open)))
  expect_false(any(grepl("export|api.coingecko", w$seen$urls)))

  raw <- cg_fetch_daily("bitcoin", "usd", c("price", "market_cap"), w$fn, "raw")$data
  expect_equal(raw$date, as.Date(c("2026-09-27", "2026-09-28")))
})

test_that("non-USD series come from the same etl2 charts", {
  w <- fake_web("ethereum", "btc", c(1.1, 1.2), c(11, 12))
  d <- cg_fetch_daily("ethereum", "btc", c("price", "market_cap"), w$fn,
                      "end_of_day")$data
  expect_equal(d$date, as.Date(c("2026-09-26", "2026-09-27")))
  expect_equal(d$close, c(1.1, 1.2))
  expect_equal(d$market_cap, c(11, 12))
})

ohlc_json <- function(candles) as.character(jsonlite::toJSON(list(ohlc = unname(candles)), digits = NA))

test_that("cg_ohlc_daily() aggregates complete days of 4-hour candles only", {
  ts <- seq(utc("2026-09-26 04:00"), utc("2026-09-28 08:00"), by = "4 hours")
  k <- seq_along(ts)
  candles <- cbind(as.numeric(ts) * 1000, open = k, high = k + 0.5,
                   low = k - 0.5, close = k + 0.25)
  seen <- NULL
  web <- function(url, ...) { seen <<- url; ohlc_json(candles) }
  o <- cg_ohlc_daily("bitcoin", "usd", web, "end_of_day")
  expect_true(endsWith(seen, "www.coingecko.com/etl2/ohlc/bitcoin/series/usd/30_days.json"))
  # candles closing in (D, D+1] belong to D; 2026-09-28 is incomplete
  expect_equal(o$date, as.Date(c("2026-09-26", "2026-09-27")))
  expect_equal(o$open, c(1, 7))
  expect_equal(o$high, c(6.5, 12.5))
  expect_equal(o$low, c(0.5, 6.5))
  expect_equal(o$close_o, c(6.25, 12.25))
  expect_equal(cg_ohlc_daily("bitcoin", "usd", web, "raw")$date,
               as.Date(c("2026-09-27", "2026-09-28")))
})

test_that("cg_ohlc_daily() rejects 4-day candles", {
  ts <- seq(utc("2026-08-01"), utc("2026-09-26"), by = "4 days")
  candles <- cbind(as.numeric(ts) * 1000, 1, 2, 0.5, 1.5)
  expect_null(cg_ohlc_daily("bitcoin", "usd", function(url, ...) ohlc_json(candles),
                            "end_of_day"))
})

test_that("failures are reported loudly", {
  expect_error(cg_report_daily_failures("cg_history", c("a", "b"),
                                        c(FALSE, FALSE), c(NA, NA)),
               "no close/volume/market-cap series for any of the 2")
  # everything failed, but Bitcoin still resolves: bad ids, not a dead source
  expect_warning(cg_report_daily_failures("cg_history", "9999999", FALSE, NA,
                                          source_alive = function() TRUE),
                 "1 of 1 coin\\(s\\): 9999999")
  expect_warning(cg_report_daily_failures("cg_history", c("a", "b"),
                                          c(TRUE, FALSE), c(NA, NA)),
                 "1 of 2 coin\\(s\\): b")
  expect_warning(cg_report_daily_failures("cg_history", "a", TRUE, FALSE),
                 "no daily OHLC")
  expect_silent(cg_report_daily_failures("cg_history", "a", TRUE, NA))
})

test_that("cg_history() stops when the history source is gone", {
  withr::local_options(crypto2.cg_sleep = 0, crypto2.cg_sleep_web = 0,
                       crypto2.cg_max_retries = 1)
  local_mocked_bindings(cg_get = function(url, query = NULL, ...) NULL)
  expect_error(
    cg_history(tibble::tibble(slug = c("bitcoin", "ethereum"), id = c(1L, 279L)),
               wait = 0.01),
    "no close/volume/market-cap series for any of the 2")
})

# ---- opt-in API fallback ---------------------------------------------------

fake_api_chart <- function(url, query = NULL, ...) {
  if (grepl("market_chart", url)) {
    as.character(jsonlite::toJSON(list(
      prices        = rbind(c(day_ms("2026-09-27"), 7.1), c(day_ms("2026-09-28"), 7.2)),
      market_caps   = rbind(c(day_ms("2026-09-27"), 71), c(day_ms("2026-09-28"), 72)),
      total_volumes = rbind(c(day_ms("2026-09-27"), 1), c(day_ms("2026-09-28"), 2))),
      digits = NA))
  }
}
dead_web <- function(url, ...) NULL

test_that("without the opt-in the API is never used", {
  api_called <- FALSE
  api <- function(...) { api_called <<- TRUE; NULL }
  r <- cg_fetch_daily("bitcoin", "usd", c("price", "market_cap"), dead_web,
                      "end_of_day", slug = "bitcoin", api_client = NULL)
  expect_false(r$price_ok)
  expect_false(r$used_api)
  expect_false(api_called)
})

test_that("with an api_client, coins the website cannot serve come from the API", {
  r <- cg_fetch_daily("bitcoin", "usd", c("price", "market_cap"), dead_web,
                      "end_of_day", slug = "bitcoin", api_client = fake_api_chart)
  expect_true(r$price_ok)
  expect_true(r$used_api)
  expect_equal(r$data$close, c(7.1, 7.2))
})

test_that("cg_history() falls back only when opted in, and says so", {
  withr::local_options(crypto2.cg_sleep = 0, crypto2.cg_sleep_web = 0,
                       crypto2.cg_max_retries = 1,
                       crypto2.cg_what = c("price", "market_cap"))
  local_mocked_bindings(cg_get = function(url, query = NULL, ...) {
    if (grepl("api.coingecko.com", url, fixed = TRUE)) fake_api_chart(url, query) else NULL
  })
  coins <- tibble::tibble(slug = "bitcoin", id = 1L)

  withr::local_options(crypto2.cg_api_fallback = FALSE)
  expect_error(cg_history(coins, wait = 0.01),
               "crypto2.cg_api_fallback = TRUE.*365 days")

  withr::local_options(crypto2.cg_api_fallback = TRUE)
  expect_warning(h <- cg_history(coins, wait = 0.01),
                 "fetched from the public API instead.*365 days")
  expect_equal(attr(h, "cg_api_fallback"), "bitcoin")
  expect_equal(h$close, c(7.1, 7.2))
})
