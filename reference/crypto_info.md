# Retrieves info (urls, logo, description, tags, platform, date_added, notice, status,...) on CMC for given id

This code retrieves data for all specified coins!

## Usage

``` r
crypto_info(
  coin_list = NULL,
  limit = NULL,
  requestLimit = 1,
  sleep = 0,
  finalWait = FALSE
)
```

## Arguments

- coin_list:

  string if NULL retrieve all currently active coins
  ([`crypto_list()`](https://sstoeckl.github.io/crypto2/reference/crypto_list.md)),
  or provide list of cryptocurrencies in the
  [`crypto_list()`](https://sstoeckl.github.io/crypto2/reference/crypto_list.md)
  or `cryptoi_listings()` format (e.g. current and/or dead coins since
  2015)

- limit:

  integer Return the top n records, default is all tokens

- requestLimit:

  (default: 1) limiting the length of request URLs when bundling the api
  calls (currently needs to be 1)

- sleep:

  integer (default: 0) Seconds to sleep between API requests

- finalWait:

  to avoid calling the web-api again with another command before 60s are
  over (FALSE=default)

## Value

List of (active and historically existing) cryptocurrencies in a tibble:

- id:

  CMC id (unique identifier)

- name:

  Coin name

- symbol:

  Coin symbol (not-unique)

- slug:

  Coin URL slug (unique)

- category:

  Coin category: "token" or "coin"

- description:

  Coin description according to CMC

- logo:

  CMC url of CC logo

- status:

  Status message from CMC

- notice:

  Markdown formatted notices from CMC

- alert_type:

  Type of alert on CMC

- alert_link:

  Message link to alert

- date_added:

  Date CC was added to the CMC database

- date_launched:

  Date CC was launched

- is_audited:

  Boolean if CC is audited

- flags:

  Boolean flags for various topics

- self_reported_circulating_supply:

  Self reported circulating supply

- tags:

  Tibble of tags and tag categories

- faq_description:

  FAQ description from CMC

- url:

  Tibble of various resource urls. Gives website, technical_doc
  (whitepaper), source_code, message_board, chat, announcement, reddit,
  twitter, (block) explorer urls

- platform:

  Metadata about the parent coin if available. Gives id, name, symbol,
  slug, and token address according to CMC

## Examples

``` r
if (FALSE) { # \dontrun{
# return info for bitcoin
coin_info <- crypto_info(limit=10)
} # }
```
