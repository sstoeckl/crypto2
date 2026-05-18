# Retrieves name, CMC id, symbol, slug, rank, an activity flag as well as activity dates on CMC for all coins

This code retrieves listing data (latest/new/historic).

## Usage

``` r
crypto_listings(
  which = "latest",
  convert = "USD",
  limit = 5000,
  start_date = NULL,
  end_date = NULL,
  interval = "day",
  quote = FALSE,
  sort = "cmc_rank",
  sort_dir = "asc",
  sleep = 0,
  wait = 60,
  finalWait = FALSE
)
```

## Arguments

- which:

  string Shall the code retrieve the latest listing, the new listings or
  a historic listing?

- convert:

  string (default: USD) to one of available fiat prices
  ([`fiat_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/fiat_list.md)).
  If more than one are selected please separate by comma (e.g.
  "USD,BTC"), only necessary if 'quote=TRUE'

- limit:

  integer Return the top n records

- start_date:

  string Start date to retrieve data from, format 'yyyymmdd'

- end_date:

  string End date to retrieve data from, format 'yyyymmdd', if not
  provided, today will be assumed

- interval:

  string Interval with which to sample data according to what
  [`seq()`](https://rdrr.io/r/base/seq.html) needs

- quote:

  logical set to TRUE if you want to include price data (FALSE=default)

- sort:

  (May 2024: currently not available) string use to sort results,
  possible values: "name", "symbol", "market_cap", "price",
  "circulating_supply", "total_supply", "max_supply",
  "num_market_pairs", "volume_24h", "volume_7d", "volume_30d",
  "percent_change_1h", "percent_change_24h", "percent_change_7d".
  Especially useful if you only want to download the top x entries using
  "limit" (deprecated for "new")

- sort_dir:

  (May 2024: currently not available) string used to specify the
  direction of the sort in "sort". Possible values are "asc" (DEFAULT)
  and "desc"

- sleep:

  integer (default 0) Seconds to sleep between API requests

- wait:

  waiting time before retry in case of fail (needs to be larger than 60s
  in case the server blocks too many attempts, default=60)

- finalWait:

  to avoid calling the web-api again with another command before 60s are
  over (TRUE=default)

## Value

List of latest/new/historic listings of cryptocurrencies in a tibble
(depending on the "which"-switch and whether "quote" is requested, the
result may only contain some of the following variables):

- id:

  CMC id (unique identifier)

- name:

  Coin name

- symbol:

  Coin symbol (not-unique)

- slug:

  Coin URL slug (unique)

- date_added:

  Date when the coin was added to the dataset

- last_updated:

  Last update of the data in the database

- rank:

  Current rank on CMC (if still active)

- market_cap:

  market cap - close x circulating supply

- market_cap_by_total_supply:

  market cap - close x total supply

- market_cap_dominance:

  market cap dominance

- fully_diluted_market_cap:

  fully diluted market cap

- self_reported_market_cap:

  is the source of the market cap self-reported

- self_reported_circulating_supply:

  is the source of the circulating supply self-reported

- tvl_ratio:

  percentage of total value locked

- price:

  latest average price

- circulating_supply:

  approx. number of coins in circulation

- total_supply:

  approx. total amount of coins in existence right now (minus any coins
  that have been verifiably burned)

- max_supply:

  CMC approx. of max amount of coins that will ever exist in the
  lifetime of the currency

- num_market_pairs:

  number of market pairs across all exchanges this coin

- tvl:

  total value locked

- volume_24h:

  Volume 24 hours

- volume_change_24h:

  Volume change in 24 hours

- percent_change_1h:

  1 hour return

- percent_change_24h:

  24 hour return

- percent_change_7d:

  7 day return

- percent_change_30d:

  30 day return

- percent_change_60d:

  60 day return

- percent_change_90d:

  90 day return

## Examples
