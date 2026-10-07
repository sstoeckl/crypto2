# Offline tests for the daily-series internals behind cg_history() and
# cg_history_by_id() (R/cg_daily.R).

# Mirrors the live export: a row dated X holds the close observed at 00:00
# X+1 but the market cap / volume observed at 00:00 X; the last row is the
# running day with no close yet.
fake_csv <- paste(
  "event_date,close_price_usd,market_cap_usd,volume_usd",
  "2026-09-25 00:00:00 UTC,100,1000,10",
  "2026-09-26 00:00:00 UTC,110,1100,11",
  "2026-09-27 00:00:00 UTC,120,1200,12",
  "2026-09-28 00:00:00 UTC,,1300,13",
  sep = "\n")

utc <- function(x) as.POSIXct(x, tz = "UTC")

test_that("cg_parse_export_csv() re-times the close to the next midnight", {
  tk <- cg_parse_export_csv(fake_csv)
  expect_equal(tk$close$timestamp, utc(c("2026-09-26", "2026-09-27", "2026-09-28")))
  expect_equal(tk$close$close, c(100, 110, 120))
  expect_equal(tk$market_cap$timestamp[4], utc("2026-09-28"))
  expect_equal(tk$market_cap$market_cap, c(1000, 1100, 1200, 1300))
  expect_null(cg_parse_export_csv("a,b\n1,2"))
  expect_null(cg_parse_export_csv(NULL))
})

fake_web <- function(url, ...) if (grepl("export", url)) fake_csv else NULL

test_that("cg_fetch_daily() aligns close, volume and market cap per trading day", {
  r <- cg_fetch_daily("bitcoin", "usd", c("price", "market_cap"), fake_web,
                      "end_of_day")
  d <- r$data
  expect_true(r$price_ok)
  expect_true(is.na(r$ohlc_ok))
  # trading day 2026-09-26: close = CSV row 09-26, mcap/volume = CSV row 09-27
  row <- d[d$date == as.Date("2026-09-26"), ]
  expect_equal(c(row$close, row$market_cap, row$volume), c(110, 1200, 12))
  expect_equal(max(d$date), as.Date("2026-09-27"))
  expect_true(all(is.na(d$open)))

  raw <- cg_fetch_daily("bitcoin", "usd", c("price", "market_cap"), fake_web,
                        "raw")$data
  row <- raw[raw$date == as.Date("2026-09-27"), ]
  expect_equal(c(row$close, row$market_cap, row$volume), c(110, 1200, 12))
})

day_ms <- function(x) as.numeric(utc(x)) * 1000
fake_chart_json <- function(values) as.character(jsonlite::toJSON(list(
  stats = rbind(c(day_ms("2026-09-27"), values[1]), c(day_ms("2026-09-28"), values[2]),
                c(day_ms("2026-09-28") + 3600e3, 99)),
  total_volumes = rbind(c(day_ms("2026-09-27"), 5), c(day_ms("2026-09-28"), 6),
                        c(day_ms("2026-09-28") + 3600e3, 99))), digits = NA))

test_that("non-USD series come from the etl2 charts, without the running point", {
  seen <- character()
  web <- function(url, ...) {
    seen <<- c(seen, url)
    if (grepl("etl2/price_charts/ethereum/btc/max.json$", url)) fake_chart_json(c(1.1, 1.2))
    else if (grepl("etl2/market_cap/ethereum/btc/max.json$", url)) fake_chart_json(c(11, 12))
  }
  d <- cg_fetch_daily("ethereum", "btc", c("price", "market_cap"), web,
                      "end_of_day")$data
  expect_false(any(grepl("api.coingecko|export", seen, fixed = FALSE)))
  expect_equal(d$date, as.Date(c("2026-09-26", "2026-09-27")))
  expect_equal(d$close, c(1.1, 1.2))
  expect_equal(d$market_cap, c(11, 12))
  expect_equal(d$volume, c(5, 6))
})

test_that("USD falls back to the etl2 charts when the CSV export fails", {
  web <- function(url, ...) {
    if (grepl("export", url)) NULL
    else if (grepl("etl2/price_charts/bitcoin/usd", url)) fake_chart_json(c(100, 110))
    else if (grepl("etl2/market_cap/bitcoin/usd", url)) fake_chart_json(c(1000, 1100))
  }
  r <- cg_fetch_daily("bitcoin", "usd", c("price", "market_cap"), web, "end_of_day")
  expect_true(r$price_ok)
  expect_equal(r$data$close, c(100, 110))
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
