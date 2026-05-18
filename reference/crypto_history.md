# Get historic crypto currency market data

Scrape the crypto currency historic market tables from 'CoinMarketCap'
<https://coinmarketcap.com> and display the results in a
dataframe/tibble. This can be used to conduct analysis on the crypto
financial markets or to attempt to predict future market movements or
trends.

## Usage

``` r
crypto_history(
  coin_list = NULL,
  convert = "USD",
  limit = NULL,
  start_date = NULL,
  end_date = NULL,
  interval = NULL,
  requestLimit = 400,
  sleep = 0,
  wait = 60,
  finalWait = FALSE,
  single_id = TRUE
)
```

## Arguments

- coin_list:

  string if NULL retrieve all currently existing coins
  ([`crypto_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_list.md)),
  or provide list of crypto currencies in the
  [`crypto_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_list.md)
  or `cryptoi_listings()` format (e.g. current and/or dead coins since
  2015)

- convert:

  (default: USD) to one of available fiat prices
  ([`fiat_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/fiat_list.md))
  or bitcoin 'BTC'. Be aware, that since 2024 only USD and BTC are
  available here!

- limit:

  integer Return the top n records, default is all tokens

- start_date:

  date Start date to retrieve data from

- end_date:

  date End date to retrieve data from, if not provided, today will be
  assumed

- interval:

  string Interval with which to sample data according to what
  [`seq()`](https://rdrr.io/r/base/seq.html) needs

- requestLimit:

  limiting the length of request URLs when bundling the api calls

- sleep:

  integer (default 60) Seconds to sleep between API requests

- wait:

  waiting time before retry in case of fail (needs to be larger than 60s
  in case the server blocks too many attempts, default=60)

- finalWait:

  to avoid calling the web-api again with another command before 60s are
  over (TRUE=default)

- single_id:

  Download data coin by coin (as of May 2024 this is necessary)

## Value

Crypto currency historic OHLC market data in a dataframe and additional
information via attribute "info":

- timestamp:

  Timestamp of entry in database

- id:

  Coin market cap unique id

- name:

  Coin name

- symbol:

  Coin symbol

- ref_cur_id:

  reference Currency id

- ref_cur_name:

  reference Currency name

- open:

  Market open

- high:

  Market high

- low:

  Market low

- close:

  Market close

- volume:

  Volume 24 hours

- market_cap:

  Market cap - close x circulating supply

- time_open:

  Timestamp of open

- time_close:

  Timestamp of close

- time_high:

  Timestamp of high

- time_low:

  Timestamp of low

This is the main function of the crypto package. If you want to retrieve
ALL active coins then do not pass an argument to `crypto_history()`,
alternatively pass the coin name.

## Examples

``` r
if (FALSE) { # \dontrun{

# Retrieving market history for ALL crypto currencies
all_coins <- crypto_history(limit = 2)
one_coin <- crypto_history(limit = 1, convert="BTC")

# Retrieving market history since 2020 for ALL crypto currencies
all_coins <- crypto_history(start_date = '2020-01-01',limit=10)

# Retrieve 2015 history for all 2015 crypto currencies
coin_list_2015 <- crypto_list(only_active=TRUE) %>%
              dplyr::filter(first_historical_data<="2015-12-31",
              last_historical_data>="2015-01-01")
coins_2015 <- crypto_history(coin_list = coin_list_2015,
              start_date = "2015-01-01", end_date="2015-12-31", limit=20, interval="30d")
# retrieve hourly bitcoin data for 2 days
btc_hourly <- crypto_history(coin_list = coin_list_2015,
              start_date = "2015-01-01", end_date="2015-01-03", limit=1, interval="1h")

} # }
```
