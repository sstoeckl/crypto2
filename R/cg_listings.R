#' Retrieves name, CG id, symbol, slug, rank, and quote data for current listings (CoinGecko)
#'
#' Companion to [crypto_listings()] but for CoinGecko. Returns one row per
#' coin with every field of the `/coins/markets` endpoint: price, volume,
#' 24h range, price and market-cap changes, all-time high/low and ROI.
#' Column names mirror those of `crypto_listings()` where a CMC counterpart
#' exists, so downstream code that already consumes a CMC listings tibble
#' works on this tibble too.
#'
#' CoinGecko free-tier limitations: only `which = "latest"` is supported.
#' `which = "historical"` and `which = "new"` produce a warning and are
#' coerced to `"latest"`, because CoinGecko's free tier does not expose the
#' historical cross-section. Snapshot this function periodically (daily /
#' weekly via a cron job) to accumulate a survivorship-bias-corrected
#' archive over time.
#'
#' **Coverage.** `/coins/markets` no longer lists wrapped, staked or bridged
#' tokens (e.g. stETH, wstETH, WBTC, JitoSOL, bridged USDT). Their history is
#' still available through [cg_history()] (the `market_chart` endpoint), but
#' they will not appear in a `cg_listings()` snapshot.
#'
#' **Rate limits and API key.** Without a key the public endpoint allows only
#' a handful of calls per minute. Set the environment variable `CG_DEMO_KEY`
#' to a (free) CoinGecko Demo-API key to raise this to 30 calls per minute
#' (10,000 per month); it is sent as the `x-cg-demo-api-key` header to the
#' documented API host only. HTTP 429 and transient 408/502/503/504 responses
#' are retried with exponential backoff (see `wait` and the
#' `crypto2.cg_max_retries` option). If a page still fails after the last
#' retry, paging stops and a warning names the failed page, so an incomplete
#' result is never returned silently.
#'
#' @param which Always `"latest"` for CoinGecko free-tier. Other values
#'   produce a warning and are coerced to `"latest"`.
#' @param convert string (default: `"USD"`). The value is lower-cased and
#'   passed to CoinGecko as `vs_currency`. Common values: `"USD"`, `"BTC"`,
#'   `"ETH"`, `"EUR"`, `"GBP"`.
#' @param limit integer Return the top n records. `NULL` (default) returns
#'   all coins.
#' @param start_date,end_date,interval Kept for API parity with
#'   [crypto_listings()] -- ignored for CoinGecko (no historical-listings
#'   endpoint on the free tier).
#' @param quote logical (default `TRUE`). The `/coins/markets` endpoint
#'   always returns prices at no extra cost, so they are included by
#'   default. Set to `FALSE` to keep only the identifier, rank, market-cap
#'   and supply columns (same default as [crypto_listings()]).
#' @param sort,sort_dir Kept for parity. CoinGecko sorts by `market_cap_desc`
#'   on the underlying endpoint; the arguments are ignored.
#' @param sleep integer (default `0`) Seconds to sleep between API requests.
#'   Will be raised to at least `getOption("crypto2.cg_sleep", 2.5)`
#'   internally to stay under the Demo-tier 30 req/min cap.
#' @param wait Seconds to wait before retrying after a 429 (default `60`).
#' @param finalWait Sleep 60s after the last call (mirrors
#'   [crypto_listings()]).
#'
#' @return Tibble with one row per coin. Always present: `id`, `name`,
#'   `symbol`, `slug`, `date_added` (always `NA`), `last_updated` (POSIXct,
#'   UTC), `rank`, `market_cap`, `fully_diluted_market_cap`,
#'   `circulating_supply`, `total_supply`, `max_supply`. With
#'   `quote = TRUE` additionally (CoinGecko field name in brackets):
#'   \item{price}{\[`current_price`\]}
#'   \item{volume_24h}{\[`total_volume`\]}
#'   \item{high_24h, low_24h}{24h price range}
#'   \item{price_change_24h}{absolute 24h price change}
#'   \item{percent_change_1h, _24h, _7d, _14d, _30d, _200d, _1y}{
#'     \[`price_change_percentage_<window>_in_currency`\]}
#'   \item{market_cap_change_24h, market_cap_change_percentage_24h}{24h
#'     market-cap change, absolute and in percent}
#'   \item{ath, ath_change_percentage, ath_date}{all-time high; date as
#'     POSIXct (UTC)}
#'   \item{atl, atl_change_percentage, atl_date}{all-time low; date as
#'     POSIXct (UTC)}
#'   \item{roi_times, roi_currency, roi_percentage}{flattened `roi` object
#'     (`NA` for most coins)}
#'   \item{ref_currency}{upper-cased `convert`}
#'
#' @examples
#' \dontrun{
#' # Full current snapshot (all coins with a market cap), including prices
#' latest <- cg_listings()
#'
#' # Top 1000 in BTC, with a Demo-API key for the higher rate limit
#' Sys.setenv(CG_DEMO_KEY = "CG-...")
#' latest_btc <- cg_listings(convert = "BTC", limit = 1000)
#' }
#'
#' @name cg_listings
#'
#' @importFrom dplyr bind_rows bind_cols
#' @importFrom tibble as_tibble tibble
#' @importFrom progress progress_bar
#' @export
cg_listings <- function(which = "latest", convert = "USD", limit = NULL,
                        start_date = NULL, end_date = NULL,
                        interval = "day", quote = TRUE,
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
  sleep_eff <- max(sleep, getOption("crypto2.cg_sleep", 2.5))

  client <- cg_make_client(sleep = sleep_eff, wait = wait,
                           max_retries = max_retries)

  per_page <- 250L
  max_pages <- if (is.null(limit)) 250L else as.integer(ceiling(limit / per_page))

  pages <- vector("list", max_pages)
  failed_page <- NA_integer_
  pb <- progress::progress_bar$new(
    format = ":spin [:current / :total] [:bar] :percent in :elapsedfull ETA: :eta",
    total = max_pages, clear = TRUE)

  for (i in seq_len(max_pages)) {
    pb$tick()
    pj <- cg_parse_json(client(
      cg_url("coins/markets", host = "api"),
      query = list(
        vs_currency = vs_currency,
        order = "market_cap_desc",
        per_page = per_page,
        page = i,
        price_change_percentage = "1h,24h,7d,14d,30d,200d,1y"
      )
    ), flatten = TRUE)
    # NULL = request failed after all retries (or unparseable body);
    # an empty JSON array = past the last page.
    if (is.null(pj)) {
      failed_page <- i
      break
    }
    if (!NROW(pj)) break
    pages[[i]] <- tibble::as_tibble(pj)
    if (nrow(pages[[i]]) < per_page) break
  }
  pages <- Filter(Negate(is.null), pages)

  if (!is.na(failed_page)) {
    warning(sprintf(paste0(
      "cg_listings(): page %d of /coins/markets failed after %d retries; ",
      "paging stopped. The result holds %d coins from pages 1-%d only and ",
      "is INCOMPLETE."),
      failed_page, max_retries,
      sum(vapply(pages, nrow, integer(1))), failed_page - 1L),
      call. = FALSE)
  }

  if (!length(pages)) {
    return(tibble::tibble())
  }

  raw <- dplyr::bind_rows(pages)
  if (!is.null(limit)) raw <- raw[seq_len(min(limit, nrow(raw))), , drop = FALSE]

  pick <- function(col, default = NA) {
    if (col %in% names(raw)) raw[[col]] else rep(default, nrow(raw))
  }
  num <- function(col) as.numeric(pick(col, NA_real_))

  out <- tibble::tibble(
    id           = cg_numeric_id_from_image(pick("image", NA_character_)),
    name         = pick("name", NA_character_),
    symbol       = pick("symbol", NA_character_),
    slug         = pick("id", NA_character_),
    date_added   = as.Date(NA),
    last_updated = cg_iso_to_posix(pick("last_updated", NA_character_)),
    rank         = as.integer(pick("market_cap_rank", NA_integer_)),
    market_cap               = num("market_cap"),
    fully_diluted_market_cap = num("fully_diluted_valuation"),
    circulating_supply       = num("circulating_supply"),
    total_supply             = num("total_supply"),
    max_supply               = num("max_supply")
  )

  if (quote) {
    out <- dplyr::bind_cols(out, tibble::tibble(
      price                 = num("current_price"),
      volume_24h            = num("total_volume"),
      high_24h              = num("high_24h"),
      low_24h               = num("low_24h"),
      price_change_24h      = num("price_change_24h"),
      percent_change_1h     = num("price_change_percentage_1h_in_currency"),
      percent_change_24h    = num("price_change_percentage_24h_in_currency"),
      percent_change_7d     = num("price_change_percentage_7d_in_currency"),
      percent_change_14d    = num("price_change_percentage_14d_in_currency"),
      percent_change_30d    = num("price_change_percentage_30d_in_currency"),
      percent_change_200d   = num("price_change_percentage_200d_in_currency"),
      percent_change_1y     = num("price_change_percentage_1y_in_currency"),
      market_cap_change_24h = num("market_cap_change_24h"),
      market_cap_change_percentage_24h = num("market_cap_change_percentage_24h"),
      ath                   = num("ath"),
      ath_change_percentage = num("ath_change_percentage"),
      ath_date              = cg_iso_to_posix(pick("ath_date", NA_character_)),
      atl                   = num("atl"),
      atl_change_percentage = num("atl_change_percentage"),
      atl_date              = cg_iso_to_posix(pick("atl_date", NA_character_)),
      roi_times             = num("roi.times"),
      roi_currency          = as.character(pick("roi.currency", NA_character_)),
      roi_percentage        = num("roi.percentage"),
      ref_currency          = toupper(vs_currency)
    ))
  }

  if (isTRUE(finalWait)) {
    pb2 <- progress::progress_bar$new(
      format = "Final wait [:bar] :percent eta: :eta",
      total = 60, clear = FALSE, width = 60)
    for (i in 1:60) { pb2$tick(); Sys.sleep(1) }
  }

  out
}
