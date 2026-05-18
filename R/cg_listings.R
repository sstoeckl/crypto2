#' Retrieves name, CG id, symbol, slug, rank, and quote data for current listings (CoinGecko)
#'
#' Companion to [crypto_listings()] but for CoinGecko. Returns one row per
#' coin with current price/volume/market-cap fields plus percent-change
#' windows. Column names mirror those of `crypto_listings()` so downstream
#' code that already consumes a CMC listings tibble works on this tibble too.
#'
#' CoinGecko free-tier limitations: only `which = "latest"` is supported.
#' `which = "historical"` and `which = "new"` produce a warning and are
#' coerced to `"latest"`, because CoinGecko's free tier does not expose the
#' historical cross-section. Snapshot this function periodically (daily /
#' weekly via a cron job) to accumulate a survivorship-bias-corrected
#' archive over time.
#'
#' @param which Always `"latest"` for CoinGecko free-tier. Other values
#'   produce a warning and are coerced to `"latest"`.
#' @param convert string (default: `"USD"`). The value is lower-cased and
#'   passed to CoinGecko as `vs_currency`. Common values: `"USD"`, `"BTC"`,
#'   `"ETH"`, `"EUR"`, `"GBP"`.
#' @param limit integer Return the top n records (default `5000` -- matches
#'   [crypto_listings()]).
#' @param start_date,end_date,interval Kept for API parity with
#'   [crypto_listings()] -- ignored for CoinGecko (no historical-listings
#'   endpoint on the free tier).
#' @param quote logical Kept for API parity. The CoinGecko `/coins/markets`
#'   endpoint always returns prices, so quote fields are always present;
#'   setting this to `FALSE` drops them from the returned tibble for
#'   parity with `crypto_listings()`.
#' @param sort,sort_dir Kept for parity. CoinGecko sorts by `market_cap_desc`
#'   on the underlying endpoint; the arguments are ignored.
#' @param sleep integer (default `0`) Seconds to sleep between API requests.
#'   Will be raised to at least `2.5` internally to stay under the Demo-tier
#'   30 req/min cap.
#' @param wait Seconds to wait before retrying after a 429 (default `60`).
#' @param finalWait Sleep 60s after the last call (mirrors
#'   [crypto_listings()]).
#'
#' @return Tibble with columns matching [crypto_listings()] where the
#'   corresponding CoinGecko field exists. See [crypto_listings()] for the
#'   column glossary; CoinGecko-specific extras (e.g. `ath`, `atl`) are
#'   appended at the end.
#'
#' @examples
#' \dontrun{
#' # Full current snapshot (all coins with a market cap)
#' latest <- cg_listings(which = "latest", quote = TRUE)
#'
#' # Top 1000 in BTC
#' latest_btc <- cg_listings(which = "latest", convert = "BTC", limit = 1000)
#' }
#'
#' @name cg_listings
#'
#' @importFrom dplyr bind_rows select mutate
#' @importFrom tibble as_tibble tibble
#' @importFrom progress progress_bar
#' @export
cg_listings <- function(which = "latest", convert = "USD", limit = 5000,
                        start_date = NULL, end_date = NULL,
                        interval = "day", quote = FALSE,
                        sort = "cmc_rank", sort_dir = "asc",
                        sleep = 0, wait = 60, finalWait = FALSE) {
  if (!identical(which, "latest")) {
    warning(sprintf(
      "cg_listings(): which='%s' is not supported on CoinGecko free-tier; ",
      which),
      "coercing to 'latest'. Snapshot this function periodically to ",
      "build a survivorship-bias-corrected archive.",
      call. = FALSE)
    which <- "latest"
  }
  if (!is.null(start_date) || !is.null(end_date)) {
    warning("`start_date`/`end_date` ignored: no historical-listings endpoint ",
            "available on the CoinGecko free-tier.", call. = FALSE)
  }

  max_retries <- getOption("crypto2.cg_max_retries", 3)
  vs_currency <- tolower(convert)
  # Force a polite floor for the documented host
  sleep_eff <- max(sleep, getOption("crypto2.cg_sleep", 2.5))

  client <- cg_make_client(sleep = sleep_eff, wait = wait,
                           max_retries = max_retries)

  per_page <- 250L
  max_pages <- if (is.null(limit)) 250L else as.integer(ceiling(limit / per_page))

  pages <- vector("list", max_pages)
  pb <- progress::progress_bar$new(
    format = ":spin [:current / :total] [:bar] :percent in :elapsedfull ETA: :eta",
    total = max_pages, clear = TRUE)

  for (i in seq_len(max_pages)) {
    pb$tick()
    pj <- cg_parse_json(client(
      cg_url("coins/markets", host = "api"),
      query = list(
        vs_currency = vs_currency,
        per_page = per_page,
        page = i,
        price_change_percentage = "1h,24h,7d,14d,30d,200d,1y"
      )
    ))
    if (is.null(pj) || (is.data.frame(pj) && nrow(pj) == 0L)) break
    pages[[i]] <- tibble::as_tibble(pj)
    if (nrow(pages[[i]]) < per_page) break
  }
  pages <- Filter(Negate(is.null), pages)

  if (!length(pages)) {
    warning("cg_listings(): no data returned (rate-limited or blocked?).",
            call. = FALSE)
    return(tibble::tibble())
  }

  raw <- dplyr::bind_rows(pages)
  if (!is.null(limit)) raw <- raw[seq_len(min(limit, nrow(raw))), , drop = FALSE]

  pick <- function(df, col, default = NA) {
    if (col %in% names(df)) df[[col]] else rep(default, nrow(df))
  }

  base <- tibble::tibble(
    id           = cg_numeric_id_from_image(pick(raw, "image", NA_character_)),
    name         = pick(raw, "name", NA_character_),
    symbol       = pick(raw, "symbol", NA_character_),
    slug         = pick(raw, "id", NA_character_),
    date_added   = as.Date(NA),
    last_updated = as.Date(as.POSIXct(pick(raw, "last_updated", NA_character_),
                                       format = "%Y-%m-%dT%H:%M:%OS",
                                       tz = "UTC")),
    rank         = as.integer(pick(raw, "market_cap_rank", NA_integer_)),
    market_cap                = as.numeric(pick(raw, "market_cap", NA_real_)),
    fully_diluted_market_cap  = as.numeric(pick(raw, "fully_diluted_valuation",
                                                NA_real_)),
    circulating_supply        = as.numeric(pick(raw, "circulating_supply", NA_real_)),
    total_supply              = as.numeric(pick(raw, "total_supply", NA_real_)),
    max_supply                = as.numeric(pick(raw, "max_supply", NA_real_))
  )

  if (quote) {
    quote_cols <- tibble::tibble(
      price                = as.numeric(pick(raw, "current_price", NA_real_)),
      volume_24h           = as.numeric(pick(raw, "total_volume", NA_real_)),
      high_24h             = as.numeric(pick(raw, "high_24h", NA_real_)),
      low_24h              = as.numeric(pick(raw, "low_24h", NA_real_)),
      percent_change_1h    = as.numeric(pick(raw,
                              "price_change_percentage_1h_in_currency", NA_real_)),
      percent_change_24h   = as.numeric(pick(raw,
                              "price_change_percentage_24h_in_currency", NA_real_)),
      percent_change_7d    = as.numeric(pick(raw,
                              "price_change_percentage_7d_in_currency", NA_real_)),
      percent_change_14d   = as.numeric(pick(raw,
                              "price_change_percentage_14d_in_currency", NA_real_)),
      percent_change_30d   = as.numeric(pick(raw,
                              "price_change_percentage_30d_in_currency", NA_real_)),
      percent_change_200d  = as.numeric(pick(raw,
                              "price_change_percentage_200d_in_currency", NA_real_)),
      percent_change_1y    = as.numeric(pick(raw,
                              "price_change_percentage_1y_in_currency", NA_real_)),
      ath                  = as.numeric(pick(raw, "ath", NA_real_)),
      ath_change_percentage= as.numeric(pick(raw, "ath_change_percentage", NA_real_)),
      ath_date             = as.Date(as.POSIXct(pick(raw, "ath_date", NA_character_),
                                                 format = "%Y-%m-%dT%H:%M:%OS",
                                                 tz = "UTC")),
      atl                  = as.numeric(pick(raw, "atl", NA_real_)),
      atl_change_percentage= as.numeric(pick(raw, "atl_change_percentage", NA_real_)),
      atl_date             = as.Date(as.POSIXct(pick(raw, "atl_date", NA_character_),
                                                 format = "%Y-%m-%dT%H:%M:%OS",
                                                 tz = "UTC")),
      ref_currency         = toupper(vs_currency)
    )
    out <- dplyr::bind_cols(base, quote_cols)
  } else {
    out <- base
  }

  if (isTRUE(finalWait)) {
    pb2 <- progress::progress_bar$new(
      format = "Final wait [:bar] :percent eta: :eta",
      total = 60, clear = FALSE, width = 60)
    for (i in 1:60) { pb2$tick(); Sys.sleep(1) }
  }

  out
}
