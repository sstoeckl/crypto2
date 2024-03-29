#' Retrieves name, CMC id, symbol, slug, rank, an activity flag as well as activity dates on CMC for all coins
#'
#' This code uses the web api. It retrieves listing data (latest/new/historic) and does not require an 'API' key.
#'
#' @param which string Shall the code retrieve the latest listing, the new listings or a historic listing?
#' @param convert string (default: USD) to one or more of available fiat or precious metals prices (`fiat_list()`). If more
#' than one are selected please separate by comma (e.g. "USD,BTC"), only necessary if 'quote=TRUE'
#' @param limit integer Return the top n records, default is 5000 (max allowed by CMC)
#' @param start_date string Start date to retrieve data from, format 'yyyymmdd'
#' @param end_date string End date to retrieve data from, format 'yyyymmdd', if not provided, today will be assumed
#' @param interval string Interval with which to sample data according to what `seq()` needs
#' @param quote logical set to TRUE if you want to include price data (FALSE=default)
#' @param sort string use to sort results, possible values: "name", "symbol", "market_cap", "price",
#' "circulating_supply", "total_supply", "max_supply", "num_market_pairs", "volume_24h",
#' "volume_7d", "volume_30d", "percent_change_1h", "percent_change_24h",
#' "percent_change_7d". Especially useful if you only want to download the top x entries using "limit" (deprecated for "new")
#' @param sort_dir string used to specify the direction of the sort in "sort". Possible values are "asc" (DEFAULT) and "desc"
#' @param sleep integer (default 60) Seconds to sleep between API requests
#' @param wait waiting time before retry in case of fail (needs to be larger than 60s in case the server blocks too many attempts, default=60)
#' @param finalWait to avoid calling the web-api again with another command before 60s are over (TRUE=default)
#'
#' @return List of latest/new/historic listings of cryptocurrencies in a tibble (depending on the "which"-switch and
#' whether "quote" is requested, the result may only contain some of the following variables):
#'   \item{id}{CMC id (unique identifier)}
#'   \item{name}{Coin name}
#'   \item{symbol}{Coin symbol (not-unique)}
#'   \item{slug}{Coin URL slug (unique)}
#'   \item{date_added}{Date when the coin was added to the dataset}
#'   \item{last_updated}{Last update of the data in the database}
#'   \item{rank}{Current rank on CMC (if still active)}
#'   \item{market_cap}{market cap - close x circulating supply}
#'   \item{market_cap_by_total_supply}{market cap - close x total supply}
#'   \item{market_cap_dominance}{market cap dominance}
#'   \item{fully_diluted_market_cap}{fully diluted market cap}
#'   \item{self_reported_market_cap}{is the source of the market cap self-reported}
#'   \item{self_reported_circulating_supply}{is the source of the circulating supply self-reported}
#'   \item{tvl_ratio}{percentage of total value locked}
#'   \item{price}{latest average price}
#'   \item{circulating_supply}{approx. number of coins in circulation}
#'   \item{total_supply}{approx. total amount of coins in existence right now (minus any coins that have been verifiably burned)}
#'   \item{max_supply}{CMC approx. of max amount of coins that will ever exist in the lifetime of the currency}
#'   \item{num_market_pairs}{number of market pairs across all exchanges this coin}
#'   \item{tvl}{total value locked}
#'   \item{volume_24h}{Volume 24 hours}
#'   \item{volume_change_24h}{Volume change in 24 hours}
#'   \item{percent_change_1h}{1 hour return}
#'   \item{percent_change_24h}{24 hour return}
#'   \item{percent_change_7d}{7 day return}
#'
#' @importFrom tibble as_tibble
#' @importFrom jsonlite fromJSON
#' @importFrom dplyr bind_rows mutate rename arrange distinct
#' @importFrom tidyr unnest
#'
#' @examples
#' \dontrun{
#' # return new listings from the last 30 days
#' new_listings <- crypto_listings(which="new", quote=FALSE)
#' new_listings2 <- crypto_listings(which="new", quote=TRUE, convert="BTC,USD")
#' # return latest listing (last available data of all CC including quotes)
#' latest_listings <- crypto_listings(which="latest", quote=TRUE)
#'
#' # return all listings in the first week of January 2014
#' listings_2014w1 <- crypto_listings(which="historical", quote=TRUE,
#' start_date = "20140101", end_date="20140107", interval="day")
#'
#' # report in two different currencies
#' listings_2014w1_USDBTC <- crypto_listings(which="historical", quote=TRUE,
#' start_date = "20140101", end_date="20140107", interval="day", convert="USD,BTC")
#'
#' # only download the top 10 crypto currencies based on their market capitalization
#' listings_2015w1_mcsort <- crypto_listings(which="historical", quote=TRUE,
#' start_date = "20150101", end_date="20150107", interval="day", sort="market_cap",
#' sort_dir="desc", limit=10)
#' }
#'
#' @name crypto_listings
#'
#' @export
#'
crypto_listings <- function(which="latest", convert="USD", limit = 5000, start_date = NULL, end_date = NULL, interval = "day", quote=FALSE, sort="market_cap", sort_dir="desc", sleep = 0, wait = 60, finalWait = FALSE) {
  # get current coins
  listing_raw <- NULL
  if (which=="new"){
    for (i in 1:10){
      new_url <- paste0("https://web-api.coinmarketcap.com/v1/cryptocurrency/listings/new?limit=",limit,"&convert=",convert,"&sort_dir=",sort_dir,"&start=",(i-1)*5000+1)
      new_raw <- jsonlite::fromJSON(new_url)
      listing_raw <- bind_rows(listing_raw,
                               new_raw$data %>% tibble::as_tibble() %>% dplyr::mutate(dplyr::across(c(date_added,last_updated),as.Date)) %>%
                                 dplyr::arrange(id))
      if (nrow(new_raw$data)<5000) {break}
    }
    listing <- listing_raw %>% select(-tags,-quote,-platform) %>% unique()
    if (quote){
      lquote <- listing_raw %>% select(quote) %>% tidyr::unnest(quote) %>% tidyr::unnest(everything(), names_sep="_")
      listing <- listing_raw %>% select(-tags,-quote,-platform) %>% bind_cols(lquote) %>% unique()
    }
  } else if (which=="latest"){
    for (i in 1:10){
      latest_url <- paste0("https://web-api.coinmarketcap.com/v1/cryptocurrency/listings/latest?limit=",limit,
                        "&aux=market_cap_by_total_supply&convert=",convert,"&sort=",sort,"&sort_dir=",sort_dir,"&start=",(i-1)*5000+1)
      latest_raw <- jsonlite::fromJSON(latest_url)
      listing_raw <- bind_rows(listing_raw,
                               latest_raw$data %>% tibble::as_tibble() %>% dplyr::mutate(dplyr::across(c(last_updated),as.Date)) %>%
                                 dplyr::arrange(id))
      if (nrow(latest_raw$data)<5000) {break}
    }
    listing <- listing_raw %>% select(-quote) %>% unique()
    if (quote){
      lquote <- listing_raw %>% select(quote) %>% tidyr::unnest(quote) %>% tidyr::unnest(everything(), names_sep="_")
      listing <- listing_raw %>% select(-quote) %>% bind_cols(lquote) %>% unique()
    }
  } else if (which=="historical"){
    if (is.null(start_date)) { start_date <- "20130428" }
    sdate <- as.Date(start_date, format="%Y%m%d")
    if (is.null(end_date)) { end_date <- gsub("-", "", lubridate::today()) }
    edate <- as.Date(end_date, format="%Y%m%d")
    dates <- seq(sdate, edate, by=interval)
    tbdate <- enframe(dates[which(dates<Sys.Date())],name=NULL) %>% rename(date=value) %>%
      mutate(historyurl = paste0("https://web-api.coinmarketcap.com/v1/cryptocurrency/listings/historical?date=",dates,
                                 "&limit=",limit,"&convert=",convert,"&sort=",sort,"&sort_dir=",sort_dir,"&start="))
    # scraping tools
    scrape_web <- function(historyurl,quote){
      listing_raw <- NULL
      for (i in 1:10){
        history_url <- paste0(historyurl,(i-1)*5000+1)
        history_raw <- jsonlite::fromJSON(history_url)
        listing_raw <- bind_rows(listing_raw,
                                 history_raw$data %>% tibble::as_tibble() %>% dplyr::mutate(dplyr::across(c(date_added,last_updated),as.Date)) %>%
                                   dplyr::arrange(id))
        if (nrow(history_raw$data)<5000) {break}
      }
      listing <- listing_raw %>% select(-tags,-quote,-platform) %>% unique()
      if (quote){
        lquote <- listing_raw %>% select(quote) %>% tidyr::unnest(quote) %>% tidyr::unnest(everything(), names_sep="_")
        listing <- listing_raw %>% select(-tags,-quote,-platform) %>% bind_cols(lquote) %>% unique()
      }
      pb$tick()
      return(listing)
    }
    # define backoff rate
    rate <- purrr::rate_delay(pause = wait, max_times = 2)
    rate2 <- purrr::rate_delay(sleep)
    #rate_backoff(pause_base = 3, pause_cap = 70, pause_min = 40, max_times = 10, jitter = TRUE)
    # Modify function to run insistently.
    insistent_scrape <- purrr::possibly(purrr::insistently(purrr::slowly(scrape_web, rate2), rate, quiet = FALSE),otherwise=NULL)
    # Progress Bar 1
    pb <- progress_bar$new(format = ":spin [:current / :total] [:bar] :percent in :elapsedfull ETA: :eta",
                           total = length(dates), clear = TRUE)
    message(cli::cat_bullet("Scraping historical listings", bullet = "pointer",bullet_col = "green"))
    data <- tbdate %>% dplyr::mutate(out = purrr::map(historyurl,.f=~insistent_scrape(.x, quote)))
    # Modify massive dataframe
    listing <- data %>% select(-historyurl) %>% tidyr::unnest(out)
  }
  # wait 60s before finishing (or you might end up with the web-api 60s bug)
  if (finalWait){
    pb <- progress_bar$new(
      format = "Final wait [:bar] :percent eta: :eta",
      total = 60, clear = FALSE, width= 60)
    for (i in 1:60) {
      pb$tick()
      Sys.sleep(1)
    }
  }
  return(listing)
}
