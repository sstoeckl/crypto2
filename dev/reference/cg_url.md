# CoinGecko URL builder

Builds a full URL for one of the four key-free CoinGecko hosts used by
this package. The website-host endpoints (`web`, `web_en`) are the
website's own internal JSON routes (not documented), discovered via
reverse-engineering the page HTML. The documented host (`api`) is the
public Demo-tier API (`api.coingecko.com/api/v3/`), which is
rate-limited to ~30 req/min but supports slug-based addressing for the
basic universe and per-coin detail.

## Usage

``` r
cg_url(path, host = c("web", "web_en", "api"))
```

## Arguments

- path:

  Path to append (no leading slash).

- host:

  One of `"api"` (documented), `"web"` (website, locale-free, used by
  `/price_charts/`, `/market_cap/`, `/ohlc/`, `/coins/...`), `"web_en"`
  (website, `/en/` prefixed, used by `/historical_data`,
  `/financials_chart_data`, etc.). Default `"web"`.

## Value

Full URL string.
