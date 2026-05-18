#' Get historic crypto currency market data from CoinGecko
#'
#' Companion to [crypto_history()] but for CoinGecko. Returns daily OHLC,
#' volume, and market-cap timeseries in a tibble whose column names match
#' the crypto2 CMC output.
#'
#' Source endpoints (no API key required) are addressed internally by
#' [cg_url()]; the package source does not embed the host URLs in
#' plain text. When the requested coin's numeric id is missing in
#' `coin_list`, [cg_id_mapping()] is consulted to recover it. If both the
#' slug-based and the numeric-id-based routes fail, the coin is silently
#' skipped (the most common cause is a Cloudflare bot challenge -- see
#' [cg_get()]).
#'
#' Free-tier caveat: the public CoinGecko Demo endpoints cap historic
#' retrieval at 365 days per coin. When `start_date` is more than 365 days
#' in the past and the website-host endpoints are unavailable (e.g. blocked
#' by Cloudflare), only the most recent 365 days are returned, with a
#' single one-line warning.
#'
#' @param coin_list string if NULL retrieve all currently existing coins
#'   ([cg_list()]), or provide list of crypto currencies in the [cg_list()] /
#'   [cg_listings()] format.
#' @param convert (default: `"USD"`). Be aware that the CoinGecko free tier
#'   typically supports only `"USD"` and `"BTC"` reliably.
#' @param limit integer Return the top n records, default is all tokens.
#' @param start_date,end_date date Filter the returned timeseries to this
#'   date window after fetching.
#' @param interval string Always coerced to `"daily"` -- CoinGecko website
#'   endpoints return daily granularity for full-history pulls. Hourly is
#'   not available without an API key.
#' @param requestLimit Kept for parity with [crypto_history()] -- ignored
#'   (CoinGecko returns full history per coin in one call).
#' @param sleep integer (default `0`) Seconds to sleep between API requests.
#'   The internal client enforces a polite floor of `0.6` to keep the
#'   website host happy.
#' @param wait waiting time before retry in case of fail (default `60`).
#' @param finalWait Sleep 60s after the last call (mirrors
#'   [crypto_history()]).
#' @param single_id Kept for parity with [crypto_history()] -- ignored;
#'   CoinGecko endpoints are always single-coin per call.
#'
#' @return Crypto currency historic OHLC market data in a tibble:
#'   \item{id}{CoinGecko internal numeric id (NA if unknown).}
#'   \item{slug, name, symbol}{Coin identifiers.}
#'   \item{timestamp}{POSIXct (UTC), midnight of the trading day.}
#'   \item{ref_cur_id}{Quote currency code (e.g. `"usd"`).}
#'   \item{ref_cur_name}{Upper-cased quote currency.}
#'   \item{open, high, low, close}{Daily OHLC; `close` is back-filled from
#'     the price-charts series when OHLC candles are unavailable.}
#'   \item{volume}{Daily total volume.}
#'   \item{market_cap}{Daily market cap.}
#'   \item{time_open, time_high, time_low, time_close}{`NA` -- CoinGecko does
#'     not expose intra-day OHLC timestamps in these endpoints.}
#'
#' @examples
#' \dontrun{
#' # Top 50 by market cap, full available history
#' top50 <- cg_list()[1:50, ]
#' hist  <- cg_history(top50)
#'
#' # Bitcoin only, last year
#' btc <- cg_history(cg_list()[1, ],
#'                   start_date = Sys.Date() - 365,
#'                   end_date   = Sys.Date())
#' }
#'
#' @name cg_history
#'
#' @importFrom dplyr bind_rows full_join transmute mutate select arrange filter relocate
#' @importFrom tibble tibble
#' @importFrom progress progress_bar
#' @importFrom cli cat_bullet
#' @export
cg_history <- function(coin_list = NULL, convert = "USD", limit = NULL,
                       start_date = NULL, end_date = NULL,
                       interval = NULL,
                       requestLimit = 400, sleep = 0, wait = 60,
                       finalWait = FALSE, single_id = TRUE) {
  if (!is.null(interval) && !identical(interval, "daily")) {
    warning("CoinGecko free-tier returns daily granularity only; ",
            "`interval` argument is ignored.", call. = FALSE)
  }
  vs <- tolower(convert)

  max_retries <- getOption("crypto2.cg_max_retries", 3)
  sleep_eff   <- max(sleep, getOption("crypto2.cg_sleep_web", 0.6))
  what        <- getOption("crypto2.cg_what",
                           c("price", "market_cap", "ohlc"))

  if (is.null(coin_list)) coin_list <- cg_list()
  if (!"slug" %in% names(coin_list)) {
    stop("`coin_list` must contain a `slug` column.", call. = FALSE)
  }
  if (!is.null(limit)) coin_list <- coin_list[seq_len(min(limit, nrow(coin_list))), ]

  # Backfill numeric ids from the historic mapping where missing
  if (!("id" %in% names(coin_list)) || any(is.na(coin_list$id))) {
    mapping <- tryCatch(cg_id_mapping(quiet = TRUE),
                        error = function(e) NULL)
    if (!is.null(mapping) && nrow(mapping) > 0L) {
      mp <- mapping[, c("slug", "id")]
      names(mp)[2] <- ".id_from_map"
      coin_list <- merge(coin_list, mp, by = "slug",
                         all.x = TRUE, sort = FALSE)
      if (!"id" %in% names(coin_list)) coin_list$id <- NA_integer_
      coin_list$id <- ifelse(is.na(coin_list$id),
                             coin_list$.id_from_map, coin_list$id)
      coin_list$.id_from_map <- NULL
    }
  }

  # 365-day-window pre-flight warning
  if (!is.null(start_date) &&
      as.Date(start_date) < Sys.Date() - 365L) {
    if (!isTRUE(getOption("crypto2.cg_long_window_warned", FALSE))) {
      warning("CoinGecko free-tier Demo endpoints cap historic retrieval at ",
              "365 days per coin. Older history is only available via the ",
              "website-host endpoints (used here when reachable), which may ",
              "be blocked by Cloudflare from cloud / datacenter IPs.",
              call. = FALSE)
      options(crypto2.cg_long_window_warned = TRUE)
    }
  }

  client <- cg_make_client(sleep = sleep_eff, wait = wait,
                           max_retries = max_retries)

  # Helper: collapse a (timestamp, value...) tibble to daily bars on the UTC
  # calendar.
  floor_daily <- function(df, value_cols) {
    if (is.null(df) || !nrow(df)) return(df)
    df$date <- as.Date(df$timestamp, tz = "UTC")
    df <- df[order(df$date, df$timestamp), , drop = FALSE]
    df <- df[!duplicated(df$date, fromLast = TRUE), , drop = FALSE]
    df[, c("date", value_cols), drop = FALSE]
  }

  fetch_one <- function(slug, numeric_id, name = NA_character_,
                        symbol = NA_character_) {
    out <- NULL

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
            dplyr::mutate(close = ifelse(is.na(close_o), close, close_o)) %>%
            dplyr::select(-close_o)
        }
      }
    }

    if (is.null(out) || !nrow(out)) return(NULL)

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

  n <- nrow(coin_list)
  pb <- progress::progress_bar$new(
    format = ":spin [:current / :total] [:bar] :percent in :elapsedfull ETA: :eta",
    total = n, clear = FALSE)
  message(cli::cat_bullet("Scraping historical CoinGecko data",
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
