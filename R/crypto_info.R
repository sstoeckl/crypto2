#' Retrieves info (urls, logo, description, tags, platform, date_added, notice, status,...) on CMC for given id
#'
#' This code retrieves data for all specified coins!
#'
#' @param coin_list string if NULL retrieve all currently active coins (`crypto_list()`),
#' or provide list of cryptocurrencies in the `crypto_list()` or `cryptoi_listings()` format (e.g. current and/or dead coins since 2015)
#' @param limit integer Return the top n records, default is all tokens
#' @param requestLimit (default: 1) limiting the length of request URLs when bundling the api calls (currently needs to be 1)
#' @param sleep integer (default: 0) Seconds to sleep between API requests
#' @param finalWait to avoid calling the web-api again with another command before 60s are over (FALSE=default)
#'
#' @return List of (active and historically existing) cryptocurrencies in a tibble:
#'   \item{id}{CMC id (unique identifier)}
#'   \item{name}{Coin name}
#'   \item{symbol}{Coin symbol (not-unique)}
#'   \item{slug}{Coin URL slug (unique)}
#'   \item{category}{Coin category: "token" or "coin"}
#'   \item{description}{Coin description according to CMC}
#'   \item{logo}{CMC url of CC logo}
#'   \item{status}{Status message from CMC}
#'   \item{notice}{Markdown formatted notices from CMC}
#'   \item{alert_type}{Type of alert on CMC}
#'   \item{alert_link}{Message link to alert}
#'   \item{date_added}{Date CC was added to the CMC database}
#'   \item{date_launched}{Date CC was launched}
#'   \item{is_audited}{Boolean if CC is audited}
#'   \item{flags}{Boolean flags for various topics}
#'   \item{self_reported_circulating_supply}{Self reported circulating supply}
#'   \item{tags}{Tibble of tags and tag categories}
#'   \item{faq_description}{FAQ description from CMC}
#'   \item{url}{Tibble of various resource urls. Gives website, technical_doc (whitepaper),
#'   source_code, message_board, chat, announcement, reddit, twitter, (block) explorer urls}
#'   \item{platform}{Metadata about the parent coin if available. Gives id, name, symbol,
#'   slug, and token address according to CMC}
#'
#' @importFrom cli cat_bullet
#' @importFrom tibble as_tibble enframe
#' @importFrom jsonlite fromJSON
#' @importFrom tidyr nest
#' @importFrom plyr laply
#' @importFrom tibble enframe
#' @importFrom lubridate ymd_hms
#'
#' @import progress
#' @import purrr
#' @import dplyr
#'
#' @examples
#' \dontrun{
#' # return info for bitcoin
#' coin_info <- crypto_info(limit=10)
#' }
#'
#' @name crypto_info
#'
#' @export
#'
crypto_info <- function(coin_list = NULL, limit = NULL, requestLimit = 1, sleep = 0, finalWait = FALSE) {
  # only if no coins are provided use crypto_list() to provide all actively traded coins
  if (is.null(coin_list)) coin_list <- crypto_list()
  # limit amount of coins downloaded
  if (!is.null(limit)) coin_list <- coin_list[1:limit, ]
  # extract slugs & ids
  slugs <- coin_list %>% dplyr::distinct(slug)
  ids <- coin_list %>% dplyr::distinct(id)
  # Create slug_vec with requestLimit elements concatenated together
  #n <- ceiling(nrow(ids)/requestLimit)
  id_vec <- ids #plyr::laply(split(ids$id, sort(ids$id%%n)),function(x) paste0(x,collapse=","))
  # get current coins
  scrape_web <- function(idv){
    path <- paste0("cryptocurrency/detail?id=")
    page <- safeFromJSON(construct_url(paste0(path,idv),v=3))
    pb$tick()
    return(page$data)
  }
  if (is.vector(id_vec)) id_vec <- tibble::enframe(id_vec,name = NULL, value = "id")
  # define backoff rate
  rate <- purrr::rate_delay(pause = 60,max_times = 2)
  rate2 <- purrr::rate_delay(sleep)
  #rate_backoff(pause_base = 3, pause_cap = 70, pause_min = 40, max_times = 10, jitter = TRUE)
  # Modify function to run insistently.
  insistent_scrape <- purrr::possibly(purrr::insistently(purrr::slowly(scrape_web, rate2), rate, quiet = FALSE),otherwise=NULL)
  # Progress Bar 1
  pb <- progress::progress_bar$new(format = ":spin [:current / :total] [:bar] :percent in :elapsedfull ETA: :eta",
                         total = nrow(id_vec), clear = FALSE)
  message(cli::cat_bullet("Scraping crypto info", bullet = "pointer",bullet_col = "green"))
  data <- id_vec %>% dplyr::mutate(out = purrr::map(id,.f=~insistent_scrape(.x)))
  data2 <- data$out
  # 2. Here comes the second part: Clean and create dataset
  map_scrape <- function(lout){
    pb2$tick()
    if (length(lout)==0){
      cat("\nThis row of the coin vector does not have info available! Cont to next row.\n")
    } else {
      out_list <- lout2 <- lout |>  janitor::clean_names()
      out_list[c("quotes","crypto_rating","analysis","earn_list","related_exchanges","holders","urls","related_coins","support_wallet_infos",
                 "wallets","faq_description","tags","statistics","platforms","volume","cex_volume","dex_volume","volume_change_percentage24h",
                 "watch_count","watch_list_rating","latest_added","launch_price","audit_infos","similar_coins")] <- NULL
      out_list[sapply(out_list,is.null)] <- NA
      out_list <- out_list %>% tibble::as_tibble()
      # add
      #out_list$status <- c(out$status %>% purrr::flatten() %>% as_tibble() %>% mutate(timestamp=as.POSIXlt(timestamp,format="%Y-%m-%dT%H:%M:%S")) %>% dplyr::pull(timestamp))
      if(!is.null(lout2$tags)) {out_list$tags <- dplyr::pull(tibble(tags=lout2$`tags`) %>% tidyr::nest(tags=everything()))} else {out_list$tags <- NA}
      if(!length(lout2$crypto_rating)==0) {out_list$crypto_rating <- dplyr::pull(tibble(crypto_rating=lout2$`crypto_rating`) %>% tidyr::nest(crypto_rating=everything()))} else {out_list$crypto_rating <- NA}
      if(!is.null(lout2$urls)) {out_list$urls <- dplyr::pull(tibble(urls=lout2$`urls`) %>% tidyr::nest(urls=everything()))} else {out_list$urls <- NA}
      if(!is.null(lout2$faq_description)) {out_list$faq_description <- dplyr::pull(tibble(faq_description=lout2$`faq_description`) %>% tidyr::nest(faq_description=everything()))} else {out_list$faq_description <- NA}
      if(!is.null(lout2$platforms)) {out_list$platform <- dplyr::pull(lout2$platforms %>% as_tibble() %>% tidyr::nest(platform=everything()))} else {out_list$platform <- NA}
      if(!is_null(lout2$date_launched)) {out_list$date_launched <- as.Date(lubridate::ymd_hms(lout2$date_launched))} else {out_list$date_launched <- NA}
      if(!is_null(lout2$date_added)) {out_list$date_added <- as.Date(lubridate::ymd_hms(lout2$date_added))} else {out_list$date_added <- NA}
      if(!is_null(lout2$latest_update_time)) {out_list$latest_update_time <- (lubridate::ymd_hms(lout2$latest_update_time))} else {out_list$latest_update_time <- NA}
      if(!is_null(lout2$self_reported_circulating_supply)) {out_list$self_reported_circulating_supply <- as.numeric(lout2$self_reported_circulating_supply)} else {out_list$self_reported_circulating_supply <- NA}
      # add link to pic
      out_list$logo <- paste0("https://s2.coinmarketcap.com/static/img/coins/64x64/",out_list$id,".png")
    }
    return(out_list)
  }
  # Modify function to run insistently.
  insistent_map <- purrr::possibly(map_scrape,otherwise=NULL)
  # Progress Bar 2
  pb2 <- progress::progress_bar$new(format = ":spin [:current / :total] [:bar] :percent in :elapsedfull ETA: :eta",
                                    total = length(data2), clear = FALSE)
  message(cli::cat_bullet("Processing crypto info", bullet = "pointer",bullet_col = "green"))
  out_all <- purrr::map(data2, .f = ~ insistent_map(.x))

  # results
  results <- do.call(bind_rows, out_all)


  if (length(results) == 0L) stop("No coin info data downloaded.", call. = FALSE)

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
  return(results)
}
#' Retrieves info (urls,logo,description,tags,platform,date_added,notice,status) on CMC for given exchange slug
#'
#' This code uses the web api. It retrieves data for all active, delisted and untracked exchanges! It does not require an 'API' key.
#'
#' @param exchange_list string if NULL retrieve all currently active exchanges (`exchange_list()`),
#' or provide list of exchanges in the `exchange_list()` format (e.g. current and/or delisted)
#' @param limit integer Return the top n records, default is all exchanges
#' @param requestLimit limiting the length of request URLs when bundling the api calls
#' @param sleep integer (default 60) Seconds to sleep between API requests
#' @param finalWait to avoid calling the web-api again with another command before 60s are over (TRUE=default)
#'
#' @return List of (active and historically existing) exchanges in a tibble:
#'   \item{id}{CMC exchange id (unique identifier)}
#'   \item{name}{Exchange name}
#'   \item{slug}{Exchange URL slug (unique)}
#'   \item{description}{Exchange description according to CMC}
#'   \item{notice}{Exchange notice (markdown formatted) according to CMC}
#'   \item{logo}{CMC url of CC logo}
#'   \item{type}{Type of exchange}
#'   \item{date_launched}{Launch date of this exchange}
#'   \item{is_hidden}{TBD}
#'   \item{is_redistributable}{TBD}
#'   \item{maker_fee}{Exchanges maker fee}
#'   \item{taker_fee}{Exchanges maker fee}
#'   \item{platform_id}{Platform id on CMC}
#'   \item{dex_status}{Decentralized exchange status}
#'   \item{wallet_source_status}{Wallet source status}
#'   \item{status}{Activity status on CMC}
#'   \item{tags}{Tibble of tags and tag categories}
#'   \item{urls}{Tibble of various resource urls. Gives website, blog, fee, twitter.}
#'   \item{countries}{Tibble of countries the exchange is active in}
#'   \item{fiats}{Tibble of fiat currencies the exchange trades in}
#'
#' @importFrom cli cat_bullet
#' @importFrom tibble as_tibble enframe
#' @importFrom jsonlite fromJSON
#' @importFrom tidyr nest
#' @importFrom plyr laply
#'
#' @import progress
#' @import purrr
#' @import dplyr
#'
#' @examples
#' \dontrun{
#' # return info for the first three exchanges
#' exchange_info <- exchange_info(limit=10)
#' }
#'
#' @name exchange_info
#'
#' @export
#'
exchange_info <- function(exchange_list = NULL, limit = NULL, requestLimit = 1, sleep = 0, finalWait = FALSE) {
  # only if no coins are provided use crypto_list() to provide all actively traded coins
  if (is.null(exchange_list)) exchange_list <- exchange_list()
  # limit amount of exchanges downloaded
  if (!is.null(limit)) exchange_list <- exchange_list[1:limit, ]
  # extract slugs
  slugs <- exchange_list %>% dplyr::distinct(slug)
  ids <- exchange_list %>% dplyr::distinct(id)
  # Create slug_vec with requestLimit elements concatenated together
  #n <- ceiling(nrow(ids)/requestLimit)
  id_vec <- slugs #plyr::laply(split(ids$id, sort(ids$id%%n)),function(x) paste0(x,collapse=","))
  # get current coins
  scrape_web <- function(idv){
    path <- paste0("exchange/detail?slug=")
    page <- safeFromJSON(construct_url(paste0(path,idv),v=3))
    pb$tick()
    return(page$data)
  }

  # define backoff rate
  rate <- purrr::rate_delay(pause = 60,max_times = 2)
  rate2 <- purrr::rate_delay(sleep)
  #rate_backoff(pause_base = 3, pause_cap = 70, pause_min = 40, max_times = 10, jitter = TRUE)
  # Modify function to run insistently.
  insistent_scrape <- purrr::possibly(purrr::insistently(purrr::slowly(scrape_web, rate2), rate, quiet = FALSE),otherwise=NULL)
  # Progress Bar 1
  pb <- progress::progress_bar$new(format = ":spin [:current / :total] [:bar] :percent in :elapsedfull ETA: :eta",
                                   total = nrow(id_vec), clear = FALSE)
  message(cli::cat_bullet("Scraping crypto info", bullet = "pointer",bullet_col = "green"))
  data <- id_vec %>% dplyr::mutate(out = purrr::map(slug,.f=~insistent_scrape(.x)))
  data2 <- data$out
  # 2. Here comes the second part: Clean and create dataset
  map_scrape <- function(lout){
    pb2$tick()
    if (length(lout)==0){
      cat("\nThis row of the exchange vector does not have info available! Cont to next row.\n")
    } else {
      out_list <- lout2 <- lout |>  janitor::clean_names()
      out_list[c("tags","quote","countries","por_switch","urls","fiats","net_worth_usd")] <- NULL
      out_list[sapply(out_list,is.null)] <- NA
      out_list <- out_list %>% tibble::as_tibble()
      # add
      #out_list$status <- c(out$status %>% purrr::flatten() %>% as_tibble() %>% mutate(timestamp=as.POSIXlt(timestamp,format="%Y-%m-%dT%H:%M:%S")) %>% dplyr::pull(timestamp))
      if(!length(lout2$tags)==0) {out_list$tags <- dplyr::pull(tibble(tags=lout2$`tags`) %>% tidyr::nest(tags=everything()))} else {out_list$tags <- NA}
      if(!length(lout2$countries)==0) {out_list$countries <- dplyr::pull(tibble(countries=lout2$`countries`) %>% tidyr::nest(countries=everything()))} else {out_list$countries <- NA}
      if(!length(lout2$fiats)==0) {out_list$fiats <- dplyr::pull(tibble(fiats=lout2$`fiats`) %>% tidyr::nest(fiats=everything()))} else {out_list$fiats <- NA}
      if(!length(lout2$urls)==0) {out_list$urls <- dplyr::pull(tibble(urls=lout2$`urls`) %>% tidyr::nest(urls=everything()))} else {out_list$urls <- NA}
      if(!is_null(lout2$date_launched)) {out_list$date_launched <- as.Date(lubridate::ymd_hms(lout2$date_launched))} else {out_list$date_launched <- NA}
    }
    return(out_list)
  }
  # Modify function to run insistently.
  insistent_map <- purrr::possibly(map_scrape,otherwise=NULL)
  # Progress Bar 2
  pb2 <- progress::progress_bar$new(format = ":spin [:current / :total] [:bar] :percent in :elapsedfull ETA: :eta",
                                    total = nrow(ids), clear = FALSE)
  message(cli::cat_bullet("Processing exchange info", bullet = "pointer",bullet_col = "green"))
  out_all <- purrr::map(data2, .f = ~ insistent_map(.x))

  # Old code
  results <- do.call(rbind, out_all)

  if (length(results) == 0L) stop("No exchange info data downloaded.", call. = FALSE)

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

  return(results)
}
