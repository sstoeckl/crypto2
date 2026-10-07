# Test different listing types
test_that("Fetching different types of listings works correctly", {
  skip_on_cran()
  expect_warning(latest_data <- crypto_listings(which="latest", quote=FALSE,limit=2),
                 "possibly truncated")
  expect_warning(new_data <- crypto_listings(which="new", quote=TRUE, convert="BTC",limit=2),
                 "possibly truncated")
  expect_warning(historical_data <- crypto_listings(which="historical", quote=TRUE, start_date="20240101", end_date="20240107",limit=2),
                 "7 of 7 day\\(s\\) reached limit = 2")

  expect_s3_class(latest_data, "tbl_df")
  expect_s3_class(new_data, "tbl_df")
  expect_s3_class(historical_data, "tbl_df")
})

# Since 2021-05-07 CMC lists more than 5,000 coins per day; the default
# must return all of them rather than stop at rank 5,000.
test_that("historical listings are not truncated at 5,000 by default", {
  skip_on_cran()
  expect_no_warning(
    hist <- crypto_listings(which="historical", start_date="20240107", end_date="20240107")
  )
  expect_gt(nrow(hist), 5000)
  expect_equal(anyDuplicated(hist$id), 0L)
})

# Offline: CMC ends a day with exactly 10,000 coins on an empty third page
fake_cmc_page <- function(n, offset) {
  if (!n) return(list(data = list()))
  list(data = data.frame(id = seq_len(n) + offset, name = "x", symbol = "x",
                         slug = paste0("c", seq_len(n) + offset),
                         cmcRank = seq_len(n) + offset,
                         dateAdded = "2020-01-01T00:00:00.000Z",
                         lastUpdated = "2024-07-10T23:59:00.000Z"))
}

test_that("an empty page after exactly 10,000 coins keeps the loaded pages", {
  local_mocked_bindings(safeFromJSON = function(url, ...) {
    start <- as.integer(sub(".*start=(\\d+).*", "\\1", url))
    fake_cmc_page(if (start > 10000) 0L else 5000L, start - 1L)
  })
  for (lim in list(NULL, 100000)) {
    expect_no_warning(
      out <- crypto_listings(which = "historical", start_date = "20240710",
                             end_date = "20240710", limit = lim, quote = FALSE,
                             wait = 0.01)
    )
    expect_equal(nrow(out), 10000L)
    expect_equal(anyDuplicated(out$id), 0L)
  }
})

test_that("a day that keeps failing is dropped whole and named in a warning", {
  local_mocked_bindings(safeFromJSON = function(url, ...) {
    start <- as.integer(sub(".*start=(\\d+).*", "\\1", url))
    if (grepl("date=2024-07-11", url) && start > 5000) stop("simulated failure")
    fake_cmc_page(if (start > 5000) 0L else 5000L, start - 1L)
  })
  expect_warning(
    out <- crypto_listings(which = "historical", start_date = "20240710",
                           end_date = "20240711", quote = FALSE, wait = 0.01),
    "1 of 2 day\\(s\\) failed.*MISSING.*2024-07-11")
  expect_equal(unique(out$date), as.Date("2024-07-10"))
  expect_equal(nrow(out), 5000L)
})

test_that("live: a day with exactly 10,000 coins is returned in full", {
  skip_on_cran()
  expect_no_warning(
    out <- crypto_listings(which = "historical", start_date = "20240710",
                           end_date = "20240710", limit = 100000)
  )
  expect_equal(nrow(out), 10000L)
})

# Output data structure is correct
test_that("Output data structure is correct", {
  skip_on_cran()
  data <- crypto_listings(which="latest", quote=TRUE, convert="USD")
  required_columns <- c("id", "name", "symbol", "slug", "price", "market_cap")
  expect_true(all(required_columns %in% names(data)))
})

# Test error handling for invalid parameters
test_that("Error handling for invalid parameters", {
  skip_on_cran()
  expect_error(crypto_listings(which="unknown"))
})

# Consistency check against reference data
test_that("Consistency check against reference data", {
  skip_on_cran()
  # reference_data <- crypto_listings(which="historical", start_date="20240101", end_date="20240107", quote=TRUE,limit=2)
  expected_dir <- "test_data"
  # expected_dir <- paste0(getwd(),"/tests/testthat/test_data")
  # saveRDS(reference_data, paste0(expected_dir, "/crypto_listings_reference.rds"))
  #
  reference_data <- readRDS(paste0(expected_dir, "/crypto_listings_reference.rds"))
  test_data <- suppressWarnings(
    crypto_listings(which="historical", start_date="20240101", end_date="20240107", quote=TRUE,limit=2)
  )

  expect_equal(test_data, reference_data)
})
