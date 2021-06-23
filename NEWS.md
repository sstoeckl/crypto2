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
