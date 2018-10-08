<!-- README.md is generated from README.Rmd. Please edit that file -->

## memoisetools

`memoisetools` is a collection of additional caches and helper functions
to work alongside the [`memoise`
package](https://github.com/r-lib/memoise).

This package was started from a need to have an in-memory cache that did
not store results over a given size.

## Installation

``` r
devtools::install_github('coolbutuseless/memoisetools')
```

## `get_memoise_info()`

`get_memoise_info()` returns information about the caches used by a
memoised function.

  - `cache` - Cache type. Either ‘memory’, ‘filesystem’ or ‘gcs or aws’
  - Storage location
      - `env` - For ‘memory’ cache, the R environment in which objects
        are stored
      - `path` - For ‘filesystem’ caches, the path to the cache
        directory
      - `cache_name` - For ‘gcs or aws’ caches, the name of the cache
  - `algo` - Hashing algorithm for creating keys
  - `bytes` - Size (in bytes) of the cache
  - `n` - Number of objects in the cache
  - `has_timestamp` - Does the cache include timestamp information?
  - `compress` - Value for ‘compress’ variable

Note: because memoised functions could have multiple caches (e.g.
`memoise_with_mixed_backend`), this function returns a list of info for
each cache.

``` r
memoised_rnorm <- memoise::memoise(rnorm)

x <- memoised_rnorm(1000)
y <- memoised_rnorm(12)
z <- memoised_rnorm(1)

memoisetools::get_memoise_info(memoised_rnorm)
#> cache: memory, env: <environment>, algo: sha512, bytes: 9728, n: 3, has_timestamp: FALSE, compress: FALSE
```

## `cache_filesystem2()`

This is a replacement for `memoise::cache_filesystem()` with the
following changes:

  - use a `tempdir()` if no path specified
  - Full absolute path to cache is used, even if initialised with a
    relative path.  
    This avoids issues as detailed in this [memoise issue on
    github](https://github.com/r-lib/memoise/issues/51#issuecomment-319993161)
  - By default objects saved to filesystem are compressed using gzip
    compression. (The corresponding [memoise PR on
    github](https://github.com/r-lib/memoise/pull/70))
  - A separate data structure keeps track of the time of all
    reads/writes to the cache.
  - The addition of timestamps allows for expiring objects older than a
    certain age. See the function `memoisetools::expire_cache()`
  - the cache `has_key` method now uses the timestamp cache to determine
    if a given key exists or not. This makes it faster to check if a key
    exists (as no filesystem access is needed), but will cause an error
    if they file doesn’t *actually* exist e.g. if you’ve deleted the
    file manually.

## `cache_memory2()`

This is a replacement for `memoise::cache_memory()` with the following
changes:

  - A separate data structure keeps track of the time of all
    reads/writes to the cache.
  - The addition of timestamps allows for expiring objects older than a
    certain age. See the function `memoisetools::expire_cache()`
  - Use the faster hash `xxhash64` by default

## Expiring objects from the cache

With `cache_filesystem2()` and `cache_memory2()`, objects older than a
specified age can be retired from the cache. I.e. if they have not been
read or written more recently than the specified time, they will be
deleted.

``` r
memoised_rnorm <- memoise::memoise(rnorm, cache = memoisetools::cache_memory2()) 

memoised_rnorm(1) # stored in cache. 
#> [1] 0.1004836
memoised_rnorm(2) # stored in cache
#> [1] -0.23166245  0.05509139
Sys.sleep(1)      # wait a little bit
memoised_rnorm(1) # recent access to this cached data means it won't be expired
#> [1] 0.1004836

# The following expiry will only delete the cached result for `memoised_rnorm(2)`
# as it has not been read/written in over 1 second
memoisetools::expire_cache(memoised_rnorm, age_in_seconds = 1, verbose = TRUE)
#> cache_memory2: Expired 1 objects

memoised_rnorm(1) # this result is still in the cache
#> [1] 0.1004836
memoised_rnorm(2) # this is a fresh result as the cached version was removed
#> [1] -0.08105522  0.35333986
```

## `memoise_with_result_size_limit()`

This is a replacement for `memoise::memoise()` which places a limit on
how large an object can be before it is no longer stored in the cache
(but simply recalculated each time).

By default, `memoise::memoise()` will store all results regardless of
size. This works for the majority of cases where you have enough memory
and results are never too large.

For the problem I was working on, the function produced many small
results and a few very very large results (greater than 2GB is size). If
all the big results were cached I’d run out of memory\!

In the following example, results over 1000 bytes will not be
cached.

``` r
memoised_rnorm <- memoisetools::memoise_with_result_size_limit(rnorm, result_size_limit = 1000)

memoised_rnorm(1) # small enough to cache
#> [1] -1.496179
memoised_rnorm(1) # getting cached result
#> [1] -1.496179

head(memoised_rnorm(1000)) # too big to be cached
#> [1] -2.1370419  0.4210523  0.6454660  1.5794866  1.4090496  1.9648221
head(memoised_rnorm(1000)) # so each run produces fresh result
#> [1] -0.41789871  0.60986783  0.04766711 -0.28903793  0.14967057  0.05247167
```

## `memoise_with_mixed_backend()`

This is an adjusted version of `memoise::memoise()` which requires
**two** caches to be set, along with a **size limit**. Objects smaller
than the size limit go to the first cache, and objects larger than the
size limit go to the second cache.

This allows you to cache small results in memory, and send large results
to the filesystem, s3 or google cloud storage.

``` r
memoised_rnorm <- memoisetools::memoise_with_mixed_backend(
  rnorm,
  cache1 = memoisetools::cache_memory2(),
  cache2 = memoisetools::cache_filesystem2(),
  result_size_limit = 1000
)

a <- memoised_rnorm(1) # These 3 results cached to memory
b <- memoised_rnorm(2)
c <- memoised_rnorm(3)

x <- memoised_rnorm(1000)  # These 2 results cached to filesystem
y <- memoised_rnorm(2000)

memoisetools::get_memoise_info(memoised_rnorm)
#> cache: memory, env: <environment>, algo: xxhash64, bytes: 1648, n: 3, has_timestamp: TRUE, compress: FALSE
#> cache: filesystem, path: /private/var/folders/5p/78cv9fvn4xn_rbgxpx51q5n80000gn/T/RtmpAu4OLY, algo: xxhash64, bytes: 23259, n: 2, has_timestamp: TRUE, compress: TRUE
```
