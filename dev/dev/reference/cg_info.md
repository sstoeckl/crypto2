# Retrieve per-coin metadata from CoinGecko (CMC-compatible columns)

Companion to
[`crypto_info()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_info.md)
but for CoinGecko. Pulls descriptive metadata (description, categories,
logos, contract addresses across chains, links) for each coin in
`coin_list`. Uses the documented public API endpoint
`api.coingecko.com/api/v3/coins/{slug}` (no key required; ~30 req/min).

## Usage

``` r
cg_info(
  coin_list = NULL,
  limit = NULL,
  sleep = 2.5,
  wait = 60,
  max_retries = 3,
  finalWait = FALSE
)
```

## Arguments

- coin_list:

  Tibble in
  [`cg_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_list.md)
  /
  [`cg_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_listings.md)
  format (must have a `slug` column). If `NULL`, calls
  [`cg_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_list.md).

- limit:

  Optional cap on number of coins (top of the tibble).

- sleep:

  Seconds between calls (default `2.5` -\> 24 req/min, ~80% of the
  Demo-tier 30 req/min cap, with headroom for CoinGecko's sliding-window
  enforcement).

- wait:

  Seconds to wait before retrying after a 429 (default `60`, matching
  CoinGecko's rate-limit window). See
  [`cg_make_client()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_make_client.md).

- max_retries:

  Maximum retry attempts on 429 / network failures (default `3`). See
  [`cg_make_client()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_make_client.md).

- finalWait:

  Sleep 60s after the last call (mirrors
  [`crypto_info()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_info.md)).

## Value

Tibble with one row per coin:

- id:

  CoinGecko internal numeric id (from `image$thumb`).

- name, symbol, slug:

  Coin identifiers.

- category:

  `"coin"` if `asset_platform_id` is `NA`, else `"token"`.

- description:

  English description (HTML stripped to text).

- logo:

  URL of the large coin logo.

- status:

  Status notice from CoinGecko (`public_notice` field).

- notice:

  Additional notices (`additional_notices` joined).

- date_added:

  Date the coin was added to CoinGecko (`genesis_date` when set, else
  `NA`).

- date_launched:

  Same as `date_added` for CG (no separate launch field exposed).

- categories:

  List-column of coin categories.

- platforms:

  List-column: per-chain contract addresses.

- web_slug:

  CoinGecko canonical web slug (sometimes differs from API slug).

- country_origin:

  Country of project origin (often empty).

- sentiment_votes_up_percentage, sentiment_votes_down_percentage:

  Community sentiment percentages.

- watchlist_portfolio_users:

  Number of CG users watching this coin.

- url:

  List-column of resource URLs (homepage, whitepaper, blockchain
  explorers, forums, repos, chats, announcements, subreddit, twitter).

## Details

Column names mirror
[`crypto_info()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_info.md)
where there is a direct equivalent, and add a few CG-specific fields
(`platforms`, `categories`).

## Examples

``` r
if (FALSE) { # \dontrun{
info <- cg_info(cg_list(top_n = 50))
} # }
```
