# Parse JSON or return NULL on failure

Convenience wrapper around
[`jsonlite::fromJSON`](https://jeroen.r-universe.dev/jsonlite/reference/fromJSON.html)
that returns `NULL` instead of erroring out – matches the failure
semantics of
[`cg_get()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_get.md).

## Usage

``` r
cg_parse_json(txt, ...)
```

## Arguments

- txt:

  JSON text (length-1 character).

- ...:

  Passed to
  [`jsonlite::fromJSON`](https://jeroen.r-universe.dev/jsonlite/reference/fromJSON.html).
