# Get historic crypto currency market data from CoinGecko

Companion to
[`crypto_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_history.md)
but for CoinGecko. Returns daily OHLC, volume, and market-cap timeseries
in a tibble whose column names match the crypto2 CMC output.

## Usage

``` r
cg_history(
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
  ([`cg_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_list.md)),
  or provide list of crypto currencies in the
  [`cg_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_list.md)
  /
  [`cg_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_listings.md)
  format.

- convert:

  (default: `"USD"`). Be aware that the CoinGecko free tier typically
  supports only `"USD"` and `"BTC"` reliably.

- limit:

  integer Return the top n records, default is all tokens.

- start_date, end_date:

  date Filter the returned timeseries to this date window after
  fetching.

- interval:

  string Always coerced to `"daily"` – CoinGecko website endpoints
  return daily granularity for full-history pulls. Hourly is not
  available without an API key.

- requestLimit:

  Kept for parity with
  [`crypto_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_history.md)
  – ignored (CoinGecko returns full history per coin in one call).

- sleep:

  integer (default `0`) Seconds to sleep between API requests. The
  internal client enforces a polite floor of `0.6` to keep the website
  host happy.

- wait:

  waiting time before retry in case of fail (default `60`).

- finalWait:

  Sleep 60s after the last call (mirrors
  [`crypto_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_history.md)).

- single_id:

  Kept for parity with
  [`crypto_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_history.md)
  – ignored; CoinGecko endpoints are always single-coin per call.

## Value

Crypto currency historic OHLC market data in a tibble:

- id:

  CoinGecko internal numeric id (NA if unknown).

- slug, name, symbol:

  Coin identifiers.

- timestamp:

  POSIXct (UTC), midnight of the trading day.

- ref_cur_id:

  Quote currency code (e.g. `"usd"`).

- ref_cur_name:

  Upper-cased quote currency.

- open, high, low, close:

  Daily OHLC; `close` is back-filled from the price-charts series when
  OHLC candles are unavailable.

- volume:

  Daily total volume.

- market_cap:

  Daily market cap.

- time_open, time_high, time_low, time_close:

  `NA` – CoinGecko does not expose intra-day OHLC timestamps in these
  endpoints.

## Details

Source endpoints (no API key required) are addressed internally by
[`cg_url()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_url.md);
the package source does not embed the host URLs in plain text. When the
requested coin's numeric id is missing in `coin_list`,
[`cg_id_mapping()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_id_mapping.md)
is consulted to recover it. If both the slug-based and the
numeric-id-based routes fail, the coin is silently skipped (the most
common cause is a Cloudflare bot challenge – see
[`cg_get()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_get.md)).

Free-tier caveat: the public CoinGecko Demo endpoints cap historic
retrieval at 365 days per coin. When `start_date` is more than 365 days
in the past and the website-host endpoints are unavailable (e.g. blocked
by Cloudflare), only the most recent 365 days are returned, with a
single one-line warning.

## Examples

``` r
if (FALSE) { # \dontrun{
# Top 50 by market cap, full available history
top50 <- cg_list()[1:50, ]
hist  <- cg_history(top50)

# Bitcoin only, last year
btc <- cg_history(cg_list()[1, ],
                  start_date = Sys.Date() - 365,
                  end_date   = Sys.Date())
} # }
```
