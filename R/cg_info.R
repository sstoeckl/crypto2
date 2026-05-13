#' Retrieve per-coin metadata from CoinGecko (CMC-compatible columns)
#'
#' Companion to `crypto_info()` but for CoinGecko. Pulls descriptive metadata
#' (description, categories, logos, contract addresses across chains, links)
#' for each coin in `coin_list`. Uses the documented public API endpoint
#' `api.coingecko.com/api/v3/coins/{slug}` (no key required; ~30 req/min).
#'
#' Column names mirror `crypto_info()` where there is a direct equivalent,
#' and add a few CG-specific fields (`platforms`, `categories`).
#'
#' @param coin_list Tibble in [cg_list()] / [cg_listings()] format (must have
#'   a `slug` column). If `NULL`, calls `cg_list()`.
#' @param limit Optional cap on number of coins (top of the tibble).
#' @param sleep Seconds between calls (default `2.5` → 24 req/min,
#'   ~80% of the Demo-tier 30 req/min cap, with headroom for CoinGecko's
#'   sliding-window enforcement).
#' @param wait Seconds to wait before retrying after a 429 (default `60`,
#'   matching CoinGecko's rate-limit window). See [cg_make_client()].
#' @param max_retries Maximum retry attempts on 429 / network failures
#'   (default `3`). See [cg_make_client()].
#' @param finalWait Sleep 60s after the last call (mirrors `crypto_info()`).
#'
#' @return Tibble with one row per coin:
#'   \item{id}{CoinGecko internal numeric id (from `image$thumb`).}
#'   \item{name, symbol, slug}{Coin identifiers.}
#'   \item{category}{`"coin"` if `asset_platform_id` is `NA`, else `"token"`.}
#'   \item{description}{English description (HTML stripped to text).}
#'   \item{logo}{URL of the large coin logo.}
#'   \item{status}{Status notice from CoinGecko (`public_notice` field).}
#'   \item{notice}{Additional notices (`additional_notices` joined).}
#'   \item{date_added}{Date the coin was added to CoinGecko (`genesis_date`
#'     when set, else `NA`).}
#'   \item{date_launched}{Same as `date_added` for CG (no separate launch
#'     field exposed).}
#'   \item{categories}{List-column of coin categories.}
#'   \item{platforms}{List-column: per-chain contract addresses.}
#'   \item{web_slug}{CoinGecko canonical web slug (sometimes differs from
#'     API slug).}
#'   \item{country_origin}{Country of project origin (often empty).}
#'   \item{sentiment_votes_up_percentage, sentiment_votes_down_percentage}{
#'     Community sentiment percentages.}
#'   \item{watchlist_portfolio_users}{Number of CG users watching this coin.}
#'   \item{url}{List-column of resource URLs (homepage, whitepaper, blockchain
#'     explorers, forums, repos, chats, announcements, subreddit, twitter).}
#'
#' @examples
#' \dontrun{
#' info <- cg_info(cg_list(top_n = 50))
#' }
#'
#' @importFrom dplyr bind_rows
#' @importFrom tibble tibble
#' @importFrom progress progress_bar
#' @importFrom cli cat_bullet
#' @export
cg_info <- function(coin_list = NULL, limit = NULL,
                    sleep = 2.5, wait = 60, max_retries = 3,
                    finalWait = FALSE) {
  if (is.null(coin_list)) coin_list <- cg_list()
  if (!"slug" %in% names(coin_list)) {
    stop("`coin_list` must contain a `slug` column.", call. = FALSE)
  }
  if (!is.null(limit)) coin_list <- coin_list[seq_len(min(limit, nrow(coin_list))), ]

  client <- cg_make_client(sleep = sleep, wait = wait, max_retries = max_retries)

  fetch_one <- function(slug) {
    url <- cg_url(sprintf("coins/%s", slug), host = "api")
    raw <- cg_parse_json(client(url, query = list(
      localization     = "false",
      tickers          = "false",
      market_data      = "false",
      community_data   = "true",
      developer_data   = "false",
      sparkline        = "false"
    )))
    if (is.null(raw)) return(NULL)

    # Defensive accessors — never assume a field exists
    pick <- function(x, ..., default = NA) {
      keys <- c(...)
      for (k in keys) {
        if (is.null(x) || !is.list(x) || !(k %in% names(x))) return(default)
        x <- x[[k]]
      }
      if (is.null(x)) default else x
    }

    image_url <- pick(raw, "image", "large", default = pick(raw, "image", "small",
                                                  default = pick(raw, "image", "thumb",
                                                  default = NA_character_)))
    numeric_id <- cg_numeric_id_from_image(image_url)

    description <- pick(raw, "description", "en", default = NA_character_)
    if (!is.na(description)) {
      # strip HTML tags & decode entities for plain text
      description <- gsub("<[^>]+>", "", description)
      description <- gsub("&amp;", "&", description, fixed = TRUE)
    }

    public_notice      <- pick(raw, "public_notice",      default = NA_character_)
    additional_notices <- pick(raw, "additional_notices", default = NA_character_)
    if (is.list(additional_notices)) {
      additional_notices <- paste(unlist(additional_notices), collapse = " | ")
      if (!nzchar(additional_notices)) additional_notices <- NA_character_
    }

    asset_platform <- pick(raw, "asset_platform_id", default = NA_character_)
    category_type  <- if (is.na(asset_platform) || !nzchar(asset_platform)) "coin" else "token"

    cats <- pick(raw, "categories", default = list())
    if (!is.list(cats)) cats <- as.list(cats)

    plats <- pick(raw, "platforms", default = list())
    if (!is.list(plats)) plats <- as.list(plats)

    links <- pick(raw, "links", default = list())
    url_list <- list(
      website           = pick(links, "homepage",                default = list()),
      whitepaper        = pick(links, "whitepaper",              default = NA_character_),
      blockchain_site   = pick(links, "blockchain_site",         default = list()),
      forum             = pick(links, "official_forum_url",      default = list()),
      chat              = pick(links, "chat_url",                default = list()),
      announcement      = pick(links, "announcement_url",        default = list()),
      twitter           = pick(links, "twitter_screen_name",     default = NA_character_),
      facebook          = pick(links, "facebook_username",       default = NA_character_),
      telegram          = pick(links, "telegram_channel_identifier",
                                                                 default = NA_character_),
      subreddit         = pick(links, "subreddit_url",           default = NA_character_),
      source_code       = pick(pick(links, "repos_url", default = list()), "github",
                               default = list())
    )

    tibble::tibble(
      id     = as.integer(numeric_id),
      name   = pick(raw, "name",   default = NA_character_),
      symbol = pick(raw, "symbol", default = NA_character_),
      slug   = pick(raw, "id",     default = slug),
      web_slug                 = pick(raw, "web_slug",  default = NA_character_),
      category                 = category_type,
      description              = description,
      logo                     = image_url,
      status                   = public_notice,
      notice                   = additional_notices,
      date_added               = as.Date(pick(raw, "genesis_date", default = NA_character_)),
      date_launched            = as.Date(pick(raw, "genesis_date", default = NA_character_)),
      country_origin           = pick(raw, "country_origin",   default = NA_character_),
      sentiment_votes_up_percentage   = as.numeric(pick(raw,
                                  "sentiment_votes_up_percentage",   default = NA_real_)),
      sentiment_votes_down_percentage = as.numeric(pick(raw,
                                  "sentiment_votes_down_percentage", default = NA_real_)),
      watchlist_portfolio_users       = as.numeric(pick(raw,
                                  "watchlist_portfolio_users",       default = NA_real_)),
      categories               = list(cats),
      platforms                = list(plats),
      url                      = list(url_list)
    )
  }

  n <- nrow(coin_list)
  pb <- progress::progress_bar$new(
    format = ":spin [:current / :total] [:bar] :percent in :elapsedfull ETA: :eta",
    total = n, clear = FALSE)
  message(cli::cat_bullet("Scraping CoinGecko coin info",
                          bullet = "pointer", bullet_col = "green"))

  rows <- vector("list", n)
  for (i in seq_len(n)) {
    pb$tick()
    rows[[i]] <- tryCatch(fetch_one(coin_list$slug[i]),
                          error = function(e) NULL)
  }
  rows <- Filter(Negate(is.null), rows)

  if (!length(rows)) {
    warning("cg_info(): no data returned.", call. = FALSE)
    return(tibble::tibble())
  }

  out <- dplyr::bind_rows(rows)

  if (isTRUE(finalWait)) {
    pb2 <- progress::progress_bar$new(
      format = "Final wait [:bar] :percent eta: :eta",
      total = 60, clear = FALSE, width = 60)
    for (i in 1:60) { pb2$tick(); Sys.sleep(1) }
  }

  out
}
