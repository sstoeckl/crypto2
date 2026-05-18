# CoinGecko URL builder

Internal URL builder. The host strings are base64-encoded (same pattern
as
[`construct_url()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/construct_url.md)
for CMC) so the package source does not contain plaintext endpoint URLs.
The `api` host is the documented Demo-tier API; the `web` and `web_en`
hosts route through the public website. The `hf` host is the Hugging
Face download root for the optional historic id/slug mapping (see
[`cg_id_mapping()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_id_mapping.md)).

## Usage

``` r
cg_url(path, host = c("web", "web_en", "api", "hf"))
```

## Arguments

- path:

  Path to append (no leading slash).

- host:

  One of `"api"`, `"web"`, `"web_en"`, `"hf"`. Default `"web"`.

## Value

Full URL string.
