# Changelog

## crypto2 2.1.0.9000 (development version)

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
