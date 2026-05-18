# Retrieves name, CG id, symbol, slug, rank, an activity flag as well as activity dates on CoinGecko for all coins

Companion to
[`crypto_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_list.md)
but for CoinGecko. Returns the active universe as a tibble using the
same column conventions as
[`crypto_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_list.md),
so downstream code that consumes a CMC coin list also consumes this one.

## Usage

``` r
cg_list(only_active = TRUE, add_untracked = FALSE)
```

## Arguments

- only_active:

  Shall the code only retrieve active coins (`TRUE` = default) or
  include historically-known but currently-inactive coins (`FALSE`)?
  When `FALSE`,
  [`cg_id_mapping()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_id_mapping.md)
  is consulted for the extra slugs.

- add_untracked:

  Kept for API parity with
  [`crypto_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_list.md)
  – CoinGecko does not have an "untracked" listing status, so the
  argument is silently ignored.

## Value

List of (active and historically existing) cryptocurrencies in a tibble:

- id:

  CoinGecko internal numeric id (unique identifier).

- name:

  Coin name.

- symbol:

  Coin symbol (not-unique).

- slug:

  CoinGecko URL slug (unique).

- rank:

  Current market-cap rank on CoinGecko (`NA` for delisted or unranked
  coins).

- is_active:

  Flag showing whether the coin is currently active (`1`) or only
  historically present (`0`).

- first_historical_data:

  First time listed on CoinGecko (currently only populated for coins
  present in the historic mapping).

- last_historical_data:

  Last time listed on CoinGecko, today's date if still active.

Rate-limiting and retry parameters can be overridden globally via the
package options `crypto2.cg_sleep`, `crypto2.cg_wait`,
`crypto2.cg_max_retries` (defaults: 2.5s between calls, 60s wait before
retry, 3 retries on rate-limit / network failure).

## Details

Because CoinGecko prunes delisted coins from its public database, the
free-tier API alone only returns coins currently active on the platform.
When `only_active = FALSE`, the function transparently merges in
historically-known coins via
[`cg_id_mapping()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_id_mapping.md);
a single one-line message is emitted indicating how current that mapping
is.

## Examples

``` r
if (FALSE) { # \dontrun{
# all coins currently tracked by CoinGecko
active_list <- cg_list(only_active = TRUE)

# active + historically-listed coins (uses cg_id_mapping())
full_list <- cg_list(only_active = FALSE)
} # }
```
