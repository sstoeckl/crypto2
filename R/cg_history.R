#' Get historic crypto currency market data from CoinGecko
#'
#' Companion to [crypto_history()] but for CoinGecko. Returns daily OHLC,
#' volume, and market-cap timeseries in a tibble whose column names match
#' the crypto2 CMC output.
#'
#' No API key is required. When the requested coin's numeric id is missing
#' in `coin_list`, [cg_id_mapping()] is consulted to fill the `id` column.
#'
#' All data come from CoinGecko's website chart endpoints; no API and no
#' key are used. Coverage:
#' * **Close, volume and market cap for the full lifetime of each coin**,
#'   in any quote currency. In USD they come from CoinGecko's daily CSV
#'   export (one request per coin), otherwise from the website's chart data
#'   (two requests per coin).
#' * **OHLC** (`open` / `high` / `low`) is built from 4-hour candles (one
#'   extra request per coin) and covers the **most recent 30 days**; older
#'   rows have `NA` there. Longer windows are only offered as 4-day
#'   candles, which are not daily bars. For a one-shot complete OHLC
#'   backfill see `vignette("coingecko-pro-backfill")`.
#'
#' Only completed days are returned. If no close/volume/market-cap series
#' can be retrieved for any requested coin, the function stops with an
#' error (the source has most likely changed); if it fails for some coins
#' only, a warning names them.
#'
#' @param coin_list string if NULL retrieve all currently existing coins
#'   ([cg_list()]), or provide list of crypto currencies in the [cg_list()] /
#'   [cg_listings()] format.
#' @param convert (default: `"USD"`). Any CoinGecko quote currency, e.g.
#'   `"BTC"`, `"ETH"` or `"EUR"`.
#' @param limit integer Return the top n records, default is all tokens.
#' @param start_date,end_date date Filter the returned timeseries to this
#'   date window after fetching.
#' @param interval string Always coerced to `"daily"` -- CoinGecko website
#'   endpoints return daily granularity for full-history pulls. Hourly is
#'   not available without an API key.
#' @param requestLimit Kept for parity with [crypto_history()] -- ignored
#'   (CoinGecko returns full history per coin in one call).
#' @param sleep integer (default `0`) Seconds to sleep between API requests.
#'   The internal client enforces a polite floor to stay within CoinGecko's
#'   per-minute budget.
#' @param wait waiting time before retry in case of fail (default `60`).
#' @param finalWait Sleep 60s after the last call (mirrors
#'   [crypto_history()]).
#' @param single_id Kept for parity with [crypto_history()] -- ignored;
#'   CoinGecko endpoints are always single-coin per call.
#' @param date_convention Either `"end_of_day"` (the default) or `"raw"`.
#'   CoinGecko's native daily series timestamps each point at 00:00:00 UTC
#'   of date X, which is the same physical instant as 23:59:59 UTC of date
#'   X-1 -- i.e. CG labels it as the start-of-day rather than the
#'   close-of-day. CMC (and `crypto_history()`) label that instant as
#'   date X-1 (the day that just ended), which is also the standard
#'   asset-pricing convention used by CRSP/Compustat and major academic
#'   datasets. With `"end_of_day"` (default) `cg_history()` shifts CG's
#'   midnight ticks by -1 day so `close[X] / close[X-1] - 1` is the return
#'   earned during date X, matching CMC. Pass `"raw"` to keep CG's native
#'   start-of-day labelling.
#'
#' @return Crypto currency historic OHLC market data in a tibble:
#'   \item{id}{CoinGecko internal numeric id (NA if unknown).}
#'   \item{slug, name, symbol}{Coin identifiers.}
#'   \item{timestamp}{POSIXct (UTC), midnight of the trading day.}
#'   \item{ref_cur_id}{Quote currency code (e.g. `"usd"`).}
#'   \item{ref_cur_name}{Upper-cased quote currency.}
#'   \item{open, high, low}{Daily OHLC from 4-hour candles (last 30 days).}
#'   \item{close}{Daily close from the price series; back-filled from the
#'     OHLC candles where the price series has no value.}
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
                       finalWait = FALSE, single_id = TRUE,
                       date_convention = c("end_of_day", "raw")) {
  date_convention <- match.arg(date_convention)
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

  cg_warn_history_coverage(what, start_date)

  web_client <- cg_make_client(sleep = sleep_eff, wait = wait,
                               max_retries = max_retries)

  n <- nrow(coin_list)
  pb <- progress::progress_bar$new(
    format = ":spin [:current / :total] [:bar] :percent in :elapsedfull ETA: :eta",
    total = n, clear = FALSE)
  message(cli::cat_bullet("Scraping historical CoinGecko data",
                          bullet = "pointer", bullet_col = "green"))

  col_or_na <- function(col, na) if (col %in% names(coin_list)) coin_list[[col]] else rep(na, n)
  ids     <- col_or_na("id", NA_integer_)
  names_  <- col_or_na("name", NA_character_)
  symbols <- col_or_na("symbol", NA_character_)

  results  <- vector("list", n)
  price_ok <- ohlc_ok <- rep(NA, n)
  for (i in seq_len(n)) {
    pb$tick()
    slug <- coin_list$slug[i]
    r <- tryCatch(
      cg_fetch_daily(key = slug, vs = vs, what = what,
                     web_client = web_client,
                     date_convention = date_convention),
      error = function(e) list(data = NULL, price_ok = FALSE, ohlc_ok = NA))
    price_ok[i] <- r$price_ok
    ohlc_ok[i]  <- r$ohlc_ok
    if (is.null(r$data)) next
    results[[i]] <- r$data %>%
      dplyr::mutate(
        timestamp    = as.POSIXct(date, tz = "UTC"),
        id           = as.integer(ids[i]),
        slug         = slug,
        name         = names_[i],
        symbol       = symbols[i],
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
  cg_report_daily_failures(
    "cg_history", coin_list$slug, price_ok, ohlc_ok,
    source_alive = function() cg_source_alive(vs, web_client))
  results <- Filter(Negate(is.null), results)

  if (!length(results)) {
    if (!any(price_ok %in% FALSE)) warning("cg_history(): no data returned.", call. = FALSE)
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
