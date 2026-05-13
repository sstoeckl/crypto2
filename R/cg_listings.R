#' Retrieve the latest CoinGecko market snapshot (CMC-compatible columns)
#'
#' Companion to `crypto_listings(which = "latest", quote = TRUE)` but for
#' CoinGecko. Returns one row per coin with current price/volume/market-cap
#' fields plus percent-change windows. Column names mirror those of
#' `crypto_listings()` so that downstream code that already consumes a CMC
#' listings tibble works on this tibble too.
#'
#' Data sources (no API key required):
#' * `api.coingecko.com/api/v3/coins/markets?vs_currency=...&per_page=250&page=N` —
#'   paginated. The `price_change_percentage` query param is set to
#'   `"1h,24h,7d,14d,30d,200d,1y"` so all CMC-equivalent return windows are
#'   present.
#'
#' CoinGecko free-tier limitations
#' * Snapshot only — `which = "historical"` is **not supported** because
#'   CoinGecko's free tier does not expose the historical cross-section of
#'   the universe. Use this function periodically (daily/weekly) and persist
#'   each snapshot yourself to accumulate a survivorship-bias-corrected
#'   archive over time.
#' * `which = "new"` is not supported (no CG equivalent endpoint).
#'
#' @param which Always `"latest"` for CoinGecko. Other values produce a
#'   warning and are coerced to `"latest"`.
#' @param convert Quote currency. Use `"USD"` (default) or `"BTC"`; the
#'   value is lower-cased and passed to CoinGecko as `vs_currency`.
#' @param limit Max number of coins to return (default `NULL` = all coins
#'   with a market cap; CoinGecko currently lists ~17 000).
#' @param quote Kept for API parity. Always treated as `TRUE` because the
#'   `/coins/markets` endpoint always returns prices.
#' @param sleep Seconds between page calls (default `2.1` → under 30 req/min).
#' @param wait,max_retries Retry parameters (see [cg_make_client()]).
#' @param ... Other args (e.g. `sort`, `sort_dir`) ignored — kept for parity
#'   with `crypto_listings()`.
#'
#' @return Tibble with columns matching `crypto_listings(quote = TRUE)` where
#'   the corresponding CoinGecko field exists. Mapping:
#'   \item{id}{CoinGecko internal numeric id (from image URL).}
#'   \item{name, symbol, slug}{Coin identifiers (slug = CG's API id).}
#'   \item{date_added}{`NA_Date_` — not available from `/coins/markets`.
#'     Pull via [cg_info()] for these.}
#'   \item{last_updated}{Date of the last update reported by CoinGecko.}
#'   \item{rank}{Market-cap rank (= CG `market_cap_rank`).}
#'   \item{market_cap, fully_diluted_market_cap}{}
#'   \item{circulating_supply, total_supply, max_supply}{}
#'   \item{price}{Current price (= CG `current_price`).}
#'   \item{volume_24h}{= CG `total_volume`.}
#'   \item{percent_change_1h, _24h, _7d, _14d, _30d, _200d, _1y}{From the
#'     `price_change_percentage` parameter.}
#'   \item{high_24h, low_24h}{Intra-day extremes.}
#'   \item{ath, ath_change_percentage, ath_date}{All-time high info.}
#'   \item{atl, atl_change_percentage, atl_date}{All-time low info.}
#'   \item{ref_currency}{Quote currency, upper-cased to match CMC output.}
#'
#' @examples
#' \dontrun{
#' # Full current snapshot of all coins with a market cap
#' snap <- cg_listings()
#'
#' # Top 1000 only, in BTC
#' snap_btc <- cg_listings(convert = "BTC", limit = 1000)
#' }
#'
#' @importFrom dplyr bind_rows transmute select mutate
#' @importFrom tibble as_tibble
#' @export
cg_listings <- function(which = "latest", convert = "USD", limit = NULL,
                        quote = TRUE, sleep = 2.1, wait = 30, max_retries = 3,
                        ...) {
  if (!identical(which, "latest")) {
    warning(sprintf(
      "cg_listings(): which='%s' not supported on CoinGecko free-tier. ",
      which),
      "Coercing to 'latest'. See ?cg_listings for the survivorship-bias note.",
      call. = FALSE
    )
    which <- "latest"
  }

  vs_currency <- tolower(convert)
  if (!vs_currency %in% c("usd", "btc", "eth", "eur", "gbp", "jpy", "chf")) {
    # CG supports ~60 vs_currencies; whitelist of common ones only for parity.
    warning(sprintf("vs_currency '%s' may not be supported by CoinGecko.",
                    vs_currency), call. = FALSE)
  }

  client <- cg_make_client(sleep = sleep, wait = wait, max_retries = max_retries)

  per_page <- 250L
  max_pages <- if (is.null(limit)) 250L else as.integer(ceiling(limit / per_page))

  pages <- vector("list", max_pages)
  for (i in seq_len(max_pages)) {
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
    warning("cg_listings(): no data returned from /coins/markets.", call. = FALSE)
    return(tibble::tibble())
  }

  raw <- dplyr::bind_rows(pages)
  if (!is.null(limit)) raw <- raw[seq_len(min(limit, nrow(raw))), , drop = FALSE]

  # Allowlist of source columns so unexpected new CG fields are silently
  # ignored — same defensive pattern recommended for crypto_info().
  pick <- function(df, col, default = NA) {
    if (col %in% names(df)) df[[col]] else rep(default, nrow(df))
  }

  out <- tibble::tibble(
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
    price                     = as.numeric(pick(raw, "current_price", NA_real_)),
    circulating_supply        = as.numeric(pick(raw, "circulating_supply", NA_real_)),
    total_supply              = as.numeric(pick(raw, "total_supply", NA_real_)),
    max_supply                = as.numeric(pick(raw, "max_supply", NA_real_)),
    volume_24h                = as.numeric(pick(raw, "total_volume", NA_real_)),
    high_24h                  = as.numeric(pick(raw, "high_24h", NA_real_)),
    low_24h                   = as.numeric(pick(raw, "low_24h", NA_real_)),
    percent_change_1h         = as.numeric(pick(raw,
                                  "price_change_percentage_1h_in_currency", NA_real_)),
    percent_change_24h        = as.numeric(pick(raw,
                                  "price_change_percentage_24h_in_currency", NA_real_)),
    percent_change_7d         = as.numeric(pick(raw,
                                  "price_change_percentage_7d_in_currency", NA_real_)),
    percent_change_14d        = as.numeric(pick(raw,
                                  "price_change_percentage_14d_in_currency", NA_real_)),
    percent_change_30d        = as.numeric(pick(raw,
                                  "price_change_percentage_30d_in_currency", NA_real_)),
    percent_change_200d       = as.numeric(pick(raw,
                                  "price_change_percentage_200d_in_currency", NA_real_)),
    percent_change_1y         = as.numeric(pick(raw,
                                  "price_change_percentage_1y_in_currency", NA_real_)),
    ath                       = as.numeric(pick(raw, "ath", NA_real_)),
    ath_change_percentage     = as.numeric(pick(raw, "ath_change_percentage", NA_real_)),
    ath_date                  = as.Date(as.POSIXct(pick(raw, "ath_date", NA_character_),
                                                   format = "%Y-%m-%dT%H:%M:%OS",
                                                   tz = "UTC")),
    atl                       = as.numeric(pick(raw, "atl", NA_real_)),
    atl_change_percentage     = as.numeric(pick(raw, "atl_change_percentage", NA_real_)),
    atl_date                  = as.Date(as.POSIXct(pick(raw, "atl_date", NA_character_),
                                                   format = "%Y-%m-%dT%H:%M:%OS",
                                                   tz = "UTC")),
    ref_currency              = toupper(vs_currency)
  )

  out
}
