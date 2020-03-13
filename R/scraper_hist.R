#' Historical table scraper
#'
#' This script scrapes historic crypto currency information from CoinMarketCap
#' and provides back a dataframe/tibble for the historic table of coins listed.
#' This function is a dependency of \code{crypto_list()} and is used
#' as part of a loop to retrieve historically listed crypto currencies.
#'
#' @param attributes URL generated from \code{listCoins()}
#' @param sleep Duration to sleep to resolve rate limiter
#'
#' @return Coin info for specific requested date in a dataframe/tibble:
#'   \item{slug}{Coin url slug}
#'   \item{symbol}{Coin symbol}
#'   \item{name}{Coin name}
#'
#' @importFrom dplyr "%>%" "mutate" "select" "filter" "as_tibble"
#' @importFrom tidyr "separate"
#' @importFrom rvest "html_nodes" "html_table"
#' @importFrom xml2 "read_html"
#' @importFrom curl "new_handle"
#'
scraper_hist <- function(attributes, sleep = NULL) {
  .            <- "."
  history_url  <- as.character(attributes)
  if (!is.null(sleep)) Sys.sleep(sleep)

  page <- tryCatch(
    xml2::read_html(history_url,
                    handle = curl::new_handle("useragent" = "Mozilla/5.0")),
    error = function(e) e)

  if (inherits(page, "error")) {
    closeAllConnections()
    message("\n")
    message(cli::cat_bullet("Rate limit hit. Sleeping for 60 seconds.", bullet = "warning", bullet_col = "red"), appendLF = TRUE)
    Sys.sleep(65)
    page <- xml2::read_html(history_url,
                            handle = curl::new_handle("useragent" = "Mozilla/5.0"))
  }

  table <- rvest::html_nodes(page, css = "table") %>% .[3] %>%
    rvest::html_table(fill = TRUE) %>%
    replace(!nzchar(.), NA)

  slug <- page %>%
    rvest::html_nodes(xpath = "//td/a") %>%
    rvest::html_attr("href") %>% tibble::enframe(name = NULL) %>% unique() %>% dplyr::filter(!grepl("#markets",value)) %>%
    tidyr::separate(value,sep="/",into=c("waste1","waste2","slug","waste3","waste4")) %>% dplyr::select(slug)


  scraper <- table[[1]][,2:3] %>% dplyr::as_tibble() %>%
    #tidyr::separate(Name,sep = "\n",into=c("symbol","name")) %>%
    dplyr::bind_cols(slug) #%>%
    #dplyr::select(-Symbol)
  return(scraper)
}
