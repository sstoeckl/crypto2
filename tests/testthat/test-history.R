# Test with valid inputs and expected outputs
test_that("Valid parameters return correctly structured data", {
  skip_on_cran()
  result <- crypto_history(convert = "USD", limit = 1,
                           start_date = "2020-01-01", end_date = "2020-01-07", interval = "1d")

  # Check data structure
  expect_s3_class(result, "tbl_df")
  expect_true(all(c("id", "name", "symbol", "open", "high", "low", "close", "volume", "market_cap") %in% names(result)))

  # Check data content related to input parameters
  expect_equal(nrow(result), 7)  # Expecting 7 days of data
  expect_equal(min(as.Date(result$timestamp)), as.Date("2020-01-01"))
  expect_equal(max(as.Date(result$timestamp)), as.Date("2020-01-07"))
})

# Test handling of unsupported currencies
test_that("Unsupported currencies are rejected", {
  skip_on_cran()
  expect_error(crypto_history(convert = "EUR"),
               "convert must be one of the available currencies")
})

test_that("Downloaded data matches previously downloaded reference data", {
  skip_on_cran()
  # Load the expected output
  # saved_output <- crypto_history(
  # convert="USD",
  # limit=1,
  # start_date="2020-01-01",
  # end_date="2020-01-07",
  # interval="daily")
  # saveRDS(saved_output, "tests/testthat/test_data/crypto_history_reference.rds")
  # # Load the reference data
  expected_data <- readRDS("test_data/crypto_history_reference.rds")

  # Get new data using the same parameters
  new_data <- crypto_history(convert = "USD", limit = 1,
                             start_date = "2020-01-01", end_date = "2020-01-07", interval = "daily")

  # Compare the new data to the expected data
  expect_equal(new_data |>  select(!contains("time")), expected_data |>  select(!contains("time")), tolerance = 1e-8,
               info = "The newly downloaded data should match the reference dataset.")
})
