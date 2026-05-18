# Changelog

## crypto2 (development version)

- [`crypto_info()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_info.md)
  and
  [`exchange_info()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/exchange_info.md)
  now use a column allowlist instead of a denylist when processing API
  responses. New or unknown fields from CMC — including list-type fields
  that would previously break
  [`as_tibble()`](https://tibble.tidyverse.org/reference/as_tibble.html)
  — are silently ignored. This makes both functions robust to future CMC
  API additions without requiring a patch release.

### CoinGecko integration (branch: `coingecko-integration`)

Added four functions that mirror the CMC-side API but pull from
CoinGecko, no API key required. Column names match
[`crypto_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_list.md)
/
[`crypto_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_listings.md)
/
[`crypto_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_history.md)
/
[`crypto_info()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_info.md)
where there is a direct equivalent, so downstream code that already
consumes a CMC tibble works on a CG tibble too.

- [`cg_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_list.md)
  — active coin universe via the documented `/coins/list` (one HTTP
  call) and enriched with market-cap rank + internal numeric id via the
  paginated `/coins/markets`.
- [`cg_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_listings.md)
  — current snapshot for all active coins (paginated `/coins/markets`
  with `price_change_percentage=1h,24h,7d,14d,30d,200d,1y`).
- [`cg_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_history.md)
  — full daily OHLC + volume + market-cap history. Uses the
  **undocumented** website-host endpoints
  (`price_charts/{slug}/{vs}/max.json`,
  `market_cap/{slug}/{vs}/max.json`,
  `ohlc/{numeric_id}/series/{vs}/max.json`) which return one coin’s
  entire history in one HTTP call and are not bound by the documented 30
  req/min rate-limit.
- [`cg_info()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_info.md)
  — per-coin metadata (description, logos, categories, contract
  addresses across chains, links) via `/coins/{slug}` on the documented
  host.
- [`cg_history_by_id()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_history_by_id.md)
  — companion to
  [`cg_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_history.md)
  that addresses coins by **numeric ID** instead of slug, calling
  `www.coingecko.com/{price_charts,market_cap,ohlc}/{numeric_id}/...`.
  Useful when accumulated snapshots have collected numeric IDs whose
  slugs have since been removed from CoinGecko’s public routing: the
  numeric ID still serves the historical data (at least for the dense
  early-ID range). The function defaults to the active universe from
  [`cg_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_list.md)
  — blind `1:N` iteration does **not** work because the numeric-ID space
  is sparse (max ~102M but only ~15k populated as of mid 2026).

**Survivorship bias caveat.** CoinGecko’s free tier exposes active coins
only — delisted coins return 404 on both `/coins/list` and
`/coins/{slug}`. To build a survivorship-bias-corrected dataset on
CoinGecko, snapshot periodically (daily/weekly) and accumulate the
*union of numeric IDs ever observed* in an external database, then feed
that union to
[`cg_history_by_id()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_history_by_id.md)
for refresh. Coins delisted after your first snapshot are then preserved
via their numeric ID.

Endpoints reverse-engineered from the `data-url`/`data-chart-urls`
attributes embedded in `https://www.coingecko.com/en/coins/{slug}` page
HTML (the website’s own JS calls these). No API key, no signup. All
requests use a browser-like `User-Agent` to defeat Cloudflare’s cheapest
bot heuristics; override via `options(crypto2.cg_user_agent = "...")`.

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
