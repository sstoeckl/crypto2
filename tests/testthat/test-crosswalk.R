# crypto_crosswalk(): offline against a fake CSV (the arrow-free path),
# plus one live check of the published file.

fake_crosswalk_csv <- paste(
  "uid,cmc_id,cg_id,cg_numeric_id,name,symbol,match_confidence,match_basis,defillama_check,is_stablecoin,is_derived_token,is_tokenized_tradfi",
  "OCP004106,1,bitcoin,1,Bitcoin,BTC,high,links+price,agrees,False,False,False",
  "OCP000002,2,two,2,Two,TWO,medium,name_sym+price,,False,False,False",
  "OCP000003,3,three,3,Three,THR,low,slug+price,disagrees,True,False,False",
  "OCP000004,,cg-only,4,Four,FOU,cg_only,,,False,True,False",
  "OCP000005,5,,,Five,FIV,cmc_only,,,False,False,True",
  sep = "\n")

local_fake_crosswalk <- function(env = parent.frame()) {
  testthat::local_mocked_bindings(
    requireNamespace = function(package, ...) if (identical(package, "arrow")) FALSE else
      base::requireNamespace(package, ...),
    .package = "base", .env = env)
  calls <- new.env()
  calls$n <- 0L
  testthat::local_mocked_bindings(
    crosswalk_download = function(url, dest) {
      calls$n <- calls$n + 1L
      calls$url <- url
      writeLines(fake_crosswalk_csv, dest)
      TRUE
    }, .env = env)
  withr::defer(unlink(file.path(tempdir(), "crypto2_crosswalk.csv")), envir = env)
  calls
}

test_that("crypto_crosswalk() filters by minimum confidence", {
  calls <- local_fake_crosswalk()
  expect_message(hi <- crypto_crosswalk(), "Stoeckl & Pukrop \\(2026\\)")
  expect_equal(hi$cmc_id, 1L)
  expect_equal(crypto_crosswalk(min_confidence = "medium", quiet = TRUE)$cmc_id, 1:2)
  expect_equal(crypto_crosswalk(min_confidence = "low", quiet = TRUE)$cmc_id, 1:3)
  expect_error(crypto_crosswalk(min_confidence = "review"))
  expect_equal(nrow(crypto_crosswalk("low", include_unmatched = TRUE, quiet = TRUE)), 5L)
  expect_error(crypto_crosswalk(min_confidence = "very_high"))
  # downloaded once, then served from the session cache
  expect_equal(calls$n, 1L)
  expect_match(calls$url, "crosswalk/coin_crosswalk\\.csv$")
  crypto_crosswalk(refresh = TRUE, quiet = TRUE)
  expect_equal(calls$n, 2L)
})

test_that("crypto_crosswalk() returns clean types with NA for blanks", {
  local_fake_crosswalk()
  cw <- crypto_crosswalk("low", include_unmatched = TRUE, quiet = TRUE)
  expect_type(cw$cmc_id, "integer")
  expect_type(cw$cg_numeric_id, "integer")
  expect_type(cw$is_stablecoin, "logical")
  expect_equal(cw$defillama_check, c("agrees", NA, "disagrees", NA, NA))
  expect_true(is.na(cw$cmc_id[4]) && is.na(cw$cg_id[5]))
  expect_equal(cw$is_stablecoin, c(FALSE, FALSE, TRUE, FALSE, FALSE))
})

test_that("crypto_crosswalk() fails loudly when the download fails", {
  local_mocked_bindings(crosswalk_download = function(url, dest) FALSE)
  expect_error(crypto_crosswalk(refresh = TRUE), "download of the crosswalk failed")
})

test_that("crypto_crosswalk() rejects a file whose columns changed", {
  expect_error(crosswalk_clean(data.frame(uid = "x", cmc_id = 1L)),
               "lacks column\\(s\\) cg_id")
})

test_that("live: the published crosswalk maps Bitcoin and Ethereum", {
  skip_on_cran()
  expect_no_warning(
    cw <- tryCatch(crypto_crosswalk("low", include_unmatched = TRUE,
                                    refresh = TRUE, quiet = TRUE),
                   error = function(e) skip(conditionMessage(e))))
  expect_setequal(unique(cw$match_confidence),
                  c("high", "medium", "low", "cg_only", "cmc_only"))
  expect_gt(nrow(cw), 10000)
  expect_equal(anyDuplicated(cw$uid), 0L)
  btc <- cw[cw$cmc_id %in% 1L, ]
  expect_equal(btc$cg_id, "bitcoin")
  expect_equal(btc$cg_numeric_id, 1L)
  expect_equal(btc$uid, "OCP004106")
  expect_equal(cw$cg_id[cw$cmc_id %in% 1027L], "ethereum")
})
