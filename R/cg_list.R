#' Retrieve the CoinGecko coin universe (active coins only)
#'
#' Companion to `crypto_list()` but for CoinGecko. Returns the active universe
#' as a tibble using the same column conventions as `crypto_list()`, so
#' downstream code that consumes a CMC coin list also consumes this one.
#'
#' Important caveat — survivorship bias: CoinGecko actively prunes delisted
#' and inactive coins from its public database. The free-tier API only returns
#' coins currently active on the platform. To build a survivorship-bias-free
#' dataset from CoinGecko, snapshot this list **periodically** (daily/weekly,
#' via an external cronjob or scheduling package) so coins that get delisted
#' later remain in your accumulated archive.
#'
#' Data sources (no API key required):
#' * `api.coingecko.com/api/v3/coins/list` — the full slug/symbol/name universe
#'   in a single HTTP call (free, key-less, but limited to active coins).
#' * `api.coingecko.com/api/v3/coins/markets?per_page=250&page=N` — paginated
#'   market snapshot, which provides `market_cap_rank` and the `image` URL
#'   from which the internal numeric ID is extracted.
#'
#' @param only_active Always `TRUE` for CoinGecko free-tier (kept for API
#'   parity with `crypto_list()`). The argument is ignored with a warning if
#'   set to `FALSE`.
#' @param add_untracked Same — ignored on CoinGecko free-tier. Kept for parity.
#' @param top_n If non-NULL, only enrich the top `top_n` coins by market cap
#'   with `rank` and `numeric_id` (faster). Default `NULL` = enrich all coins
#'   that appear in `/coins/markets`.
#' @param sleep Seconds between consecutive `/coins/markets` page calls
#'   (default `2.1` to stay under the documented 30 req/min cap).
#' @param vs_currency Quote currency for the market snapshot, default `"usd"`.
#'
#' @return Tibble with one row per coin currently tracked by CoinGecko.
#'   Columns mirror [crypto_list()]:
#'   \item{id}{CoinGecko internal numeric id (extracted from the image URL).
#'     May be `NA` for coins outside the top `top_n`.}
#'   \item{name}{Coin name.}
#'   \item{symbol}{Coin symbol (lower-case, non-unique).}
#'   \item{slug}{CoinGecko URL slug (unique, also the `id` in CoinGecko's
#'     documented API).}
#'   \item{rank}{Current market-cap rank, `NA` for coins outside the top
#'     `top_n` or without a market cap.}
#'   \item{is_active}{Always `1L` on CoinGecko free-tier.}
#'   \item{first_historical_data}{`NA_Date_` — not exposed by the free tier.
#'     Backfill via [cg_history()] if needed.}
#'   \item{last_historical_data}{Today's date, in line with `crypto_list()`'s
#'     convention for active coins.}
#'
#' @examples
#' \dontrun{
#' # Bootstrap: one HTTP call gets the entire universe
#' universe <- cg_list(top_n = 0)
#'
#' # Enriched: pull universe + ranks + numeric IDs for the top 500
#' top500 <- cg_list(top_n = 500)
#' }
#'
#' @importFrom tibble as_tibble tibble
#' @importFrom dplyr left_join select arrange mutate distinct
#' @export
cg_list <- function(only_active = TRUE, add_untracked = FALSE,
                    top_n = NULL, sleep = 2.1, vs_currency = "usd") {
  if (!only_active) {
    warning("CoinGecko's free tier does not expose delisted/inactive coins. ",
            "`only_active=FALSE` is ignored; consider using `cg_snapshot()` ",
            "to accumulate snapshots over time instead.", call. = FALSE)
  }
  if (add_untracked) {
    warning("`add_untracked=TRUE` is not supported on CoinGecko's free tier.",
            call. = FALSE)
  }

  client <- cg_make_client(sleep = sleep)

  # 1. Full universe (slug/symbol/name) in one call
  raw <- cg_parse_json(client(cg_url("coins/list", host = "api")))
  if (is.null(raw)) {
    stop("Failed to fetch CoinGecko universe list from /coins/list", call. = FALSE)
  }
  universe <- tibble::as_tibble(raw)
  if (!all(c("id", "symbol", "name") %in% names(universe))) {
    stop("Unexpected schema returned by /coins/list", call. = FALSE)
  }
  # Rename CG slug ("id" in their API) to our "slug" column
  universe <- universe %>%
    dplyr::rename(slug = id) %>%
    dplyr::select(slug, symbol, name)

  # 2. Enrich with rank + numeric_id from /coins/markets paginated
  per_page <- 250L
  if (is.null(top_n)) {
    # Enrich the whole universe by paging until /coins/markets is empty.
    # CG's /coins/markets only returns coins with a market cap, so we cap pages
    # at a reasonable upper bound (~250 pages = 62 500 coins).
    max_pages <- 250L
  } else if (top_n <= 0L) {
    max_pages <- 0L
  } else {
    max_pages <- as.integer(ceiling(top_n / per_page))
  }

  markets_rows <- vector("list", length = max_pages)
  for (i in seq_len(max_pages)) {
    page <- cg_parse_json(client(
      cg_url("coins/markets", host = "api"),
      query = list(vs_currency = vs_currency,
                   per_page = per_page, page = i)
    ))
    if (is.null(page) || (is.data.frame(page) && nrow(page) == 0L)) break
    markets_rows[[i]] <- tibble::as_tibble(page)
    if (nrow(markets_rows[[i]]) < per_page) break
  }
  markets_rows <- Filter(Negate(is.null), markets_rows)

  if (length(markets_rows)) {
    markets <- dplyr::bind_rows(markets_rows)
    markets <- markets %>%
      dplyr::transmute(
        slug      = id,
        id_num    = cg_numeric_id_from_image(image),
        rank      = market_cap_rank
      )
    # When numeric_id_from_image fails, leave NA
    out <- universe %>%
      dplyr::left_join(markets, by = "slug") %>%
      dplyr::rename(id = id_num)
  } else {
    out <- universe %>% dplyr::mutate(id = NA_integer_, rank = NA_integer_)
  }

  out %>%
    dplyr::mutate(
      is_active             = 1L,
      first_historical_data = as.Date(NA),
      last_historical_data  = Sys.Date()
    ) %>%
    dplyr::select(id, name, symbol, slug, rank, is_active,
                  first_historical_data, last_historical_data) %>%
    dplyr::distinct(slug, .keep_all = TRUE) %>%
    dplyr::arrange(dplyr::desc(!is.na(rank)), rank, slug)
}
