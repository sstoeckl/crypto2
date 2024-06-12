# Test crypto_list function
test_that("crypto_list returns correctly structured data", {
  result <- crypto_list(only_active = TRUE)
  expect_s3_class(result, "tbl_df")
  expect_true(all(c("id", "name", "symbol", "slug", "is_active") %in% names(result)))
})

# Test exchange_list function
test_that("exchange_list returns correctly structured data", {
  result <- exchange_list(only_active = TRUE)
  expect_s3_class(result, "tbl_df")
  expect_true(all(c("id", "name", "slug", "is_active") %in% names(result)))
})

# Test fiat_list function
test_that("fiat_list returns correctly structured data", {
  result <- fiat_list()
  expect_s3_class(result, "tbl_df")
  expect_true(all(c("id", "symbol", "name", "sign") %in% names(result)))
})

# Test handling of different parameters
test_that("Handling of additional parameters in listing functions", {
  crypto_all <- crypto_list(only_active = FALSE, add_untracked = TRUE)
  expect_true(any(crypto_all$is_active == 1))

  exchange_all <- exchange_list(only_active = FALSE, add_untracked = TRUE)
  expect_true(any(exchange_all$is_active == 1))
})

# Test for data consistency over time
# test_that("Data consistency over time for listings", {
#   skip_on_cran()
#   # Run these at a time when the data is verified to be correct
#   # reference_crypto_data <- crypto_list(only_active = TRUE)
#   # saveRDS(reference_crypto_data, "tests/testthat/test_data/crypto_list_reference.rds")
#   #
#   # reference_exchange_data <- exchange_list(only_active = TRUE)
#   # saveRDS(reference_exchange_data, "tests/testthat/test_data/exchange_list_reference.rds")
#   # Assuming you've saved reference data from a previous known good state
#   expected_crypto_data <- readRDS("test_data/crypto_list_reference.rds")
#   new_crypto_data <- crypto_list(only_active = TRUE)
#
#   expected_exchange_data <- readRDS("test_data/exchange_list_reference.rds")
#   new_exchange_data <- exchange_list(only_active = TRUE)
#
#   # Compare the new data to the expected data
#   expect_equal(new_crypto_data, expected_crypto_data, tolerance = 1e-8,
#                info = "The newly downloaded crypto data should match the reference dataset.")
#   expect_equal(new_exchange_data, expected_exchange_data, tolerance = 1e-8,
#                info = "The newly downloaded exchange data should match the reference dataset.")
# })
