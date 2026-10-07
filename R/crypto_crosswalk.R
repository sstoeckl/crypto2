#' Crosswalk between CoinMarketCap and CoinGecko coin ids
#'
#' Downloads the Open Crypto Pricing crosswalk, which links every
#' CoinMarketCap id (as used by the `crypto_*` functions) to its CoinGecko
#' coin (as used by the `cg_*` functions), including dead coins. Each pair
#' is matched on contract addresses, project links, name/symbol and slug,
#' cross-checked against DefiLlama, and confirmed on the price series of
#' both providers. The file is updated weekly.
#'
#' The file is downloaded once per session and cached in `tempdir()`.
#' Parquet is used when the `arrow` package is installed, CSV otherwise.
#'
#' @param min_confidence Lowest match confidence to keep, one of `"high"`
#'   (default), `"medium"` or `"low"`. Each level includes the ones above
#'   it, so `"low"` returns all published matches.
#' @param include_unmatched If `TRUE`, also return coins listed by only one
#'   provider (`match_confidence` `"cmc_only"` or `"cg_only"`), which have
#'   `NA` for the other provider's ids. Default `FALSE`.
#' @param refresh Download again even if the file is cached this session.
#' @param quiet Suppress the one-line source message.
#'
#' @return Tibble with one row per coin:
#'   \item{uid}{Open Crypto Pricing id, never reused (e.g. `"OCP004106"` for
#'     Bitcoin).}
#'   \item{cmc_id}{CoinMarketCap id (the `id` column of [crypto_list()]).}
#'   \item{cg_id}{CoinGecko slug (the `slug` column of [cg_list()]).}
#'   \item{cg_numeric_id}{CoinGecko numeric id (the `id` column of
#'     [cg_list()]).}
#'   \item{name, symbol}{Coin name and symbol.}
#'   \item{match_confidence}{`"high"`, `"medium"` or `"low"`, or
#'     `"cmc_only"` / `"cg_only"` for unmatched coins.}
#'   \item{match_basis}{The evidence that matched, joined by `+` (e.g.
#'     `"contract+name_sym+slug+price"`).}
#'   \item{defillama_check}{`"agrees"`, `"disagrees"`,
#'     `"suggests_pair_we_lack"` or `NA` when DefiLlama has no entry.}
#'   \item{is_stablecoin, is_derived_token, is_tokenized_tradfi}{Logical
#'     flags.}
#'
#' @source Stoeckl & Pukrop (2026), Open Crypto Pricing,
#'   <https://opencryptopricing.com>. Licensed under CC BY 4.0: cite the
#'   source when you use or redistribute the crosswalk.
#'
#' @examples
#' \dontrun{
#' cw <- crypto_crosswalk()
#'
#' # CoinGecko history for the CMC top 100, via the crosswalk
#' top <- crypto_listings(limit = 100)
#' ids <- dplyr::inner_join(top, cw, by = c("id" = "cmc_id"))
#' hist <- cg_history(dplyr::select(ids, slug = cg_id, id = cg_numeric_id))
#' }
#'
#' @importFrom tibble as_tibble
#' @export
crypto_crosswalk <- function(min_confidence = c("high", "medium", "low"),
                             include_unmatched = FALSE, refresh = FALSE,
                             quiet = FALSE) {
  min_confidence <- match.arg(min_confidence)
  levels <- c("high", "medium", "low")

  cw <- crosswalk_load(refresh = refresh, quiet = quiet)

  keep <- cw$match_confidence %in% levels[seq_len(match(min_confidence, levels))]
  if (include_unmatched) {
    keep <- keep | cw$match_confidence %in% c("cmc_only", "cg_only")
  }
  cw[keep, , drop = FALSE]
}

crosswalk_load <- function(refresh = FALSE, quiet = FALSE) {
  use_arrow <- requireNamespace("arrow", quietly = TRUE)
  ext <- if (use_arrow) "parquet" else "csv"
  cache <- file.path(tempdir(), paste0("crypto2_crosswalk.", ext))

  if (refresh || !file.exists(cache)) {
    ok <- crosswalk_download(
      cg_url(paste0("crosswalk/coin_crosswalk.", ext), host = "hf"), cache)
    if (!ok) {
      if (file.exists(cache)) unlink(cache)
      stop("crypto_crosswalk(): download of the crosswalk failed. Check your ",
           "connection and try again.", call. = FALSE)
    }
    downloaded <- TRUE
  } else {
    downloaded <- FALSE
  }

  raw <- if (use_arrow) {
    arrow::read_parquet(cache)
  } else {
    utils::read.csv(cache, stringsAsFactors = FALSE, na.strings = c("", "NA"))
  }
  cw <- crosswalk_clean(raw)

  if (downloaded && !quiet) {
    message(sprintf(paste0(
      "Crosswalk: %d matched CMC-CoinGecko pairs. Source: Stoeckl & Pukrop ",
      "(2026), Open Crypto Pricing, https://opencryptopricing.com (CC BY 4.0)"),
      sum(!is.na(cw$cmc_id) & !is.na(cw$cg_id))))
  }
  cw
}

crosswalk_download <- function(url, dest) {
  tryCatch({
    utils::download.file(url, destfile = dest, mode = "wb", quiet = TRUE)
    file.exists(dest) && file.info(dest)$size > 0
  }, error = function(e) FALSE, warning = function(w) FALSE)
}

crosswalk_clean <- function(raw) {
  need <- c("uid", "cmc_id", "cg_id", "cg_numeric_id", "name", "symbol",
            "match_confidence", "match_basis", "defillama_check",
            "is_stablecoin", "is_derived_token", "is_tokenized_tradfi")
  missing <- setdiff(need, names(raw))
  if (length(missing)) {
    stop("crypto_crosswalk(): the crosswalk file lacks column(s) ",
         paste(missing, collapse = ", "), "; its format may have changed.",
         call. = FALSE)
  }
  cw <- tibble::as_tibble(raw)[, need]
  chr <- c("uid", "cg_id", "name", "symbol", "match_confidence",
           "match_basis", "defillama_check")
  for (col in chr) {
    x <- as.character(cw[[col]])
    x[!is.na(x) & !nzchar(x)] <- NA_character_
    cw[[col]] <- x
  }
  for (col in c("cmc_id", "cg_numeric_id")) cw[[col]] <- as.integer(cw[[col]])
  for (col in c("is_stablecoin", "is_derived_token", "is_tokenized_tradfi")) {
    cw[[col]] <- as.logical(cw[[col]])
  }
  cw
}
