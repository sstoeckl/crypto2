# Retrieves name, CMC id, symbol, slug, rank, an activity flag as well as activity dates on CMC for all coins

This code uses the web api. It retrieves data for all historic and all
active exchanges and does not require an 'API' key.

## Usage

``` r
exchange_list(only_active = TRUE, add_untracked = FALSE)
```

## Arguments

- only_active:

  Shall the code only retrieve active exchanges (TRUE=default) or
  include inactive coins (FALSE)

- add_untracked:

  Shall the code additionally retrieve untracked exchanges
  (FALSE=default)

## Value

List of (active and historically existing) exchanges in a tibble:

- id:

  CMC exchange id (unique identifier)

- name:

  Exchange name

- slug:

  Exchange URL slug (unique)

- is_active:

  Flag showing whether exchange is active (1), inactive(0) or untracked
  (-1)

- first_historical_data:

  First time listed on CMC

- last_historical_data:

  Last time listed on CMC, *today's date* if still listed

## Examples

``` r
if (FALSE) { # \dontrun{
# return all exchanges
ex_active_list <- exchange_list(only_active=TRUE)
ex_all_but_untracked_list <- exchange_list(only_active=FALSE)
ex_full_list <- exchange_list(only_active=FALSE,add_untracked=TRUE)
} # }
```
