#' Retrieves name, CMC id, symbol, slug, rank, an activity flag as well as activity dates on CMC for all coins
#'
#' This code retrieves listing data (latest/new/historic).
#'
#' @param which string Shall the code retrieve the latest listing, the new listings or a historic listing?
#' @param convert string (default: USD) to one of available fiat prices (`fiat_list()`). If more
#' than one are selected please separate by comma (e.g. "USD,BTC"), only necessary if 'quote=TRUE'
#' @param limit integer Return the top n records
#' @param start_date string Start date to retrieve data from, format 'yyyymmdd'
#' @param end_date string End date to retrieve data from, format 'yyyymmdd', if not provided, today will be assumed
#' @param interval string Interval with which to sample data according to what `seq()` needs
#' @param quote logical set to TRUE if you want to include price data (FALSE=default)
#' @param sort (May 2024: currently not available) string use to sort results, possible values: "name", "symbol", "market_cap", "price",
#' "circulating_supply", "total_supply", "max_supply", "num_market_pairs", "volume_24h",
#' "volume_7d", "volume_30d", "percent_change_1h", "percent_change_24h",
#' "percent_change_7d". Especially useful if you only want to download the top x entries using "limit" (deprecated for "new")
#' @param sort_dir (May 2024: currently not available) string used to specify the direction of the sort in "sort". Possible values are "asc" (DEFAULT) and "desc"
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
#'   \item{percent_change_30d}{30 day return}
#'   \item{percent_change_60d}{60 day return}
#'   \item{percent_change_90d}{90 day return}
#'
#' @importFrom tibble as_tibble enframe
#' @importFrom dplyr bind_rows mutate rename arrange distinct left_join select bind_cols join_by
#' @importFrom tidyr unnest
#' @importFrom janitor clean_names
#'
#' @examples
#' \dontrun{
#' # return new listings from the last 30 days
#' new_listings <- crypto_listings(which="new", quote=FALSE, limit=50000)
#' new_listings2 <- crypto_listings(which="new", quote=TRUE, convert="BTC")
#'
#' # return latest listing (last available data of all CC including quotes)
#' latest_listings <- crypto_listings(which="latest", quote=FALSE, limit=50000)
#' latest_listings2 <- crypto_listings(which="latest", quote=TRUE, convert="BTC")
#'
#' # return the first 10 listings in the first week of January 2024
#' listings_2024w1 <- crypto_listings(which="historical", quote=TRUE,
#' start_date = "20240101", end_date="20240102", interval="day", limit=10)
#'
#' # only download the top 10 crypto currencies based on their market capitalization
#' # DOES NOT WORK ANY MORE
#'
#' # for historically accurate snapshots (e.g. for backtesting crypto investments)
#' # you need to download the entire history on one day including price information:
#' listings_20200202 <- crypto_listings(which="historical", quote=TRUE, start_date="20200202", end_date="20200202")
#' listings_20240202 <- crypto_listings(which="historical", quote=TRUE, start_date="20240202", end_date="20240202", limit=50000)
#' # note the much larger amount in CCs in 2024, as well as the existence of many more variables in the dataset
#' }
#'
#' @name crypto_listings
#'
#' @export
#'
crypto_listings <- function(which="latest", convert="USD", limit = 5000, start_date = NULL, end_date = NULL,
                            interval = "day", quote=FALSE, sort="cmc_rank", sort_dir="asc", sleep = 0, wait = 60, finalWait = FALSE) {
  # now create convertId from convert
  convertId <- ifelse(convert=="USD",2781,1)
  # get current coins
  if (which=="new"){
    listing_raw <- NULL
    limitdl <- 500
    limitend <- ifelse(limit%%limitdl==0,limit%/%limitdl,limit%/%limitdl+1)
    for (i in 1:limitend){
      new_url <- paste0("cryptocurrency/spotlight?dataType=8&limit=",limitdl,"&convertId=",convertId,"&sort_dir=",sort_dir,"&start=",(i-1)*limitdl+1)
      new_raw <- safeFromJSON(construct_url(new_url,v=3))
      listing_raw <- bind_rows(listing_raw,
                               new_raw$data$recentlyAddedList %>% tibble::as_tibble() |> janitor::clean_names() %>%
                                 dplyr::rename(date_added=added_date) |>
                                 dplyr::select(-platforms) |>
                                 dplyr::mutate(dplyr::across(c(date_added),as.Date)) %>%
                                 dplyr::arrange(id))
      if (nrow(new_raw$data$recentlyAddedList)<limitdl) {break}
    }
    listing <- listing_raw %>% dplyr::select(-price_change) %>% unique()
    if (quote){
      lquote <- listing_raw %>% dplyr::select(price_change) %>% tidyr::unnest(price_change) %>% tidyr::unnest(everything(), names_sep="_") |> janitor::clean_names() |>
                dplyr::mutate(dplyr::across(c(last_update),as.Date))
      listing <- listing_raw %>% dplyr::select(-price_change) %>% dplyr::bind_cols(lquote) %>% unique()
    }
  } else if (which=="latest"){
    listing_raw <- NULL
    limitdl <- 5000
    limitend <- ifelse(limit%%limitdl==0,limit%/%limitdl,limit%/%limitdl+1)
    for (i in 1:limitend){
      latest_url <- paste0("cryptocurrency/listing?limit=",limitdl,
                        "&convertId=",
                        convertId,"&sort=",sort,"&sort_dir=",sort_dir,"&start=",(i-1)*limitdl+1)
      latest_raw <- safeFromJSON(construct_url(latest_url,v=3))
      listing_raw <- bind_rows(listing_raw,
                               latest_raw$data$cryptoCurrencyList %>% tibble::as_tibble() |> janitor::clean_names() %>%
                                 dplyr::mutate(dplyr::across(c(last_updated),as.Date)) %>%
                                 dplyr::select(-any_of(c("badges","audit_info_list","is_audited","platform"))) |>
                                 dplyr::arrange(id))
      if (nrow(latest_raw$data$cryptoCurrencyList)<limitdl) {break}
    }
    listing <- listing_raw %>% dplyr::select(-quotes,-tags) %>% unique()
    if (quote){
      lquote <- listing_raw %>% dplyr::select(quotes) %>% tidyr::unnest(quotes) %>% tidyr::unnest(everything(), names_sep="_") |> janitor::clean_names() |>
                dplyr::mutate(dplyr::across(c(last_updated),as.Date))
      listing <- listing_raw %>% dplyr::select(-any_of(c("quotes","tags"))) %>%
        dplyr::bind_cols(lquote |> dplyr::select(ref_currency=name,everything(),-last_updated)) %>% unique()
    }
  } else if (which=="historical"){
    if (is.null(start_date)) { start_date <- "20130428" }
    sdate <- as.Date(start_date, format="%Y%m%d")
    if (is.null(end_date)) { end_date <- gsub("-", "", lubridate::today()) }
    edate <- as.Date(end_date, format="%Y%m%d")
    dates <- seq(sdate, edate, by=interval)
    tbdate <- tibble::enframe(dates[which(dates<Sys.Date())],name=NULL) %>% rename(date=value) %>%
      mutate(historyurl = paste0("cryptocurrency/listings/historical?date=",date,
                                 "&limit=",limit,"&convertId=",convertId,"&sort=",sort,"&sort_dir=",sort_dir,"&start="))
    # scraping tools
    scrape_web <- function(historyurl,quote){
      listing_raw <- NULL
      limitdl <- 5000
      limitend <- ifelse(limit%%limitdl==0,limit%/%limitdl,limit%/%limitdl+1)
      for (i in 1:limitend){
        history_url <- paste0(historyurl,(i-1)*limitdl+1)
        history_raw <- safeFromJSON(construct_url(history_url,v=3))
        listing_raw <- bind_rows(listing_raw,
                                 history_raw$data %>% tibble::as_tibble() |> janitor::clean_names() %>%
                                   dplyr::mutate(dplyr::across(c(date_added,last_updated),as.Date)) %>%
                                   dplyr::arrange(id))
        if (nrow(history_raw$data)<limitdl) {break}
      }
      listing <- listing_raw %>% dplyr::select(-any_of(c("tags","quotes","platform"))) %>% unique()
      if (quote){
        lquote <- listing_raw %>% dplyr::select(quotes) %>% tidyr::unnest(quotes) %>% tidyr::unnest(everything(), names_sep="_") |> janitor::clean_names()
        listing <- listing_raw %>% dplyr::select(-any_of(c("tags","quotes","platform"))) %>%
          dplyr::bind_cols(lquote |>  dplyr::select(-any_of(c("name","last_updated")))) %>% unique()
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
