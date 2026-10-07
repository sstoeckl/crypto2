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
  single_id = TRUE,
  date_convention = c("end_of_day", "raw")
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

  (default: `"USD"`). Any CoinGecko quote currency, e.g. `"BTC"`,
  `"ETH"` or `"EUR"`.

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
  internal client enforces a polite floor to stay within CoinGecko's
  per-minute budget.

- wait:

  waiting time before retry in case of fail (default `60`).

- finalWait:

  Sleep 60s after the last call (mirrors
  [`crypto_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_history.md)).

- single_id:

  Kept for parity with
  [`crypto_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_history.md)
  – ignored; CoinGecko endpoints are always single-coin per call.

- date_convention:

  Either `"end_of_day"` (the default) or `"raw"`. CoinGecko's native
  daily series timestamps each point at 00:00:00 UTC of date X, which is
  the same physical instant as 23:59:59 UTC of date X-1 – i.e. CG labels
  it as the start-of-day rather than the close-of-day. CMC (and
  [`crypto_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_history.md))
  label that instant as date X-1 (the day that just ended), which is
  also the standard asset-pricing convention used by CRSP/Compustat and
  major academic datasets. With `"end_of_day"` (default) `cg_history()`
  shifts CG's midnight ticks by -1 day so `close[X] / close[X-1] - 1` is
  the return earned during date X, matching CMC. Pass `"raw"` to keep
  CG's native start-of-day labelling.

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

- open, high, low:

  Daily OHLC from 4-hour candles (last 30 days).

- close:

  Daily close from the price series; back-filled from the OHLC candles
  where the price series has no value.

- volume:

  Daily total volume.

- market_cap:

  Daily market cap.

- time_open, time_high, time_low, time_close:

  `NA` – CoinGecko does not expose intra-day OHLC timestamps in these
  endpoints.

## Details

No API key is required. When the requested coin's numeric id is missing
in `coin_list`,
[`cg_id_mapping()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_id_mapping.md)
is consulted to fill the `id` column.

All data come from CoinGecko's website chart endpoints; no API and no
key are used. Coverage:

- **Close, volume and market cap for the full lifetime of each coin**,
  in any quote currency. In USD they come from CoinGecko's daily CSV
  export (one request per coin), otherwise from the website's chart data
  (two requests per coin).

- **OHLC** (`open` / `high` / `low`) is built from 4-hour candles (one
  extra request per coin) and covers the **most recent 30 days**; older
  rows have `NA` there. Longer windows are only offered as 4-day
  candles, which are not daily bars. For a one-shot complete OHLC
  backfill see
  [`vignette("coingecko-pro-backfill")`](https://www.sebastianstoeckl.com/crypto2/dev/articles/coingecko-pro-backfill.md).

Only completed days are returned. If no close/volume/market-cap series
can be retrieved for any requested coin, the function stops with an
error (the source has most likely changed); if it fails for some coins
only, a warning names them.

**Fallback (opt-in).** With `options(crypto2.cg_api_fallback = TRUE)`,
coins the website cannot serve are fetched from CoinGecko's public API
instead, still without a key. Its daily history covers only the **last
365 days**, so this is off by default: a call that falls back warns and
lists the affected coins in `attr(result, "cg_api_fallback")`.

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
