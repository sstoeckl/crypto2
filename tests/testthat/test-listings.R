# Test different listing types
test_that("Fetching different types of listings works correctly", {
  latest_data <- crypto_listings(which="latest", quote=FALSE)
  new_data <- crypto_listings(which="new", quote=TRUE, convert="BTC")
  historical_data <- crypto_listings(which="historical", quote=TRUE, start_date="20240101", end_date="20240107")

  expect_s3_class(latest_data, "tbl_df")
  expect_s3_class(new_data, "tbl_df")
  expect_s3_class(historical_data, "tbl_df")
})

# Test output structure and content
test_that("Output data structure is correct", {
  data <- crypto_listings(which="latest", quote=TRUE, convert="USD")
  required_columns <- c("id", "name", "symbol", "slug", "price", "market_cap")
  expect_true(all(required_columns %in% names(data)))
})

# Test error handling for invalid parameters
test_that("Error handling for invalid parameters", {
  expect_error(crypto_listings(which="unknown"))
})

# Consistency check against reference data
test_that("Consistency check against reference data", {
  # reference_data <- crypto_listings(which="historical", start_date="20240101", end_date="20240107", quote=TRUE)
  # saveRDS(reference_data, "tests/testthat/test_data/crypto_listings_reference.rds")
  #
  reference_data <- readRDS("test_data/crypto_listings_reference.rds")
  test_data <- crypto_listings(which="historical", start_date="20240101", end_date="20240107", quote=TRUE)

  expect_equal(test_data, reference_data)
})
