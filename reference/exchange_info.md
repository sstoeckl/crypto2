# Retrieves info (urls,logo,description,tags,platform,date_added,notice,status) on CMC for given exchange slug

This code uses the web api. It retrieves data for all active, delisted
and untracked exchanges! It does not require an 'API' key.

## Usage

``` r
exchange_info(
  exchange_list = NULL,
  limit = NULL,
  requestLimit = 1,
  sleep = 0,
  finalWait = FALSE
)
```

## Arguments

- exchange_list:

  string if NULL retrieve all currently active exchanges
  ([`exchange_list()`](https://www.sebastianstoeckl.com/crypto2/reference/exchange_list.md)),
  or provide list of exchanges in the
  [`exchange_list()`](https://www.sebastianstoeckl.com/crypto2/reference/exchange_list.md)
  format (e.g. current and/or delisted)

- limit:

  integer Return the top n records, default is all exchanges

- requestLimit:

  limiting the length of request URLs when bundling the api calls

- sleep:

  integer (default 60) Seconds to sleep between API requests

- finalWait:

  to avoid calling the web-api again with another command before 60s are
  over (TRUE=default)

## Value

List of (active and historically existing) exchanges in a tibble:

- id:

  CMC exchange id (unique identifier)

- name:

  Exchange name

- slug:

  Exchange URL slug (unique)

- description:

  Exchange description according to CMC

- notice:

  Exchange notice (markdown formatted) according to CMC

- logo:

  CMC url of CC logo

- type:

  Type of exchange

- date_launched:

  Launch date of this exchange

- is_hidden:

  TBD

- is_redistributable:

  TBD

- maker_fee:

  Exchanges maker fee

- taker_fee:

  Exchanges maker fee

- platform_id:

  Platform id on CMC

- dex_status:

  Decentralized exchange status

- wallet_source_status:

  Wallet source status

- status:

  Activity status on CMC

- tags:

  Tibble of tags and tag categories

- urls:

  Tibble of various resource urls. Gives website, blog, fee, twitter.

- countries:

  Tibble of countries the exchange is active in

- fiats:

  Tibble of fiat currencies the exchange trades in

## Examples

``` r
if (FALSE) { # \dontrun{
# return info for the first three exchanges
exchange_info <- exchange_info(limit=10)
} # }
```
