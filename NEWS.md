# crypto2 (development version)

# crypto 2.0.2

Slight change in api call outcome needed another modification in `crypto_info()`.

# crypto 2.0.1

Slight change in api call outcome needed a modification in `crypto_info()`.

# crypto 2.0.0

After a major change in the api structure of coinmarketcap.com, the package had to be rewritten. As a result, many functions had to be rewritten, because data was not available any more in a similar format or with similar accuracy. Unfortunately, this will potentially break many users implementations. Here is a detailed list of changes:

- `crypto_list()` has been modified and delivers the same data as before.
- `exchange_list()` has been modified and delivers the same data as before.
- `fiat_list()` has been modified and no longer delivers all available currencies and precious metals (therefore only USD and Bitcoin are available any more).
- `crypto_listings()` needed to be modified, as multiple base currencies are not available any more. Also some of the fields downloaded from CMC might have changed. It still retrieves the latest listings, the new listings as well as historical listings. The fields returned have somewhat slightly changed. Also, no sorting is available any more, so if you want to download the top x CCs by market cap, you have to download all CCs and then sort them in R.
- `crypto_info()` has been modified, as the data structure has changed. The fields returned have somewhat slightly changed.
- `crypto_history()` has been modified. It still retrieves all the OHLC history of all the coins, but is slower due to an increased number of necessary api calls. The number of available intervals is strongly limited, but hourly and daily data is still available. Currently only USD and BTC are available as quote currencies through this library.
- `crypto_global_quotes()` has been modified. It still produces a clear picture of the global market, but the data structure has somewhat slightly changed.


# crypto 1.4.6 

Added new options "sort" and "sort_dir" for `crypto_listings()` to allow for the sorting of results, which in combination with "limit" allows, for example, to only download the top 100 CCs according to market capitalization that were listed at a certain date. Correct missing last_historical_data date conversion due to the now missing field.

# crypto 1.4.5 

Added a new function `crypto_global_quotes()` which retrieves global aggregate market statistics for CMC. There also were some bugs fixed.

# crypto 1.4.4 

A new function `crypto_listings()` is introduced to retrieve new/latest/historical listings and listing information at CMC. The option `finalWait = TRUE` does not seem to be necessary any more, also `sleep` can be set to '0' seconds.

# crypto 1.4.3 

change limit==1 bug, add interval parameter (offered by pull-request), also change the amount of id splits to allow for max url length 2000

# crypto 1.4.2

Repaired the history retrieval due to the fact that one api call can only retrieve 1000 data points. Therefore we have to call more often on the api when retrieving the entire history.

# crypto 1.4.1

Added and corrected a waiter function to wait an additional 60 seconds after the end of the history command before another command could be executed (to not accidentally retrieve the same outdated data). Fixed the waiter.

# crypto2 1.4.0

Due to a change in the web-api of CMC we can only make one call to the api per minute (else, it will just deliver the same output as for the first call of the 60 seconds). To reduce the overhang, I have redesigned the interfaces to retrieve as many ids from one api call as possible (limited by the 2000 character limitation of the URL). We can set `requestLimit` to increase/decrease the number of simultaneous ids that are retrieved from CMC.

# crypto2 1.3.0

Rewrite of crypto_info and exchange_info to take similar input as crypto_history. Also extensively updated readme.

# crypto2 1.2.1

Adapt spelling and '' for CRAN and explain why I have taken Jesse Vent off the package authors (except function names everything else is new)

# crypto2 1.2.0

Add Exchange functions, delete unnecessary functions, update readme, prepare for submission to cran

# crypto2 1.1.3.9000

* Corrected small error in crypto_info where non-existing slugs led to break of the code (because for some reason I stopped using "Insistent")

# crypto2 1.1.3.9000

* Correct a glitch in the tag data, where now not enough group observations are available. Info I have therefore deleted.
* Corrected small error about empty list in coin_info

# crypto2 1.1.2.9000

* Added a `NEWS.md` file to track changes to the package.
* Deleted necessary API key from crypto_list(). Now we do not need an api key anymore
