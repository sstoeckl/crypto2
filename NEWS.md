# crypto2 3.0.0

A major release. crypto2 now draws on two sources: CoinMarketCap (the
`crypto_*` functions, as before) and CoinGecko (the new `cg_*` functions),
with a crosswalk that links the two id systems. Several defaults of
`crypto_listings()` change, so code that relied on them returns different
(complete) data; see "Breaking changes".

## Breaking changes

* `crypto_listings()` defaults to `limit = NULL` (all coins) instead of
  `limit = 5000`. Since 2021-05-07 CoinMarketCap lists more than 5,000
  coins per day (9,002 on 2024-01-07), and the old default cut every
  historical day at rank 5,000 without a warning.
* `crypto_listings()` defaults to `quote = TRUE`: price, volume, market-cap
  and percent-change columns are returned unless `quote = FALSE`. They come
  with the same API response, so the default costs no extra requests.
* `crypto_history()` without `coin_list` selects from the full latest
  listing rather than its top 5,000.

## CoinGecko as a second source

New functions with the same column conventions as their `crypto_*`
counterparts, so downstream code consumes either tibble. No API key is
needed.

* `cg_list()` -- coin universe; with `only_active = FALSE` it adds dead
  coins from `cg_id_mapping()`.
* `cg_listings()` -- current snapshot with every `/coins/markets` field
  (price, volume, 24h range, price and market-cap changes, all-time
  high/low, ROI). CoinGecko's free tier has no historical cross-section;
  snapshot this function periodically to build one. Wrapped, staked and
  bridged tokens are not listed by `/coins/markets`.
* `cg_history()` and `cg_history_by_id()` -- daily close, volume and market
  cap for the full lifetime of each coin in any quote currency, from
  CoinGecko's website chart data (in USD from its daily CSV export, one
  request per coin). Daily open/high/low are built from 4-hour candles and
  cover the last 30 days; CoinGecko offers longer windows only as 4-day
  candles.
* `cg_info()` -- coin metadata.
* `cg_id_mapping()` -- archive of CoinGecko ids including dead coins,
  cached per session with a small bundled fallback.
* Dates follow the CMC / CRSP convention by default
  (`date_convention = "end_of_day"`): CoinGecko's midnight-UTC ticks are
  labelled with the day that just ended, so `close[X] / close[X-1] - 1` is
  the return earned on date X. `date_convention = "raw"` keeps CoinGecko's
  labels.
* No API key is used anywhere. HTTP 429 and transient 408/502/503/504 responses are retried with
  backoff. Package options `crypto2.cg_sleep`, `crypto2.cg_wait`,
  `crypto2.cg_max_retries`, `crypto2.cg_top_n`, `crypto2.cg_what` and
  `crypto2.cg_vs_currency` tune rate limits, retries and streams.

## CMC-CoinGecko crosswalk

* New `crypto_crosswalk()` links CoinMarketCap ids to CoinGecko slugs and
  numeric ids, including dead coins, from the weekly Open Crypto Pricing
  crosswalk (Stoeckl & Pukrop 2026, <https://opencryptopricing.com>,
  CC BY 4.0). Pairs are matched on contracts, project links, name/symbol
  and slug and confirmed on both providers' prices; `min_confidence`
  (high / medium / low) filters by match quality and
  `include_unmatched = TRUE` adds coins listed by one provider only. The
  file is cached per session; Parquet is used when `arrow` is installed,
  CSV otherwise.

## No silent data loss

* `crypto_listings(which = "historical")` pages in blocks of 5,000 and no
  longer loses a whole day when CoinMarketCap lists an exact multiple of
  5,000 coins (e.g. 10,000 on 2024-07-10); for `"latest"` / `"new"` that
  case used to error. A day that still fails after the retries is left
  out and named in a warning, never returned truncated, and a day that
  reaches an explicit `limit` is flagged as possibly truncated.
* `crypto_global_quotes()` with the default `which = "latest"` returned
  `NULL`; it now returns the current global market metrics.
* `crypto_info()` and `exchange_info()` keep an allowlist of known columns,
  so new or list-type fields in the CoinMarketCap response no longer break
  them.
* The `cg_*` functions warn with the page number when paging stops on a
  failed page, and `cg_history()` / `cg_history_by_id()` stop with an error
  when CoinGecko returns no series for any requested coin (the source has
  most likely changed); partial failures name the affected coins.

## Vignettes

* `vignette("coingecko-integration")` -- walkthrough of the `cg_*`
  functions and a survivorship-bias-free price history in three lines.
* `vignette("cg-vs-cmc")` -- what each source delivers, matching coins
  with `crypto_crosswalk()`, the date conventions, and a reconciliation of
  the CMC top 20 across both sources.
