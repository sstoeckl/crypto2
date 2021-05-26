#' Retrieves info (urls,logo,description,tags,platform,date_added,notice,status) on cmc for given id or slug
#'
#' This code uses the web api. It retrieves data for all active, delisted and untracked coins! It does not require an API key.
#'
#' @param slugs A vector of slugs that you want to retrieve data for
#'
#' @return List of (active and historically existing) cryptocurrencies in a tibble:
#'   \item{id}{CMC id (unique identifier)}
#'   \item{name}{Coin name}
#'   \item{symbol}{Coin symbol (not-unique)}
#'   \item{slug}{Coin URL slug (unique)}
#'   \item{category}{Coin category: "token" or "coin"}
#'   \item{description}{Coin description according to CMC}
#'   \item{logo}{CMC url of CC logo}
#'   \item{subreddit}{Name of subreddit community}
#'   \item{notice}{Markdown formatted notices from CMC}
#'   \item{date_added}{Date CC was added to the CMC database}
#'   \item{twitter_username}{Username of CCs twitter account}
#'   \item{is_hidden}{TBD}
#'   \item{date_launched}{Date CC was launched}
#'   \item{self_reported_circulating_supply}{Self reported circulating supply}
#'   \item{self reported tags}{Self_reported_tags}
#'   \item{status}{timestamp and other status messages}
#'   \item{tags}{Tibble of tags and tag categories}
#'   \item{url}{Tibble of various ressource urls. Gives website, technical_doc (whitepaper),
#'   source_code, message_board, chat, announcement, reddit, twitter, (block) explorer ursl.}
#'   \item{Platform}{Metadata about the parent coin if available. Gives id, name, symbol,
#'   slug, and token adress according to CMC}
#'
#' @importFrom cli cat_bullet
#' @importFrom tibble as_tibble enframe
#' @importFrom jsonlite fromJSON
#' @importFrom tidyr nest
#'
#' @import progress
#' @import purrr
#' @import dplyr
#'
#' @examples
#' \dontrun{
#' # return info for bitcoin
#' coin_info <- crypto_info(slugs=c("bitcoin","tether","novacoin"))
#' }
#'
#' @name crypto_info
#'
#' @export
#'
crypto_info <- function(slugs) {
  # get current coins
  scrape_web <- function(slug){
    web_url <- paste0("https://web-api.coinmarketcap.com/v1/cryptocurrency/info?slug=")
    page <- jsonlite::fromJSON(paste0(web_url,slug))
    pb$tick()
    return(page)
  }
  if (is.vector(slugs)) slugs <- tibble::enframe(slugs,name = NULL, value = "slug")
  # define backoff rate
  rate <- purrr::rate_delay(pause=5,max_times = 2)
  #rate_backoff(pause_base = 3, pause_cap = 70, pause_min = 40, max_times = 10, jitter = TRUE)
  # Modify function to run insistently.
  insistent_scrape <- purrr::possibly(purrr::insistently(scrape_web, rate, quiet = FALSE),otherwise=NULL)
  # Progress Bar 1
  pb <- progress::progress_bar$new(format = ":spin [:current / :total] [:bar] :percent in :elapsedfull ETA: :eta",
                         total = nrow(slugs), clear = FALSE)
  message(cli::cat_bullet("Scraping crypto info", bullet = "pointer",bullet_col = "green"))
  data <- slugs %>% dplyr::mutate(out = purrr::map(slug,.f=~insistent_scrape(.x)))

  map_scrape <- function(out){
    pb2$tick()
    if (!(out$status$error_code==0)) {
      cat("\n Info for Coin",slug,"could not be downloaded. Error message: ",out$status$error_message,"!\n")
    } else if (length(out$data[[1]])==0){
      cat("\nCoin",slug,"does not have info available! Cont to next coin.\n")
    } else {
      out_list <- out$data[[1]]
      out_list[c("tags","tag-names","tag-groups","urls","contract_address","platform")] <- NULL
      out_list[sapply(out_list,is.null)] <- NA
      out_list <- out_list %>% tibble::as_tibble()
      # add
      out_list$status <- c(out$status %>% purrr::flatten() %>% as_tibble() %>% mutate(timestamp=as.POSIXlt(timestamp,format="%Y-%m-%dT%H:%M:%S")) %>% pull(timestamp))
      if(!is.null(out$data[[1]]$tags)) {out_list$tags <- pull(tibble(tags=out$data[[1]]$`tags`) %>% tidyr::nest(tags=everything()))} else {out_list$tags <- NA}
      if(!(length(flatten(out$data[[1]]$urls))==0)) {out_list$urls <- pull(out$data[[1]]$urls %>% unlist() %>% enframe(value = "url") %>% tidyr::nest(urls=everything()))} else {out_list$urls <- NA}
      if(!is.null(out$data[[1]]$platform)) {out_list$platform <- pull(out$data[[1]]$platform %>% as_tibble() %>% tidyr::nest(platform=everything()))} else {out_list$platform <- NA}
    }
    return(out_list)
  }
  # Modify function to run insistently.
  insistent_map <- purrr::possibly(map_scrape,otherwise=NULL)
  # Progress Bar 2
  pb2 <- progress::progress_bar$new(format = ":spin [:current / :total] [:bar] :percent in :elapsedfull ETA: :eta",
                                    total = nrow(slugs), clear = FALSE)
  message(cli::cat_bullet("Processing historical crypto data", bullet = "pointer",bullet_col = "green"))
  out_all <- purrr::map(data$out, .f = ~ insistent_map(.x))

  # Old code
  results <- do.call(rbind, out_all)

  if (length(results) == 0L) stop("No data downloaded.", call. = FALSE)

  return(results)
}
#' Retrieves info (urls,logo,description,tags,platform,date_added,notice,status) on cmc for given exchange slug
#'
#' This code uses the web api. It retrieves data for all active, delisted and untracked exchanges! It does not require an API key.
#'
#' @param slugs A vector of (exchange) slugs that you want to retrieve data for
#'
#' @return List of (active and historically existing) cryptocurrencies in a tibble:
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
#'   \item{spot_volume_usd}{Current volume in USD according to CMC}
#'   \item{spot_volume_last_updated}{Lates update of spot volume}
#'   \item{status}{timestamp and other status messages}
#'   \item{tags}{Tibble of tags and tag categories}
#'   \item{url}{Tibble of various ressource urls. Gives website, blog, fee, twitter.}
#'   \item{countries}{Tibble of countries the exchange is active in}
#'   \item{fiat}{Tibble of fiat currencies the exchange trades in}
#'
#' @importFrom cli cat_bullet
#' @importFrom tibble as_tibble enframe
#' @importFrom jsonlite fromJSON
#' @importFrom tidyr nest
#'
#' @import progress
#' @import purrr
#' @import dplyr
#'
#' @examples
#' \dontrun{
#' # return info for bitcoin
#' exchange_info <- exchange_info(slugs=c("binance","kraken","bter"))
#' }
#'
#' @name exchange_info
#'
#' @export
#'
exchange_info <- function(slugs) {
  # get current coins
  scrape_web <- function(slug){
    web_url <- paste0("https://web-api.coinmarketcap.com/v1/exchange/info?slug=")
    page <- jsonlite::fromJSON(paste0(web_url,slug))
    pb$tick()
    return(page)
  }
  if (is.vector(slugs)) slugs <- tibble::enframe(slugs,name = NULL, value = "slug")
  # define backoff rate
  rate <- purrr::rate_delay(pause=5,max_times = 2)
  #rate_backoff(pause_base = 3, pause_cap = 70, pause_min = 40, max_times = 10, jitter = TRUE)
  # Modify function to run insistently.
  insistent_scrape <- purrr::possibly(purrr::insistently(scrape_web, rate, quiet = FALSE),otherwise=NULL)
  # Progress Bar 1
  pb <- progress::progress_bar$new(format = ":spin [:current / :total] [:bar] :percent in :elapsedfull ETA: :eta",
                                   total = nrow(slugs), clear = FALSE)
  message(cli::cat_bullet("Scraping crypto info", bullet = "pointer",bullet_col = "green"))
  data <- slugs %>% dplyr::mutate(out = purrr::map(slug,.f=~insistent_scrape(.x)))

  map_scrape <- function(out){
    pb2$tick()
    if (!(out$status$error_code==0)) {
      cat("\n Info for exchange",slug,"could not be downloaded. Error message: ",out$status$error_message,"!\n")
    } else if (length(out$data[[1]])==0){
      cat("\nExchange",slug,"does not have info available! Cont to next exchange\n")
    } else {
      out_list <- out$data[[1]]
      out_list[c("tags","urls","countries","fiats")] <- NULL
      out_list[sapply(out_list,is.null)] <- NA
      out_list <- out_list %>% tibble::as_tibble()
      # add
      out_list$status <- c(out$status %>% purrr::flatten() %>% as_tibble() %>% mutate(timestamp=as.POSIXlt(timestamp,format="%Y-%m-%dT%H:%M:%S")) %>% pull(timestamp))
      out_list$spot_volume_last_updated <- c(out$data[[1]]$spot_volume_last_updated %>% as_tibble() %>% mutate(timestamp=as.POSIXlt(value,format="%Y-%m-%dT%H:%M:%S")) %>% pull(timestamp))
      if(!is.null(out$data[[1]]$tags)) {out_list$tags <- pull(tibble(tags=out$data[[1]]$`tags`) %>% tidyr::nest(tags=everything()))} else {out_list$tags <- NA}
      if(!(length(flatten(out$data[[1]]$urls))==0)) {out_list$urls <- pull(out$data[[1]]$urls %>% unlist() %>% enframe(value = "url") %>% tidyr::nest(urls=everything()))} else {out_list$urls <- NA}
      if(!(length(flatten(out$data[[1]]$countries))==0)) {out_list$countries <- pull(out$data[[1]]$countries %>% as_tibble() %>% tidyr::nest(countries=everything()))} else {out_list$countries <- NA}
      if(!is.null(out$data[[1]]$fiats)) {out_list$fiats <- pull(out$data[[1]]$fiats %>% as_tibble() %>% tidyr::nest(fiats=everything()))} else {out_list$fiats <- NA}
    }
    return(out_list)
  }
  # Modify function to run insistently.
  insistent_map <- purrr::possibly(map_scrape,otherwise=NULL)
  # Progress Bar 2
  pb2 <- progress::progress_bar$new(format = ":spin [:current / :total] [:bar] :percent in :elapsedfull ETA: :eta",
                                    total = nrow(slugs), clear = FALSE)
  message(cli::cat_bullet("Processing historical crypto data", bullet = "pointer",bullet_col = "green"))
  out_all <- purrr::map(data$out, .f = ~ insistent_map(.x))

  # Old code
  results <- do.call(rbind, out_all)

  if (length(results) == 0L) stop("No data downloaded.", call. = FALSE)

  return(results)
}
