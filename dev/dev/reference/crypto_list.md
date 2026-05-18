# Retrieves name, CMC id, symbol, slug, rank, an activity flag as well as activity dates on CMC for all coins

This code uses the web api. It retrieves data for all historic and all
active coins and does not require an 'API' key.

## Usage

``` r
crypto_list(only_active = TRUE, add_untracked = FALSE)
```

## Arguments

- only_active:

  Shall the code only retrieve active coins (TRUE=default) or include
  inactive coins (FALSE)

- add_untracked:

  Shall the code additionally retrieve untracked coins (FALSE=default)

## Value

List of (active and historically existing) cryptocurrencies in a tibble:

- id:

  CMC id (unique identifier)

- name:

  Coin name

- symbol:

  Coin symbol (not-unique)

- slug:

  Coin URL slug (unique)

- rank:

  Current rank on CMC (if still active)

- is_active:

  Flag showing whether coin is active (1), inactive(0) or untracked (-1)

- first_historical_data:

  First time listed on CMC

- last_historical_data:

  Last time listed on CMC, *today's date* if still listed

## Examples

``` r
if (FALSE) { # \dontrun{
# return all coins
active_list <- crypto_list(only_active=TRUE)
all_but_untracked_list <- crypto_list(only_active=FALSE)
full_list <- crypto_list(only_active=FALSE,add_untracked=TRUE)

# return all coins active in 2015
coin_list_2015 <- active_list %>%
dplyr::filter(first_historical_data<="2015-12-31",
              last_historical_data>="2015-01-01")
} # }
```
