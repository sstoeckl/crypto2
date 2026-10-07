# Changelog

## crypto2 2.1.0.9000 (development version)

### CMC-CoinGecko crosswalk

- New
  [`crypto_crosswalk()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_crosswalk.md)
  links CoinMarketCap ids (`crypto_*`) to CoinGecko slugs and numeric
  ids (`cg_*`), including dead coins, from the weekly Open Crypto
  Pricing crosswalk (Stoeckl & Pukrop 2026,
  <https://opencryptopricing.com>, CC BY 4.0). Pairs are matched on
  contracts, project links, name/symbol and slug and confirmed on both
  providers’ prices; `min_confidence` (high / medium / low) filters by
  match quality and `include_unmatched = TRUE` adds coins listed by one
  provider only. The file is cached per session; Parquet is used when
  `arrow` is installed, CSV otherwise.

### Listings return prices by default

- [`crypto_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_listings.md)
  now defaults to `quote = TRUE`, like
  [`cg_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_listings.md).
  Under the old `quote = FALSE` default a call returned no `price`,
  volume or market-cap columns and no error, which is easy to miss in an
  automated pipeline. The quotes come with the same API response, so the
  default costs no extra requests. Pass `quote = FALSE` for identifiers,
  ranks and supply only.

### Complete listings, no silent truncation

Two defaults silently returned incomplete data; both are fixed.

- [`cg_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_listings.md)
  now defaults to `quote = TRUE` and returns every field of
  `/coins/markets`: `price` (`current_price`), `volume_24h`
  (`total_volume`), `high_24h`, `low_24h`, `price_change_24h`, the
  `percent_change_*` windows, `market_cap_change_24h`,
  `market_cap_change_percentage_24h`, `ath`/`atl` with their dates, and
  the flattened `roi_times`, `roi_currency`, `roi_percentage`.
  `last_updated`, `ath_date` and `atl_date` are now POSIXct (UTC) rather
  than Date. Under the previous `quote = FALSE` default, snapshots
  carried no price, and deriving one as
  `market_cap / circulating_supply` is off by up to 16%.
- [`cg_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_listings.md)
  defaults to `limit = NULL` (all coins, about 18,000 on 70+ pages). A
  page that still fails after the retries now stops paging with a
  warning naming the page, instead of returning a silently shortened
  snapshot.
- All `cg_*` functions send a CoinGecko Demo-API key as the
  `x-cg-demo-api-key` header when the environment variable `CG_DEMO_KEY`
  is set (30 instead of a handful of calls per minute). HTTP
  408/502/503/504 are now retried with backoff like 429.
- [`?cg_listings`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_listings.md)
  documents that `/coins/markets` no longer lists wrapped, staked or
  bridged tokens (stETH, wstETH, WBTC, JitoSOL, bridged USDT); their
  history is only available through
  [`cg_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_history.md).
- [`crypto_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_listings.md)
  defaults to `limit = NULL` (all coins). Since 2021-05-07 CMC lists
  more than 5,000 coins per day (9,002 on 2024-01-07), and the old
  default `limit = 5000` cut every day at rank 5,000 without a warning.
  `which = "historical"` now pages in blocks of 5,000, and a result that
  reaches an explicit `limit` warns that it may be truncated.
  [`crypto_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_history.md)
  without `coin_list` now selects from the full latest listing rather
  than its top 5,000.
- [`crypto_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_listings.md)
  no longer loses a whole day when CMC lists an exact multiple of 5,000
  coins (e.g. 10,000 on 2024-07-10 and 2024-07-11). The empty page that
  ends such a day made the page parser fail; for `which = "historical"`
  the day was then dropped without a warning, for `"latest"` / `"new"`
  the call errored. Empty pages now end the paging and keep the pages
  already loaded.
- `crypto_listings(which = "historical")` now warns and names every day
  that still fails after the retries; such days are missing from the
  result rather than truncated.
  [`cg_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_list.md)
  warns with the page number if `/coins/markets` paging stops on a
  failed page.

### `cg_history()` rebuilt on CoinGecko’s CSV export

CoinGecko retired the website endpoints
`price_charts/<coin>/<vs>/max.json` and
`market_cap/<coin>/<vs>/max.json` (HTTP 404). Since then
[`cg_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_history.md)
and
[`cg_history_by_id()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_history_by_id.md)
silently returned no close, volume or market cap, only 4-day OHLC
candles misread as daily bars.

- Close, volume and market cap now come from the daily CSV export
  `price_charts/export/<coin>/usd.csv`: the full lifetime of each coin
  in a single request. Over the last 365 days the values are identical
  to the API’s `market_chart` series and within 0.05% of CMC for BTC.
  The export’s close is dated one day later than its market cap and
  volume; the package re-aligns them, so the `date_convention` semantics
  are unchanged.
- The export is USD-only. For any other `convert` / `vs_currency` the
  series come from the API `market_chart` endpoint and cover the most
  recent 365 days (a one-time warning says so).
- Daily OHLC is aggregated from 4-hour candles and covers the most
  recent 30 days (previously documented as 365 days, but those were
  4-day candles). `close` now comes from the price series throughout, so
  the column no longer switches source 30 days back; OHLC candles only
  back-fill it.
