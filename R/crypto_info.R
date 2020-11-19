#' Retrieves info (urls,logo,description,tags,platform,date_added,notice,status) on cmc for given id or slug
#'
#' This code uses the web api. It retrieves data for all historic and all active coins! It does not require an API key.
#' This function replaces the old function \code{crypto_list()} (still available as \code{crypto_list_old()}
#' which does not work anymore due to the "load more" button that I could ot figure out)
#'
#' @param slugs A vector of slugs that you want to retrieve data for
#'
#' @return List of (active and historically existing) cryptocurrencies in a tibble:
#'   \item{id}{CMC id (unique identifier)}
#'   \item{symbol}{Coin symbol (not-unique)}
#'   \item{name}{Coin name}
#'   \item{slug}{Coin URL slug (unique)}
#'   \item{category}{}
#'   \item{description}{}
#'   \item{logo}{CMC url of CC logo}
#'   \item{subreddit}{Name of subreddit community}
#'   \item{notice}{Notices}
#'   \item{date_added}{Date CC was added to the CMC database}
#'   \item{twitter_username}{Username of CCs twitter account}
#'   \item{is_hidden}{TBD}
#'   \item{date_launched}{Date CC was launched}
#'   \item{self_reported_circulating_supply}{Self reported circulating supply}
#'   \item{self reported tags}{Self_reported_tags}
#'   \item{status}{timestamp and other status messages}
#'   \item{tags}{Tibble of tags and tag categories}
#'   \item{url}{Tibble of various web adresses (website/twitter/reddit/github/tech documentation etc)}
#'   \item{Platform}{Which platform the CC uses}
#'
#' Required dependency that is used in function call \code{getCoins()}.
#' @importFrom tibble as_tibble enframe
#' @importFrom jsonlite fromJSON
#' @importFrom dplyr bind_rows mutate rename arrange
#'
#' @import progress
#' @import purrr
#' @import dplyr
#'
#' @examples
#' \dontrun{
#' # return info for bitcoin
#' coin_info <- crypto_info(slugs=c("bitcoin","tether"))
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
  rate <- purrr::rate_delay(pause=65,max_times = 2)
  #rate_backoff(pause_base = 3, pause_cap = 70, pause_min = 40, max_times = 10, jitter = TRUE)
  # Modify function to run insistently.
  insistent_scrape <- purrr::possibly(purrr::insistently(scrape_web, rate, quiet = FALSE),otherwise=NULL)
  # Progress Bar 1
  pb <- progress::progress_bar$new(format = ":spin [:current / :total] [:bar] :percent in :elapsedfull ETA: :eta",
                         total = nrow(slugs), clear = FALSE)
  message(cli::cat_bullet("Scraping crypto info", bullet = "pointer",bullet_col = "green"))
  data <- slugs %>% dplyr::mutate(out = purrr::map(slug,.f=~scrape_web(.x)))


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
      out_list$tags <- pull(tibble(tag_grous=out$data[[1]]$`tag-groups`,tags=out$data[[1]]$`tags`) %>% nest(tags=everything()))
      out_list$urls <- pull(out$data[[1]]$urls %>% unlist() %>% enframe(value = "url") %>% nest(urls=everything()))
      if(!is.null(out$data[[1]]$platform)) {out_list$platform <- pull(out$data[[1]]$platform %>% as_tibble() %>% nest(platform=everything()))} else {out_list$platform <- NA}
    }
    return(out_list)
  }
  # Progress Bar 2
  pb2 <- progress::progress_bar$new(format = ":spin [:current / :total] [:bar] :percent in :elapsedfull ETA: :eta",
                                    total = nrow(slugs), clear = FALSE)
  message(cli::cat_bullet("Processing historical crypto data", bullet = "pointer",bullet_col = "green"))
  out_all <- purrr::map(data$out, .f = ~ map_scrape(.x))

  # Old code
  results <- do.call(rbind, out_all)

  if (length(results) == 0L) stop("No data downloaded.", call. = FALSE)

  return(results)
}
