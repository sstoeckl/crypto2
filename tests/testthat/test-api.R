test_that("API data matches expected for crypto_global_quotes", {
  skip_on_cran()
  urls <- c(construct_url("global-metrics/quotes/historical?&convertId=1&timeStart=2020-01-01&timeEnd=2020-01-02&interval=1d",v="3"))
  #expected_dir <- paste0(getwd(),"/tests/testthat/test_data")
  expected_dir <- "test_data"

  # Optionally download and save the latest JSON for initial setup or update
  #download_and_save_json(urls, expected_dir)

  # Load expected JSON
  for (url in urls) {
    file_name <- paste0(digest::digest(url), ".json")
    file_path <- file.path(expected_dir, file_name)
cat(file_path, "\n")
    if (file.exists(file_path)) {
      cat("Found file ",file_path, "on the system!\n")
      expected_json <- jsonlite::read_json(file_path, simplifyVector = TRUE)
      current_json <- safeFromJSON(url)
        expect_equal(current_json$data, expected_json$data)
    } else {
      skip("No reference JSON available for comparison")
    }
  }
})
test_that("API data matches expected for crypto_history()", {
  skip_on_cran()
  urls <- c(construct_url("cryptocurrency/historical?id=1&convertId=2781&timeStart=1577836800&timeEnd=1578355200&interval=daily",v="3.1"),
            construct_url("cryptocurrency/historical?id=1&convertId=2781&timeStart=1577750400&timeEnd=1578005999&interval=1h",v="3.1"))
  expected_dir <- "test_data"
  # expected_dir <- paste0(getwd(),"/tests/testthat/test_data")
  # Optionally download and save the latest JSON for initial setup or update
  #download_and_save_json(urls, expected_dir)

  # Load expected JSON
  for (url in urls) {
    file_name <- paste0(digest::digest(url), ".json")
    file_path <- file.path(expected_dir, file_name)

    if (file.exists(file_path)) {
      expected_json <- jsonlite::read_json(file_path, simplifyVector = TRUE)
      current_json <- safeFromJSON(url)
        expect_equal(current_json$data, expected_json$data)
    } else {
      skip("No reference JSON available for comparison")
    }
  }
})
test_that("API data matches expected for crypto_info()", {
  skip_on_cran()
  urls <- c(construct_url("cryptocurrency/detail?id=1",v="3"))
  expected_dir <- "test_data"
  # expected_dir <- paste0(getwd(),"/tests/testthat/test_data")
  # Optionally download and save the latest JSON for initial setup or update
  #download_and_save_json(urls, expected_dir)

  # Load expected JSON
  for (url in urls) {
    file_name <- paste0(digest::digest(url), ".json")
    file_path <- file.path(expected_dir, file_name)

    if (file.exists(file_path)) {
      expected_json <- jsonlite::read_json(file_path, simplifyVector = TRUE)
      current_json <- safeFromJSON(url)

        expect_equal(current_json$data$urls, expected_json$data$urls)
        expect_equal(current_json$data$tags, expected_json$data$tags)

    } else {
      skip("No reference JSON available for comparison")
    }
  }
})

