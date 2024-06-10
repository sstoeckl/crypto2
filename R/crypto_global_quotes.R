#' Retrieves historical quotes for the global aggregate market
#'
#' This code retrieves global quote data (latest/historic) from coinmarketcap.com.
#'
#' @param which string Shall the code retrieve the latest listing or a historic listing?
#' @param convert string (default: USD) to one or more of available fiat or precious metals prices (`fiat_list()`). If more
#' than one are selected please separate by comma (e.g. "USD,BTC"), only necessary if 'quote=TRUE'
#' @param start_date string Start date to retrieve data from, format 'yyyymmdd'
#' @param end_date string End date to retrieve data from, format 'yyyymmdd', if not provided, today will be assumed
#' @param interval string Interval with which to sample data, default 'daily'. Must be one of `"hourly" "daily" "weekly"
#' "monthly" "yearly" "1d" "2d" "3d" "7d" "14d" "15d" "30d" "60d" "90d" "365d"`
#' @param quote logical set to TRUE if you want to include price data (FALSE=default)
#' @param sleep integer (default 60) Seconds to sleep between API requests
#' @param wait waiting time before retry in case of fail (needs to be larger than 60s in case the server blocks too many attempts, default=60)
#' @param finalWait to avoid calling the web-api again with another command before 60s are over (TRUE=default)
#'
#' @return List of latest/new/historic listings of crypto currencies in a tibble (depending on the "which"-switch and
#' whether "quote" is requested, the result may only contain some of the following variables):
#' \item{btc_dominance}{number Bitcoin's market dominance percentage by market cap.}
#' \item{eth_dominance}{number Ethereum's market dominance percentage by market cap.}
#' \item{active_cryptocurrencies}{number Count of active crypto currencies tracked by CMC
#' This includes all crypto currencies with a listing_status of "active" or "listed".}
#' \item{total_cryptocurrencies}{number Count of all crypto currencies tracked by CMC
#' This includes "inactive" listing_status crypto currencies.}
#' \item{active_market_pairs}{number Count of active market pairs tracked by CoinMarketCap across all exchanges.}#'
#' \item{active_exchanges}{number Count of active exchanges tracked by CMC This includes all
#' exchanges with a listing_status of "active" or "listed".}
#' \item{total_exchanges}{number Count of all exchanges tracked by CMC
#' This includes "inactive" listing_status exchanges.}
#' \item{last_updated}{Timestamp of when this record was last updated.}
#' \item{total_market_cap}{number The sum of all individual cryptocurrency market capitalizations in the requested currency.}
#' \item{total_volume_24h}{number The sum of rolling 24 hour adjusted volume (as outlined in our methodology) for all
#' crypto currencies in the requested currency.}
#' \item{total_volume_24h_reported}{number The sum of rolling 24 hour reported volume for all crypto currencies in the requested currency.}#'
#' \item{altcoin_volume_24h}{number The sum of rolling 24 hour adjusted volume (as outlined in our methodology) for
#' all crypto currencies excluding Bitcoin in the requested currency.}
#' \item{altcoin_volume_24h_reported}{number The sum of rolling 24 hour reported volume for
#' all crypto currencies excluding Bitcoin in the requested currency.}
#' \item{altcoin_market_cap	}{number The sum of all individual cryptocurrency market capitalizations excluding Bitcoin in the requested currency.}
#'
#' @importFrom tibble as_tibble
#' @importFrom jsonlite fromJSON
#' @importFrom dplyr bind_rows mutate rename arrange distinct
#' @importFrom tidyr unnest unnest_wider pivot_wider pivot_longer
#'
#' @examples
#' \dontrun{
#' # return new listings from the last 30 days
#' new_quotes <- crypto_global_quotes(which="latest", quote=TRUE, convert="BTC")
#' # return all global quotes in the first week of January 2014
#' quotes_2014w1 <- crypto_global_quotes(which="historical", quote=TRUE,
#'   start_date = "20140101", end_date="20140107", interval="daily")
#'
#' # report in two different currencies
#' listings_2014w1_USDBTC <- crypto_global_quotes(which="historical", quote=TRUE,
#'   start_date = "20200101", end_date="20240530", interval="daily", convert="BTC")
#' }
#'
#' @name crypto_global_quotes
#'
#' @export
#'
crypto_global_quotes <- function(which="latest", convert="USD", start_date = NULL, end_date = NULL, interval = "daily", quote=FALSE,
                                 requestLimit = 2200, finalWait = FALSE) {
  # check if convert is valid
  if (!convert %in% c("USD", "BTC")) {
    if (!convert %in% fiat_list()) {
      stop("convert must be one of the available currencies, which is BTC or available via fiat_list().")
    }
  }
  # now create convertId from convert
  convertId <- ifelse(convert=="USD",2781,1)
  # get current coins
  quotes_raw <- NULL
 if (which=="latest"){
    path <- paste0("web/global-data?convert=",convert)
    latest_raw <- safeFromJSON(construct_url(path,v="agg"))
    latest_raw1 <- latest_raw$data$metric
    latest_raw1[c("quotes","etherscanGas")] <- NULL
    global_quotes_raw <- latest_raw1 |> purrr::flatten() %>%
      tibble::as_tibble() %>% janitor::clean_names()
    global_quotes <- global_quotes_raw
    if (quote){
      lquote <- latest_raw$data$metric$quotes %>% tibble::as_tibble() %>% janitor::clean_names() %>%
        dplyr::select(-any_of(colnames(global_quotes_raw)))
      global_quotes <- global_quotes %>% bind_cols(lquote) %>% unique()
    }
  } else if (which=="historical"){
    # create dates
    if (is.null(start_date)) { start_date <- as.Date("2013-04-28") }
    if (is.null(end_date)) { end_date <- lubridate::today() }
    # convert dates
    start_date <- convert_date(start_date)
    end_date <- convert_date(end_date)
    # check dates
    if (end_date<as.Date("2013-04-29")) stop("Attention: CMC Data is only available after 2013-04-29!")
    if (start_date<as.Date("2013-04-28")) warning("CMC Data (that will be downloaded) starts after 2013-04-29!")
    # intervals
    interval <- 'daily'
    # time_period
    time_period="days"
    # create path
    dl <- seq(as.Date(start_date),as.Date(end_date),"day")
    # split time vector in chunks of requestLimit
    if (length(dl)>=requestLimit) {
      start_dates <- seq(from = as.Date(start_date), by = paste(requestLimit,time_period), length.out = length(dl) %/% requestLimit +1)
      end_dates_start <- seq(from = start_dates[2], by = paste(-1,time_period), length.out = 2)
      end_dates <- seq(from = end_dates_start[2], by = paste(requestLimit,time_period), length.out = length(dl) %/% requestLimit +1)
      if (end_dates[length(end_dates)] > end_date) {
        end_dates[length(end_dates)] <- end_date
        start_dates <- start_dates[1:length(end_dates)]
      }
      # UNIX format
      # Create UNIX timestamps for download
      UNIXstart <- format(as.numeric(as.POSIXct(as.Date(start_dates), format="%Y%m%d")),scientific = FALSE)
      UNIXend <- format(as.numeric(as.POSIXct(as.Date(end_dates), format="%Y%m%d", tz = "UTC")),scientific = FALSE)
      dates <- tibble::tibble(start_dates,end_dates,startDate=UNIXstart, endDate=UNIXend)
    } else {
      UNIXstart <- format(as.numeric(as.POSIXct(as.Date(start_date), format="%Y%m%d")),scientific = FALSE)
      UNIXend <- format(as.numeric(as.POSIXct(as.Date(end_date), format="%Y%m%d", tz = "UTC")),scientific = FALSE)
      dates <- tibble::tibble(start_dates=start_date,end_dates=end_date,startDate=UNIXstart, endDate=UNIXend)
    }
    # define scraper_function
    scrape_web <- function(historyurl){
      page <- safeFromJSON(construct_url(historyurl,v="3"))
      pb$tick()
      return(page$data)
    }
    # add history URLs
    dates <- dates %>% dplyr::mutate(historyurl=paste0(
      "global-metrics/quotes/historical?&convertId=",
      convertId,
      "&timeStart=",
      startDate,
      "&timeEnd=",
      endDate,
      "&interval=",
      ifelse(!interval=="daily",interval,"1d")
    ))
    # define backoff rate
    rate <- purrr::rate_delay(pause = wait, max_times = 2)
    rate2 <- purrr::rate_delay(sleep)
    #rate_backoff(pause_base = 3, pause_cap = 70, pause_min = 40, max_times = 10, jitter = TRUE)
    # Modify function to run insistently.
    insistent_scrape <- purrr::possibly(purrr::insistently(purrr::slowly(scrape_web, rate2), rate, quiet = FALSE),otherwise=NULL)
    # Progress Bar 1
    pb <- progress_bar$new(format = ":spin [:current / :total] [:bar] :percent in :elapsedfull ETA: :eta",
                           total = nrow(dates), clear = FALSE)
    message(cli::cat_bullet("Scraping historical global data", bullet = "pointer",bullet_col = "green"))
    data <- dates %>% dplyr::mutate(out = purrr::map(historyurl,.f=~insistent_scrape(.x)))
    data2 <- data$out
    # 2. Here comes the second part: Clean and create dataset
    map_scrape <- function(lout){
      pb2$tick()
      if (length(lout$quotes)==0){
        cat("\nCoin",lout$name,"does not have data available! Cont to next coin.\n")
      } else {
        # only one currency possible at this time
          outall <- lout$quotes |>  tibble::as_tibble() |>  dplyr::select(-quote) |>  janitor::clean_names() |>
            dplyr::mutate(timestamp=as.POSIXct(timestamp,tz="UTC"))

          if (quote) {
            quotes <- lout$quotes$quote |>  purrr::list_rbind() |> tibble::as_tibble() |>  janitor::clean_names() |>
              dplyr::mutate(timestamp=as.POSIXct(timestamp,tz="UTC"))
            outall <- outall |>  dplyr::left_join(quotes,by="timestamp")
          }
      }
      return(outall)
    }
    # Modify function to run insistently.
    insistent_map <- purrr::possibly(map_scrape,otherwise=NULL)
    # Progress Bar 2
    pb2 <- progress_bar$new(format = ":spin [:current / :total] [:bar] :percent in :elapsedfull ETA: :eta",
                            total = length(data2), clear = FALSE)
    message(cli::cat_bullet("Processing historical crypto data", bullet = "pointer",bullet_col = "green"))
    global_quotes <- purrr::map(data2,.f = ~ insistent_map(.x))
    #filter

    # results
    global_quotes <- dplyr::bind_rows(global_quotes) |>  dplyr::arrange(timestamp)
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
  return(global_quotes)
  }
}