- Only completed days are returned.
- If no series can be retrieved for any requested coin, the functions
  now stop with an error; partial failures warn and name the affected
  coins.

### CoinGecko integration

Added a CoinGecko-side counterpart to the CMC API as a second,
independent source. Column names mirror the `crypto_*` functions, so
downstream code that already consumes a CMC tibble works on a CG tibble
too.

- [`cg_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_list.md)
  – active coin universe; signature matches
  [`crypto_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_list.md).
  With `only_active = FALSE`, transparently extends the universe with
  the historic mapping from
  [`cg_id_mapping()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_id_mapping.md)
  and prints one line indicating how current that mapping is.
- [`cg_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_listings.md)
  – current cross-sectional snapshot; signature matches
  [`crypto_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_listings.md).
  Only `which = "latest"` is supported on the free tier; `"new"` /
  `"historical"` warn and coerce.
- [`cg_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_history.md)
  – daily OHLC + volume + market-cap history; signature matches
  [`crypto_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_history.md).
  Missing numeric ids are silently backfilled from the historic mapping.
- [`cg_info()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_info.md)
  – per-coin metadata; signature matches
  [`crypto_info()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_info.md).
- [`cg_history_by_id()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_history_by_id.md)
  – companion to
  [`cg_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_history.md)
  that addresses coins by their numeric CoinGecko id rather than slug,
  useful for refreshing coins whose slug no longer resolves.
- [`cg_id_mapping()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_id_mapping.md)
  – reads a periodically-refreshed
  `(id, slug, symbol, name, harvested_at)` archive (cached in
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html), with a small
  bundled fallback in `inst/extdata/`). Used internally by
  `cg_list(only_active = FALSE)` and
  [`cg_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_history.md);
  can also be called directly.

CG-specific knobs that have no CMC counterpart (rate-limit floor, retry
budget, OHLC-stream selection) move to package options:
`crypto2.cg_sleep`, `crypto2.cg_wait`, `crypto2.cg_max_retries`,
`crypto2.cg_top_n`, `crypto2.cg_what`, `crypto2.cg_vs_currency`. This
keeps the public signatures aligned with the CMC functions.

### Date convention (behavioural change in `cg_history()`)

[`cg_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_history.md)
and
[`cg_history_by_id()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_history_by_id.md)
now harmonize their date labels with
[`crypto_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_history.md)
by default. CoinGecko’s native daily series timestamps each point at
00:00:00 UTC of date X, which is the same physical instant as 23:59:59
UTC of date X-1 – but CMC (and the standard asset-pricing convention
used by CRSP / Compustat / Liu, Tsyvinski & Wu 2022) labels that instant
as date X-1, while CG labels it as date X. Empirically, CG’s row
labelled date X agrees with CMC’s row labelled date X-1 to within
sub-dollar precision (verified against hourly intraday CG data; see
`tools/check_cg_midnight_convention.R`).

- New argument `date_convention = c("end_of_day", "raw")` on both
  [`cg_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_history.md)
  and
  [`cg_history_by_id()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_history_by_id.md),
  defaulting to `"end_of_day"`. Under the default, midnight-UTC ticks
  are attributed to the previous date so `close[X] / close[X-1] - 1` is
  the return earned during date X, matching CMC.
- Pass `date_convention = "raw"` to keep CG’s native start-of-day
  labels.

### Vignettes

- New `coingecko-integration.Rmd` – the user-facing walkthrough.
- New `coingecko-pro-backfill.Rmd` – recipes for the optional one-shot
  Pro-tier bootstrap of a complete historic universe. Functions are kept
  inline in the vignette rather than exported from the package.
- New `cg-vs-cmc.Rmd` – cross-source reconciliation, the date-convention
  story in detail, and guidance on which fields are expected to agree
  vs. expected to differ between the two providers.

### Tests

- New `test-cg-vs-cmc.R` – reconciles `cg_history(BTC)` against
  `crypto_history(BTC)` over a 7-day window, asserts \|pct diff\| \< 1%
  per day. Will fail loudly if the date conventions ever drift out of
  alignment again or if either provider switches its underlying exchange
  basket enough to break the tolerance.

### Other

