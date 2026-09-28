# Internal: daily series shared by cg_history() and cg_history_by_id().
#
# Sources (free tier, no key):
# * USD close / volume / market cap, full history: the website CSV export
#   `price_charts/export/<slug-or-numeric-id>/usd.csv`. It is USD-only
#   (other currency paths return the same USD values).
# * Other quote currencies: the documented API
#   `/coins/<slug>/market_chart?interval=daily`, limited to the last 365
#   days without a paid plan.
# * Daily OHLC: aggregated from the 4-hour candles of
#   `ohlc/<numeric-id>/series/<vs>/30_days.json` -- longer windows only come
#   as 4-day candles, which are not daily bars and are not used.

# Collapse a (timestamp, value...) tibble to daily bars on the UTC calendar.
# CoinGecko's daily ticks sit at 00:00 UTC of date X, i.e. the close of date
# X-1. Under `date_convention = "end_of_day"` (the default) midnight ticks
# are attributed to the previous date to match CMC's close-of-day labelling;
# non-midnight points keep their own date.
floor_daily_ <- function(df, value_cols,
                         date_convention = "end_of_day") {
  if (is.null(df) || !nrow(df)) return(df)
  raw_date <- as.Date(df$timestamp, tz = "UTC")
  if (date_convention == "end_of_day") {
    is_midnight <- (as.numeric(df$timestamp) %% 86400) == 0
    df$date <- as.Date(ifelse(is_midnight, raw_date - 1L, raw_date),
                       origin = "1970-01-01")
  } else {
    df$date <- raw_date
  }
  df <- df[order(df$date, df$timestamp), , drop = FALSE]
  df <- df[!duplicated(df$date, fromLast = TRUE), , drop = FALSE]
  df[, c("date", value_cols), drop = FALSE]
}

# Parse the CSV export into midnight ticks. Its columns are not aligned: a
# row dated X carries the market cap and 24h volume observed at 00:00 X,
# but the close observed at 00:00 X+1 (the latest row, the running day, has
# no close yet). Re-timing the close by +1 day puts all three streams on the
# same tick grid as the API's market_chart series.
cg_parse_export_csv <- function(txt) {
  if (is.null(txt) || !nzchar(txt)) return(NULL)
  d <- tryCatch(utils::read.csv(text = txt, stringsAsFactors = FALSE),
                error = function(e) NULL)
  need <- c("event_date", "close_price_usd", "market_cap_usd", "volume_usd")
  if (is.null(d) || !nrow(d) || !all(need %in% names(d))) return(NULL)
  t <- as.POSIXct(d$event_date, format = "%Y-%m-%d %H:%M:%S", tz = "UTC")
  close <- tibble::tibble(timestamp = t + 86400,
                          close = suppressWarnings(as.numeric(d$close_price_usd)))
  list(
    close      = close[!is.na(close$timestamp) & !is.na(close$close), ],
    volume     = tibble::tibble(timestamp = t,
                                volume = suppressWarnings(as.numeric(d$volume_usd))),
    market_cap = tibble::tibble(timestamp = t,
                                market_cap = suppressWarnings(as.numeric(d$market_cap_usd)))
  )
}

cg_ticks_export <- function(key, web_client) {
  cg_parse_export_csv(web_client(
    cg_url(sprintf("price_charts/export/%s/usd.csv", key)),
    accept = "text/csv, */*"))
}

# Only completed days are kept: the trailing non-midnight "now" point is
# dropped so the API path returns the same days as the CSV path.
cg_ticks_api <- function(slug, vs, api_client) {
  pj <- cg_parse_json(api_client(
    cg_url(sprintf("coins/%s/market_chart", slug), host = "api"),
    query = list(vs_currency = vs, days = 365, interval = "daily")))
  if (is.null(pj) || !length(pj$prices)) return(NULL)
  mk <- function(m, col) {
    if (!length(m)) return(NULL)
    tb <- tibble::tibble(timestamp = cg_ms_to_posix(m[, 1]))
    tb[[col]] <- as.numeric(m[, 2])
    tb[as.numeric(tb$timestamp) %% 86400 == 0, ]
  }
  list(close      = mk(pj$prices, "close"),
       volume     = mk(pj$total_volumes, "volume"),
       market_cap = mk(pj$market_caps, "market_cap"))
}

# Daily OHLC from intraday candles. Candle timestamps are close times, so
# a candle closing in (D 00:00, D+1 00:00] belongs to trading day D. Only
# days fully covered by candles are returned.
cg_ohlc_daily <- function(numeric_id, vs, web_client, date_convention) {
  oj <- cg_parse_json(web_client(cg_url(
    sprintf("ohlc/%d/series/%s/30_days.json", as.integer(numeric_id), vs))))
  if (is.null(oj) || is.null(oj$ohlc) || !length(oj$ohlc)) return(NULL)
  m <- oj$ohlc[order(oj$ohlc[, 1]), , drop = FALSE]
  ts <- cg_ms_to_posix(m[, 1])
  step <- stats::median(diff(as.numeric(ts)))
  if (!is.finite(step) || step <= 0 || 86400 %% step != 0) return(NULL)
  day <- as.Date(ts - 1, tz = "UTC")
  keep <- day %in% as.Date(names(which(table(day) == 86400 / step)))
  if (!any(keep)) return(NULL)
  m <- m[keep, , drop = FALSE]
  day <- day[keep]
  first <- !duplicated(day)
  last <- !duplicated(day, fromLast = TRUE)
  out <- tibble::tibble(
    date    = day[first],
    open    = as.numeric(m[first, 2]),
    high    = as.numeric(tapply(m[, 3], day, max)),
    low     = as.numeric(tapply(m[, 4], day, min)),
    close_o = as.numeric(m[last, 5])
  )
  if (date_convention == "raw") out$date <- out$date + 1L
  out
}

