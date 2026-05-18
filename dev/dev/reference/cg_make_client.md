# Build a slow + insistent wrapper around `cg_get`

Combines
[`purrr::slowly`](https://purrr.tidyverse.org/reference/slowly.html)
(rate limiting between successful calls) and
[`purrr::insistently`](https://purrr.tidyverse.org/reference/insistently.html)
(retry with exponential backoff on retryable errors) to produce an HTTP
client suitable for batch jobs.

## Usage

``` r
cg_make_client(sleep = 0.6, wait = 60, max_retries = 3, quiet = TRUE)
```

## Arguments

- sleep:

  Seconds between successive successful calls (default 0.6 -\> ~100
  req/min, polite for the website host; the documented
  `api.coingecko.com` host needs `sleep >= 2.5` to stay safely below the
  30 req/min Demo-tier cap).

- wait:

  Seconds to wait before the first retry after a 429 / network error.
  Defaults to 60 so the CoinGecko 60-second rate-limit window fully
  resets before the retry fires. Exponential backoff applies for
  subsequent retries, up to `pause_cap = wait * 4`.

- max_retries:

  Max retry attempts on failure (default 3, giving up to ~ 60 + 120 +
  240 = 420 s of additional waiting in the worst case).

- quiet:

  If `FALSE`,
  [`purrr::insistently`](https://purrr.tidyverse.org/reference/insistently.html)
  emits a message on every retry so the caller sees the back-off in
  progress. Default `TRUE`.

## Details

Retry behaviour:
[`cg_get()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_get.md)
raises a classed condition for HTTP 429 (rate-limited) and network
failures. The `insistently` wrapper catches these and retries up to
`max_retries` times, waiting `wait` seconds before the first retry and
up to `wait * 4` seconds before later retries (with jitter).
Non-retryable HTTP errors (404, 410, 5xx) still return `NULL`
immediately and do not consume retry budget.
