# Safe HTTP GET with browser-like User-Agent

Wraps [`httr::GET`](https://httr.r-lib.org/reference/GET.html) with a
Chrome User-Agent (defeats Cloudflare's cheapest bot heuristic), follows
redirects, and returns the response body as text.

## Usage

``` r
cg_get(url, query = NULL, accept = "application/json, text/plain, */*")
```

## Arguments

- url:

  Full URL to GET.

- query:

  Optional named list of query parameters.

- accept:

  Default `"application/json, text/plain, */*"`. Override to
  `"text/html"` etc. as needed.

## Value

Raw response body as a length-1 character vector on 2xx, or `NULL` for
non-retryable non-2xx (404 etc.). Raises a classed condition on
retryable failures (429, network errors).

## Details

Failure semantics – designed to interact correctly with the
[`cg_make_client()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_make_client.md)
retry wrapper:

- **Network / connection errors** raise a classed condition
  (`"cg_network_error"`) – retryable by
  [`purrr::insistently`](https://purrr.tidyverse.org/reference/insistently.html).

- **HTTP 429** (rate-limited) raises a classed condition
  (`"cg_rate_limited"`) carrying the `Retry-After` header in seconds
  (defaulting to 60 if absent) – retryable by
  [`purrr::insistently`](https://purrr.tidyverse.org/reference/insistently.html),
  which will pause `wait` seconds before retrying.

- **HTTP 403 with `cf-mitigated` header** (Cloudflare bot challenge)
  returns `NULL` and emits a one-time message per session advising the
  user to run from a residential IP. Cloudflare challenges are not
  solvable by retry, so they are *not* raised as retryable conditions.

- **Other non-2xx responses** (404, 410, 5xx, ...) return `NULL`
  **without** raising, so a missing coin or a stale endpoint does not
  consume retry budget – the caller decides what to do with `NULL`.

- **2xx** returns the response body as a length-1 character vector.