* `vignette("coingecko-pro-backfill")` -- optional one-shot recipes for a
  complete historic universe with a CoinGecko Pro key.

## Tests

* Offline tests with simulated API responses cover paging, retries,
  failure warnings, the CSV re-alignment and the crosswalk, and run on
  CRAN. Live tests (skipped on CRAN) reconcile BTC across both sources and
  fail when a CoinGecko endpoint is retired rather than skipping.

# crypto2 2.0.5

Slight change in api call outcome needed another modification in `crypto_info()`.

# crypto2 2.0.4

Slight change in api call outcome needed another modification in `crypto_info()`.

# crypto2 2.0.3

Slight change in api call outcome needed another modification in `crypto_info()`. Also corrected one failing tests to not check time zones.

# crypto2 2.0.2

Slight change in api call outcome needed another modification in `crypto_info()`.

# crypto2 2.0.1

Slight change in api call outcome needed a modification in `crypto_info()`.

# crypto2 2.0.0

After a major change in the api structure of coinmarketcap.com, the package had to be rewritten. As a result, many functions had to be rewritten, because data was not available any more in a similar format or with similar accuracy. Unfortunately, this will potentially break many users implementations. Here is a detailed list of changes:

- `crypto_list()` has been modified and delivers the same data as before.
- `exchange_list()` has been modified and delivers the same data as before.
- `fiat_list()` has been modified and no longer delivers all available currencies and precious metals (therefore only USD and Bitcoin are available any more).
- `crypto_listings()` needed to be modified, as multiple base currencies are not available any more. Also some of the fields downloaded from CMC might have changed. It still retrieves the latest listings, the new listings as well as historical listings. The fields returned have somewhat slightly changed. Also, no sorting is available any more, so if you want to download the top x CCs by market cap, you have to download all CCs and then sort them in R.
- `crypto_info()` has been modified, as the data structure has changed. The fields returned have somewhat slightly changed.
- `crypto_history()` has been modified. It still retrieves all the OHLC history of all the coins, but is slower due to an increased number of necessary api calls. The number of available intervals is strongly limited, but hourly and daily data is still available. Currently only USD and BTC are available as quote currencies through this library.
- `crypto_global_quotes()` has been modified. It still produces a clear picture of the global market, but the data structure has somewhat slightly changed.


# crypto2 1.4.6 

Added new options "sort" and "sort_dir" for `crypto_listings()` to allow for the sorting of results, which in combination with "limit" allows, for example, to only download the top 100 CCs according to market capitalization that were listed at a certain date. Correct missing last_historical_data date conversion due to the now missing field.

# crypto2 1.4.5 

Added a new function `crypto_global_quotes()` which retrieves global aggregate market statistics for CMC. There also were some bugs fixed.

# crypto2 1.4.4 

A new function `crypto_listings()` is introduced to retrieve new/latest/historical listings and listing information at CMC. The option `finalWait = TRUE` does not seem to be necessary any more, also `sleep` can be set to '0' seconds.

# crypto2 1.4.3 

change limit==1 bug, add interval parameter (offered by pull-request), also change the amount of id splits to allow for max url length 2000

# crypto2 1.4.2

Repaired the history retrieval due to the fact that one api call can only retrieve 1000 data points. Therefore we have to call more often on the api when retrieving the entire history.

# crypto2 1.4.1

Added and corrected a waiter function to wait an additional 60 seconds after the end of the history command before another command could be executed (to not accidentally retrieve the same outdated data). Fixed the waiter.

# crypto2 1.4.0

Due to a change in the web-api of CMC we can only make one call to the api per minute (else, it will just deliver the same output as for the first call of the 60 seconds). To reduce the overhang, I have redesigned the interfaces to retrieve as many ids from one api call as possible (limited by the 2000 character limitation of the URL). We can set `requestLimit` to increase/decrease the number of simultaneous ids that are retrieved from CMC.

# crypto2 1.3.0

Rewrite of crypto_info and exchange_info to take similar input as crypto_history. Also extensively updated readme.

# crypto2 1.2.1

Adapt spelling and '' for CRAN and explain why I have taken Jesse Vent off the package authors (except function names everything else is new)

# crypto2 1.2.0

Add Exchange functions, delete unnecessary functions, update readme, prepare for submission to cran

# crypto2 1.1.3.9000

* Corrected small error in crypto_info where non-existing slugs led to break of the code (because for some reason I stopped using "Insistent")

# crypto2 1.1.3.9000

* Correct a glitch in the tag data, where now not enough group observations are available. Info I have therefore deleted.
* Corrected small error about empty list in coin_info

# crypto2 1.1.2.9000

* Added a `NEWS.md` file to track changes to the package.
* Deleted necessary API key from crypto_list(). Now we do not need an api key anymore
