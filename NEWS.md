# crypto2 2.1.0.9000 (development version)

## CoinGecko integration

Added a CoinGecko-side counterpart to the CMC API as a second, independent
source. Column names mirror the `crypto_*` functions, so downstream code that
already consumes a CMC tibble works on a CG tibble too.

* `cg_list()` -- active coin universe; signature matches `crypto_list()`. With
  `only_active = FALSE`, transparently extends the universe with the historic
  mapping from `cg_id_mapping()` and prints one line indicating how current
  that mapping is.
* `cg_listings()` -- current cross-sectional snapshot; signature matches
  `crypto_listings()`. Only `which = "latest"` is supported on the free tier;
  `"new"` / `"historical"` warn and coerce.
* `cg_history()` -- daily OHLC + volume + market-cap history; signature
  matches `crypto_history()`. Missing numeric ids are silently backfilled
  from the historic mapping.
* `cg_info()` -- per-coin metadata; signature matches `crypto_info()`.
* `cg_history_by_id()` -- companion to `cg_history()` that addresses coins by
  their numeric CoinGecko id rather than slug, useful for refreshing coins
  whose slug no longer resolves.
* `cg_id_mapping()` -- reads a periodically-refreshed `(id, slug, symbol,
  name, harvested_at)` archive (cached in `tempdir()`, with a small bundled
  fallback in `inst/extdata/`). Used internally by `cg_list(only_active =
  FALSE)` and `cg_history()`; can also be called directly.

CG-specific knobs that have no CMC counterpart (rate-limit floor, retry
budget, OHLC-stream selection) move to package options:
`crypto2.cg_sleep`, `crypto2.cg_wait`, `crypto2.cg_max_retries`,
`crypto2.cg_top_n`, `crypto2.cg_what`, `crypto2.cg_vs_currency`. This keeps
the public signatures aligned with the CMC functions.

## Date convention (behavioural change in `cg_history()`)

`cg_history()` and `cg_history_by_id()` now harmonize their date labels
with `crypto_history()` by default. CoinGecko's native daily series
timestamps each point at 00:00:00 UTC of date X, which is the same
physical instant as 23:59:59 UTC of date X-1 -- but CMC (and the
standard asset-pricing convention used by CRSP / Compustat / Liu,
Tsyvinski & Wu 2022) labels that instant as date X-1, while CG labels it
as date X. Empirically, CG's row labelled date X agrees with CMC's row
labelled date X-1 to within sub-dollar precision (verified against
hourly intraday CG data; see `tools/check_cg_midnight_convention.R`).

* New argument `date_convention = c("end_of_day", "raw")` on both
  `cg_history()` and `cg_history_by_id()`, defaulting to
  `"end_of_day"`. Under the default, midnight-UTC ticks are attributed
  to the previous date so `close[X] / close[X-1] - 1` is the return
  earned during date X, matching CMC.
* Pass `date_convention = "raw"` to keep CG's native start-of-day labels.

## Vignettes

* New `coingecko-integration.Rmd` -- the user-facing walkthrough.
* New `coingecko-pro-backfill.Rmd` -- recipes for the optional one-shot
  Pro-tier bootstrap of a complete historic universe. Functions are kept
  inline in the vignette rather than exported from the package.
* New `cg-vs-cmc.Rmd` -- cross-source reconciliation, the date-convention
  story in detail, and guidance on which fields are expected to agree
  vs. expected to differ between the two providers.

## Tests

* New `test-cg-vs-cmc.R` -- reconciles `cg_history(BTC)` against
  `crypto_history(BTC)` over a 7-day window, asserts |pct diff| < 1%
  per day. Will fail loudly if the date conventions ever drift out of
  alignment again or if either provider switches its underlying
  exchange basket enough to break the tolerance.

## Other

* `crypto_info()` and `exchange_info()` now use a column allowlist instead of
  a denylist when processing API responses. New or unknown fields from CMC --
  including list-type fields that would previously break `as_tibble()` --
  are silently ignored, making both functions robust to future CMC
  additions without a patch release.
* Coverage clarification (and tightened warning in `cg_history()`):
  close, volume and market cap are returned for the full lifetime of
  each coin on the free tier. The OHLC quartet (open / high / low) is
  capped at the most recent 365 days; for older windows those three
  columns come back `NA` while close remains populated from the price
  stream. The one-time warning now only fires when OHLC is actually
  requested over a window that exceeds the cap.

# crypto 2.0.5

Slight change in api call outcome needed another modification in `crypto_info()`.

# crypto 2.0.4

Slight change in api call outcome needed another modification in `crypto_info()`.

# crypto 2.0.3

Slight change in api call outcome needed another modification in `crypto_info()`. Also corrected one failing tests to not check time zones.

# crypto 2.0.2

Slight change in api call outcome needed another modification in `crypto_info()`.

# crypto 2.0.1

Slight change in api call outcome needed a modification in `crypto_info()`.

# crypto 2.0.0

After a major change in the api structure of coinmarketcap.com, the package had to be rewritten. As a result, many functions had to be rewritten, because data was not available any more in a similar format or with similar accuracy. Unfortunately, this will potentially break many users implementations. Here is a detailed list of changes:

- `crypto_list()` has been modified and delivers the same data as before.
- `exchange_list()` has been modified and delivers the same data as before.
- `fiat_list()` has been modified and no longer delivers all available currencies and precious metals (therefore only USD and Bitcoin are available any more).
- `crypto_listings()` needed to be modified, as multiple base currencies are not available any more. Also some of the fields downloaded from CMC might have changed. It still retrieves the latest listings, the new listings as well as historical listings. The fields returned have somewhat slightly changed. Also, no sorting is available any more, so if you want to download the top x CCs by market cap, you have to download all CCs and then sort them in R.
- `crypto_info()` has been modified, as the data structure has changed. The fields returned have somewhat slightly changed.
- `crypto_history()` has been modified. It still retrieves all the OHLC history of all the coins, but is slower due to an increased number of necessary api calls. The number of available intervals is strongly limited, but hourly and daily data is still available. Currently only USD and BTC are available as quote currencies through this library.
- `crypto_global_quotes()` has been modified. It still produces a clear picture of the global market, but the data structure has somewhat slightly changed.


# crypto 1.4.6 

Added new options "sort" and "sort_dir" for `crypto_listings()` to allow for the sorting of results, which in combination with "limit" allows, for example, to only download the top 100 CCs according to market capitalization that were listed at a certain date. Correct missing last_historical_data date conversion due to the now missing field.

# crypto 1.4.5 

Added a new function `crypto_global_quotes()` which retrieves global aggregate market statistics for CMC. There also were some bugs fixed.

# crypto 1.4.4 

A new function `crypto_listings()` is introduced to retrieve new/latest/historical listings and listing information at CMC. The option `finalWait = TRUE` does not seem to be necessary any more, also `sleep` can be set to '0' seconds.

# crypto 1.4.3 

change limit==1 bug, add interval parameter (offered by pull-request), also change the amount of id splits to allow for max url length 2000

# crypto 1.4.2

Repaired the history retrieval due to the fact that one api call can only retrieve 1000 data points. Therefore we have to call more often on the api when retrieving the entire history.

# crypto 1.4.1

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