- [`crypto_info()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_info.md)
  and
  [`exchange_info()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/exchange_info.md)
  now use a column allowlist instead of a denylist when processing API
  responses. New or unknown fields from CMC – including list-type fields
  that would previously break
  [`as_tibble()`](https://tibble.tidyverse.org/reference/as_tibble.html)
  – are silently ignored, making both functions robust to future CMC
  additions without a patch release.
- Coverage clarification (and tightened warning in
  [`cg_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_history.md)):
  close, volume and market cap are returned for the full lifetime of
  each coin on the free tier. The OHLC quartet (open / high / low) is
  capped at the most recent 365 days; for older windows those three
  columns come back `NA` while close remains populated from the price
  stream. The one-time warning now only fires when OHLC is actually
  requested over a window that exceeds the cap.

## crypto2 2.0.5

CRAN release: 2025-09-11

Slight change in api call outcome needed another modification in
[`crypto_info()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_info.md).

## crypto2 2.0.4

Slight change in api call outcome needed another modification in
[`crypto_info()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_info.md).

## crypto2 2.0.3

CRAN release: 2024-10-11

Slight change in api call outcome needed another modification in
[`crypto_info()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_info.md).
Also corrected one failing tests to not check time zones.

## crypto2 2.0.2

CRAN release: 2024-09-02

Slight change in api call outcome needed another modification in
[`crypto_info()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_info.md).

## crypto2 2.0.1

CRAN release: 2024-07-03

Slight change in api call outcome needed a modification in
[`crypto_info()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_info.md).

## crypto2 2.0.0

CRAN release: 2024-06-13

After a major change in the api structure of coinmarketcap.com, the
package had to be rewritten. As a result, many functions had to be
rewritten, because data was not available any more in a similar format
or with similar accuracy. Unfortunately, this will potentially break
many users implementations. Here is a detailed list of changes:

- [`crypto_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_list.md)
  has been modified and delivers the same data as before.
- [`exchange_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/exchange_list.md)
  has been modified and delivers the same data as before.
- [`fiat_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/fiat_list.md)
  has been modified and no longer delivers all available currencies and
  precious metals (therefore only USD and Bitcoin are available any
  more).
- [`crypto_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_listings.md)
  needed to be modified, as multiple base currencies are not available
  any more. Also some of the fields downloaded from CMC might have
  changed. It still retrieves the latest listings, the new listings as
  well as historical listings. The fields returned have somewhat
  slightly changed. Also, no sorting is available any more, so if you
  want to download the top x CCs by market cap, you have to download all
  CCs and then sort them in R.
- [`crypto_info()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_info.md)
  has been modified, as the data structure has changed. The fields
  returned have somewhat slightly changed.
- [`crypto_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_history.md)
  has been modified. It still retrieves all the OHLC history of all the
  coins, but is slower due to an increased number of necessary api
  calls. The number of available intervals is strongly limited, but
  hourly and daily data is still available. Currently only USD and BTC
  are available as quote currencies through this library.
- [`crypto_global_quotes()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_global_quotes.md)
  has been modified. It still produces a clear picture of the global
  market, but the data structure has somewhat slightly changed.

## crypto2 1.4.6

CRAN release: 2024-01-29

Added new options “sort” and “sort_dir” for
[`crypto_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_listings.md)
to allow for the sorting of results, which in combination with “limit”
allows, for example, to only download the top 100 CCs according to
market capitalization that were listed at a certain date. Correct
missing last_historical_data date conversion due to the now missing
field.

## crypto2 1.4.5

CRAN release: 2022-10-19

Added a new function
[`crypto_global_quotes()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_global_quotes.md)
which retrieves global aggregate market statistics for CMC. There also
were some bugs fixed.

## crypto2 1.4.4

CRAN release: 2022-07-18

A new function
[`crypto_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_listings.md)
is introduced to retrieve new/latest/historical listings and listing
information at CMC. The option `finalWait = TRUE` does not seem to be
necessary any more, also `sleep` can be set to ‘0’ seconds.

## crypto2 1.4.3

CRAN release: 2022-01-25

change limit==1 bug, add interval parameter (offered by pull-request),
also change the amount of id splits to allow for max url length 2000

## crypto2 1.4.2

CRAN release: 2022-01-11

Repaired the history retrieval due to the fact that one api call can
only retrieve 1000 data points. Therefore we have to call more often on
the api when retrieving the entire history.

## crypto2 1.4.1

Added and corrected a waiter function to wait an additional 60 seconds
after the end of the history command before another command could be
executed (to not accidentally retrieve the same outdated data). Fixed
the waiter.

## crypto2 1.4.0

CRAN release: 2022-01-10

Due to a change in the web-api of CMC we can only make one call to the
api per minute (else, it will just deliver the same output as for the
first call of the 60 seconds). To reduce the overhang, I have redesigned
the interfaces to retrieve as many ids from one api call as possible
(limited by the 2000 character limitation of the URL). We can set
`requestLimit` to increase/decrease the number of simultaneous ids that
are retrieved from CMC.

## crypto2 1.3.0

CRAN release: 2021-06-24

Rewrite of crypto_info and exchange_info to take similar input as
crypto_history. Also extensively updated readme.

## crypto2 1.2.1

Adapt spelling and ’’ for CRAN and explain why I have taken Jesse Vent
off the package authors (except function names everything else is new)

## crypto2 1.2.0

Add Exchange functions, delete unnecessary functions, update readme,
prepare for submission to cran

## crypto2 1.1.3.9000

- Corrected small error in crypto_info where non-existing slugs led to
  break of the code (because for some reason I stopped using
  “Insistent”)

## crypto2 1.1.3.9000

- Correct a glitch in the tag data, where now not enough group
  observations are available. Info I have therefore deleted.
- Corrected small error about empty list in coin_info

## crypto2 1.1.2.9000

- Added a `NEWS.md` file to track changes to the package.
- Deleted necessary API key from crypto_list(). Now we do not need an
  api key anymore
