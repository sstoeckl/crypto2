#' Retrieves name, CG id, symbol, slug, rank, an activity flag as well as activity dates on CoinGecko for all coins
#'
#' Companion to [crypto_list()] but for CoinGecko. Returns the active universe
#' as a tibble using the same column conventions as `crypto_list()`, so
#' downstream code that consumes a CMC coin list also consumes this one.
#'
#' Because CoinGecko prunes delisted coins from its public database, the
#' free-tier API alone only returns coins currently active on the platform.
#' When `only_active = FALSE`, the function transparently merges in
#' historically-known coins via [cg_id_mapping()]; a single one-line message
#' is emitted indicating how current that mapping is.
#'
#' @param only_active Shall the code only retrieve active coins (`TRUE` =
#'   default) or include historically-known but currently-inactive coins
#'   (`FALSE`)? When `FALSE`, [cg_id_mapping()] is consulted for the extra
#'   slugs.
#' @param add_untracked Kept for API parity with [crypto_list()] -- CoinGecko
#'   does not have an "untracked" listing status, so the argument is silently
#'   ignored.
#'
#' @return List of (active and historically existing) cryptocurrencies in a
#'   tibble:
#'   \item{id}{CoinGecko internal numeric id (unique identifier).}
#'   \item{name}{Coin name.}
#'   \item{symbol}{Coin symbol (not-unique).}
#'   \item{slug}{CoinGecko URL slug (unique).}
#'   \item{rank}{Current market-cap rank on CoinGecko (`NA` for delisted or
#'     unranked coins).}
#'   \item{is_active}{Flag showing whether the coin is currently active (`1`)
#'     or only historically present (`0`).}
#'   \item{first_historical_data}{First time listed on CoinGecko (currently
#'     only populated for coins present in the historic mapping).}
#'   \item{last_historical_data}{Last time listed on CoinGecko, today's date
#'     if still active.}
#'
#' Rate-limiting and retry parameters can be overridden globally via the
#' package options `crypto2.cg_sleep`, `crypto2.cg_wait`,
#' `crypto2.cg_max_retries` (defaults: 2.5s between calls, 60s wait before
#' retry, 3 retries on rate-limit / network failure).
#'
#' @examples
#' \dontrun{
#' # all coins currently tracked by CoinGecko
#' active_list <- cg_list(only_active = TRUE)
#'
#' # active + historically-listed coins (uses cg_id_mapping())
#' full_list <- cg_list(only_active = FALSE)
#' }
#'
#' @name cg_list
#'
#' @importFrom tibble as_tibble tibble
#' @importFrom dplyr left_join select arrange mutate distinct rename bind_rows transmute desc filter anti_join
#' @export
cg_list <- function(only_active = TRUE, add_untracked = FALSE) {
  sleep       <- getOption("crypto2.cg_sleep", 2.5)
  wait        <- getOption("crypto2.cg_wait", 60)
  max_retries <- getOption("crypto2.cg_max_retries", 3)
  vs_currency <- getOption("crypto2.cg_vs_currency", "usd")

  client <- cg_make_client(sleep = sleep, wait = wait,
                           max_retries = max_retries)

  # 1. Full universe (slug/symbol/name) in one call
  raw <- cg_parse_json(client(cg_url("coins/list", host = "api")))
  if (is.null(raw)) {
    stop("Failed to fetch CoinGecko universe list", call. = FALSE)
  }
  universe <- tibble::as_tibble(raw)
  if (!all(c("id", "symbol", "name") %in% names(universe))) {
    stop("Unexpected schema returned by /coins/list", call. = FALSE)
  }
  universe <- universe %>%
    dplyr::rename(slug = id) %>%
    dplyr::select(slug, symbol, name)

  # 2. Enrich with rank + numeric_id from /coins/markets paginated
  per_page <- 250L
  top_n    <- getOption("crypto2.cg_top_n", NULL)
  max_pages <- if (is.null(top_n)) {
    250L  # ~62 500 coins; CG currently lists ~17 000
  } else if (top_n <= 0L) {
    0L
  } else {
    as.integer(ceiling(top_n / per_page))
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
    markets <- dplyr::bind_rows(markets_rows) %>%
      dplyr::transmute(
        slug      = id,
        id_num    = cg_numeric_id_from_image(image),
        rank      = market_cap_rank
      )
    active <- universe %>%
      dplyr::left_join(markets, by = "slug") %>%
      dplyr::rename(id = id_num)
  } else {
    active <- universe %>% dplyr::mutate(id = NA_integer_, rank = NA_integer_)
  }

  active <- active %>%
    dplyr::mutate(
      is_active             = 1L,
      first_historical_data = as.Date(NA),
      last_historical_data  = Sys.Date()
    ) %>%
    dplyr::select(id, name, symbol, slug, rank, is_active,
                  first_historical_data, last_historical_data)

  # 3. If requested, splice in historically-known coins via the id mapping
  if (!only_active) {
    mapping <- cg_id_mapping()
    if (nrow(mapping) > 0L) {
      historic <- mapping %>%
        dplyr::anti_join(active %>% dplyr::select(slug), by = "slug") %>%
        dplyr::transmute(
          id                    = as.integer(id),
          name                  = as.character(name),
          symbol                = as.character(symbol),
          slug                  = as.character(slug),
          rank                  = NA_integer_,
          is_active             = 0L,
          first_historical_data = as.Date(NA),
          last_historical_data  = as.Date(harvested_at)
        )
      active <- dplyr::bind_rows(active, historic)
    }
  }

  active %>%
    dplyr::distinct(slug, .keep_all = TRUE) %>%
    dplyr::arrange(dplyr::desc(!is.na(rank)), rank, slug)
}