# One coin's daily bars. `key` addresses the CSV export (slug or numeric
# id); `slug` is needed for the non-USD API path, `numeric_id` for OHLC.
# Returns list(data = tibble or NULL, price_ok, ohlc_ok).
cg_fetch_daily <- function(key, slug, numeric_id, vs, what,
                           web_client, api_client, date_convention) {
  out <- NULL
  price_ok <- NA
  if (any(c("price", "market_cap") %in% what)) {
    ticks <- if (vs == "usd") {
      cg_ticks_export(key, web_client)
    } else if (!is.na(slug)) {
      cg_ticks_api(slug, vs, api_client)
    }
    price_ok <- !is.null(ticks) && NROW(ticks$close) > 0
    if (price_ok) {
      streams <- c(if ("price" %in% what) c("close", "volume"),
                   if ("market_cap" %in% what) "market_cap")
      for (s in streams) {
        if (is.null(ticks[[s]]) || !nrow(ticks[[s]])) next
        d <- floor_daily_(ticks[[s]], s, date_convention)
        out <- if (is.null(out)) d else dplyr::full_join(out, d, by = "date")
      }
      # the first market-cap tick precedes the first close by one day
      first_close <- min(floor_daily_(ticks$close, "close", date_convention)$date)
      out <- out[out$date >= first_close, , drop = FALSE]
    }
  }

  ohlc_ok <- NA
  if ("ohlc" %in% what && !is.na(numeric_id)) {
    ohlc <- cg_ohlc_daily(numeric_id, vs, web_client, date_convention)
    ohlc_ok <- !is.null(ohlc)
    if (ohlc_ok) {
      if (is.null(out)) {
        names(ohlc)[names(ohlc) == "close_o"] <- "close"
        out <- ohlc
      } else {
        out <- dplyr::full_join(out, ohlc, by = "date")
        if (!"close" %in% names(out)) out$close <- NA_real_
        out$close <- ifelse(is.na(out$close), out$close_o, out$close)
        out$close_o <- NULL
      }
    }
  }

  if (!is.null(out) && nrow(out)) {
    for (cc in setdiff(c("open", "high", "low", "close", "volume", "market_cap"),
                       names(out))) out[[cc]] <- NA_real_
    out <- out[order(out$date), , drop = FALSE]
  } else {
    out <- NULL
  }
  list(data = out, price_ok = price_ok, ohlc_ok = ohlc_ok)
}

# Once-per-session notes on what the free tier cannot deliver.
cg_warn_history_coverage <- function(vs, what, start_date) {
  if (vs != "usd" && any(c("price", "market_cap") %in% what) &&
      !isTRUE(getOption("crypto2.cg_non_usd_warned", FALSE))) {
    warning("CoinGecko's free full-history export is USD-only. For '",
            toupper(vs), "' close, volume and market cap come from the API ",
            "and cover the most recent 365 days only.", call. = FALSE)
    options(crypto2.cg_non_usd_warned = TRUE)
  }
  if ("ohlc" %in% what &&
      !is.null(start_date) && as.Date(start_date) < Sys.Date() - 30L &&
      !isTRUE(getOption("crypto2.cg_long_window_warned", FALSE))) {
    warning("CoinGecko free-tier daily OHLC (open / high / low) covers the ",
            "most recent 30 days only; older rows have NA there while close, ",
            "volume and market cap are returned in full. For a one-shot ",
            "complete OHLC backfill see vignette('coingecko-pro-backfill').",
            call. = FALSE)
    options(crypto2.cg_long_window_warned = TRUE)
  }
}

# Does the close/volume/market-cap source still answer for Bitcoin?
cg_source_alive <- function(vs, web_client, api_client) {
  ticks <- if (vs == "usd") cg_ticks_export("bitcoin", web_client) else
    cg_ticks_api("bitcoin", vs, api_client)
  !is.null(ticks) && NROW(ticks$close) > 0
}

# Loud failure reporting. If the close/volume/market-cap source failed for
# every coin and `source_alive()` confirms it is down for Bitcoin too, the
# endpoint has most likely changed: stop. Otherwise (delisted slugs, bogus
# ids) warn with the affected keys.
cg_report_daily_failures <- function(fn, keys, price_ok, ohlc_ok,
                                     source_alive = function() FALSE) {
  show <- function(k) paste0(paste(utils::head(k, 10), collapse = ", "),
                             if (length(k) > 10) ", ..." else "")
  tried <- !is.na(price_ok)
  if (any(tried) && !any(price_ok[tried]) && !isTRUE(source_alive())) {
    stop(sprintf(paste0(
      "%s(): CoinGecko returned no close/volume/market-cap series for any of ",
      "the %d requested coin(s) (%s). The endpoint may have changed; please ",
      "report at https://github.com/sstoeckl/crypto2/issues."),
      fn, sum(tried), show(keys[tried])), call. = FALSE)
  }
  failed <- tried & !price_ok
  if (any(failed)) {
    warning(sprintf("%s(): no close/volume/market-cap series for %d of %d coin(s): %s",
                    fn, sum(failed), sum(tried), show(keys[failed])),
            call. = FALSE)
  }
  tried_o <- !is.na(ohlc_ok)
  if (any(tried_o) && !any(ohlc_ok[tried_o])) {
    warning(sprintf("%s(): no daily OHLC for any of the %d coin(s) with a numeric id; open/high/low are NA.",
                    fn, sum(tried_o)), call. = FALSE)
  }
}
