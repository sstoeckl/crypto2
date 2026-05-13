#' Retrieve historic CoinGecko market data (OHLC + volume + market cap)
#'
#' Companion to `crypto_history()` but for CoinGecko, returning daily
#' time-series data in a tibble whose column names match crypto2's CMC output.
#' Uses CoinGecko's **undocumented website-host endpoints** (no API key
#' required, no documented rate limit) so it can be used for mass research
#' backfills.
#'
#' Per coin, up to three HTTP calls are made (each returning the coin's
#' **full** history in one response):
#' \describe{
#'   \item{`/price_charts/{slug}/{vs}/max.json`}{price + total volume (daily)}
#'   \item{`/market_cap/{slug}/{vs}/max.json`}{market cap (daily)}
#'   \item{`/ohlc/{numeric_id}/series/{vs}/max.json`}{OHLC — daily where the
#'     period covers ≥91 days, 4-day candles for older history per CoinGecko's
#'     OHLC granularity policy. Sparse on short date windows.}
#' }
#' The three series are joined on date. If a coin's numeric id is missing
#' (e.g. because the coin is outside the top market-cap pages enriched by
#' [cg_list()]), OHLC will be `NA` for that coin but price/volume/mcap will
#' still be returned. Pass an explicit `coin_list` that already has a
#' non-NA `id` column to guarantee OHLC.
#'
#' @param coin_list Tibble in the [cg_list()] / [cg_listings()] format
#'   (must contain at least `slug`; `id` recommended for OHLC). If `NULL`,
#'   `cg_list()` is called to fetch the active universe.
#' @param convert Quote currency, default `"USD"` (lower-cased before sending).
#' @param limit Optional cap on the number of coins to process (top of the
#'   tibble after sorting by `rank`).
#' @param start_date,end_date Filter the returned timeseries to this date
#'   window after fetching (the upstream endpoints always return full history
#'   in one call, so this is a client-side filter).
#' @param interval Always `"daily"` — CoinGecko's website endpoints return
#'   daily granularity for `max` periods. Hourly is not available without an
#'   API key.
#' @param what Subset of timeseries to fetch — character vector with any of
#'   `"price"`, `"market_cap"`, `"ohlc"`. Default `c("price","market_cap","ohlc")`.
#'   Drop `"ohlc"` if you don't need candles (saves one call per coin).
#' @param sleep Seconds between consecutive endpoint calls on the website
#'   host (default `0.6` → ~100 req/min, polite). Cloudflare may issue a 403
#'   challenge at higher rates from less reputable IPs.
#' @param wait Seconds to wait before retrying after a 429 / network error
#'   (default `60`). See [cg_make_client()].
#' @param max_retries Maximum retry attempts (default `3`). See
#'   [cg_make_client()].
#' @param finalWait Sleep 60s after the last call (mirrors `crypto_history()`).
#'
#' @return Tibble with one row per (coin, date) using crypto2-compatible
#'   column names:
#'   \item{id}{CoinGecko numeric id (NA if unknown).}
#'   \item{slug, name, symbol}{Coin identifiers.}
#'   \item{timestamp}{POSIXct (UTC), midnight of the trading day.}
#'   \item{ref_cur_id}{CoinGecko quote currency code (e.g. `"usd"`).}
#'   \item{ref_cur_name}{Upper-cased quote currency.}
#'   \item{open, high, low, close}{Daily OHLC, `NA` if `"ohlc"` not requested
#'     or numeric id missing. `close` is back-filled from the price endpoint
#'     when OHLC is missing — the price-charts series records the last spot
#'     price of the day, which is a reasonable close proxy.}
#'   \item{volume}{Daily total volume.}
#'   \item{market_cap}{Daily market cap.}
#'   \item{time_open, time_high, time_low, time_close}{`NA` — CoinGecko does
#'     not expose intra-day OHLC timestamps in these endpoints.}
#'
#' @examples
#' \dontrun{
#' # Pull full price+volume+market-cap+OHLC history for the top 50 coins.
#' top50 <- cg_list(top_n = 50)
#' hist  <- cg_history(coin_list = top50, what = c("price", "market_cap", "ohlc"))
#'
#' # Faster: skip OHLC if you only need close+volume+mcap
#' hist_fast <- cg_history(coin_list = top50, what = c("price", "market_cap"))
#' }
#'
#' @importFrom dplyr bind_rows full_join transmute mutate select arrange filter relocate
#' @importFrom tibble tibble
#' @importFrom purrr map
#' @importFrom progress progress_bar
#' @importFrom cli cat_bullet
#' @export
cg_history <- function(coin_list = NULL, convert = "USD", limit = NULL,
                       start_date = NULL, end_date = NULL,
                       interval = "daily",
                       what = c("price", "market_cap", "ohlc"),
                       sleep = 0.6, wait = 60, max_retries = 3,
                       finalWait = FALSE) {
  if (!identical(interval, "daily")) {
    warning("CoinGecko free-tier website endpoints return daily granularity ",
            "only for full-history pulls; `interval` argument is ignored.",
            call. = FALSE)
  }
  what <- match.arg(what, choices = c("price", "market_cap", "ohlc"),
                    several.ok = TRUE)
  vs <- tolower(convert)

  if (is.null(coin_list)) coin_list <- cg_list()
  if (!"slug" %in% names(coin_list)) {
    stop("`coin_list` must contain a `slug` column.", call. = FALSE)
  }
  if (!is.null(limit)) coin_list <- coin_list[seq_len(min(limit, nrow(coin_list))), ]

  client <- cg_make_client(sleep = sleep, wait = wait, max_retries = max_retries)

  # Helper: collapse a (timestamp, value...) tibble to daily bars on the UTC
  # calendar. The CG website endpoints intermix daily bars with a final
  # rolling "now" point in the same series, so we floor to date and keep the
  # last observation per day for each value column.
  floor_daily <- function(df, value_cols) {
    if (is.null(df) || !nrow(df)) return(df)
    df$date <- as.Date(df$timestamp, tz = "UTC")
    df <- df[order(df$date, df$timestamp), , drop = FALSE]
    # take the last row per date (latest timestamp wins)
    df <- df[!duplicated(df$date, fromLast = TRUE), , drop = FALSE]
    df[, c("date", value_cols), drop = FALSE]
  }

  # ---- per-coin fetcher ----
  fetch_one <- function(slug, numeric_id, name = NA_character_,
                        symbol = NA_character_) {
    out <- NULL

    # price + total_volumes
    if ("price" %in% what) {
      pj <- cg_parse_json(client(cg_url(
        sprintf("price_charts/%s/%s/max.json", slug, vs))))
      if (!is.null(pj) && length(pj$stats)) {
        pr <- tibble::tibble(
          timestamp = cg_ms_to_posix(pj$stats[, 1]),
          close     = as.numeric(pj$stats[, 2])
        )
        pr <- floor_daily(pr, "close")
        if (!is.null(pj$total_volumes) && length(pj$total_volumes)) {
          vol <- tibble::tibble(
            timestamp = cg_ms_to_posix(pj$total_volumes[, 1]),
            volume    = as.numeric(pj$total_volumes[, 2])
          )
          vol <- floor_daily(vol, "volume")
          pr <- dplyr::full_join(pr, vol, by = "date")
        } else {
          pr$volume <- NA_real_
        }
        out <- pr
      }
    }

    # market_cap
    if ("market_cap" %in% what) {
      mj <- cg_parse_json(client(cg_url(
        sprintf("market_cap/%s/%s/max.json", slug, vs))))
      if (!is.null(mj) && length(mj$stats)) {
        mc <- tibble::tibble(
          timestamp  = cg_ms_to_posix(mj$stats[, 1]),
          market_cap = as.numeric(mj$stats[, 2])
        )
        mc <- floor_daily(mc, "market_cap")
        out <- if (is.null(out)) mc else dplyr::full_join(out, mc, by = "date")
      }
    }

    # OHLC (numeric id required)
    if ("ohlc" %in% what && !is.na(numeric_id)) {
      oj <- cg_parse_json(client(cg_url(
        sprintf("ohlc/%d/series/%s/max.json", as.integer(numeric_id), vs))))
      if (!is.null(oj) && !is.null(oj$ohlc) && length(oj$ohlc)) {
        ohlc <- tibble::tibble(
          timestamp = cg_ms_to_posix(oj$ohlc[, 1]),
          open      = as.numeric(oj$ohlc[, 2]),
          high      = as.numeric(oj$ohlc[, 3]),
          low       = as.numeric(oj$ohlc[, 4]),
          close_o   = as.numeric(oj$ohlc[, 5])
        )
        ohlc <- floor_daily(ohlc, c("open","high","low","close_o"))
        if (is.null(out)) {
          out <- ohlc %>% dplyr::mutate(close = close_o) %>% dplyr::select(-close_o)
        } else {
          out <- dplyr::full_join(out, ohlc, by = "date") %>%
            # prefer OHLC close when present, else keep price-charts close
            dplyr::mutate(close = ifelse(is.na(close_o), close, close_o)) %>%
            dplyr::select(-close_o)
        }
      }
    }

    if (is.null(out) || !nrow(out)) return(NULL)

    # Add identifiers + ensure all expected columns present
    expected_cols <- c("open", "high", "low", "close", "volume", "market_cap")
    for (cc in setdiff(expected_cols, names(out))) out[[cc]] <- NA_real_

    out %>%
      dplyr::mutate(
        timestamp    = as.POSIXct(date, tz = "UTC"),
        id           = as.integer(numeric_id),
        slug         = slug,
        name         = name,
        symbol       = symbol,
        ref_cur_id   = vs,
        ref_cur_name = toupper(vs),
        time_open    = as.POSIXct(NA),
        time_high    = as.POSIXct(NA),
        time_low     = as.POSIXct(NA),
        time_close   = as.POSIXct(NA)
      ) %>%
      dplyr::select(
        id, slug, name, symbol, timestamp,
        ref_cur_id, ref_cur_name,
        open, high, low, close, volume, market_cap,
        time_open, time_high, time_low, time_close
      )
  }

  # ---- batch with progress ----
  n <- nrow(coin_list)
  pb <- progress::progress_bar$new(
    format = ":spin [:current / :total] [:bar] :percent in :elapsedfull ETA: :eta",
    total = n, clear = FALSE)
  message(cli::cat_bullet("Scraping CoinGecko history (",
                          paste(what, collapse = "+"), ")",
                          bullet = "pointer", bullet_col = "green"))

  results <- vector("list", n)
  for (i in seq_len(n)) {
    pb$tick()
    results[[i]] <- tryCatch(
      fetch_one(
        slug       = coin_list$slug[i],
        numeric_id = if ("id" %in% names(coin_list)) coin_list$id[i] else NA_integer_,
        name       = if ("name" %in% names(coin_list)) coin_list$name[i] else NA_character_,
        symbol     = if ("symbol" %in% names(coin_list)) coin_list$symbol[i] else NA_character_
      ),
      error = function(e) NULL
    )
  }
  results <- Filter(Negate(is.null), results)

  if (!length(results)) {
    warning("cg_history(): no data returned.", call. = FALSE)
    return(tibble::tibble())
  }

  hist <- dplyr::bind_rows(results) %>%
    dplyr::arrange(slug, timestamp)

  # Client-side date filter
  if (!is.null(start_date)) {
    sd <- as.POSIXct(as.Date(start_date), tz = "UTC")
    hist <- dplyr::filter(hist, timestamp >= sd)
  }
  if (!is.null(end_date)) {
    ed <- as.POSIXct(as.Date(end_date) + 1, tz = "UTC")
    hist <- dplyr::filter(hist, timestamp < ed)
  }

  if (isTRUE(finalWait)) {
    pb2 <- progress::progress_bar$new(
      format = "Final wait [:bar] :percent eta: :eta",
      total = 60, clear = FALSE, width = 60)
    for (i in 1:60) { pb2$tick(); Sys.sleep(1) }
  }

  hist
}
