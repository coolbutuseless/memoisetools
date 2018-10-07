
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' In Memory Cache with last access timestamp recorded for each object
#'
#' A cache in memory, that lasts only in the current R session.
#'
#' This function differs from \code{memoise::cache_memory} in a number of ways:
#'
#' \itemize{
#'   \item{timestamping}  {Each get/set to the cache is timestamped so that the
#'        last access time for every cached object is known}
#'   \item{expiry}  {The addition of timestamps allows for expiring objects older
#'        than a certain age. See the function \code{memoisetools::expire_cache}}
#'   \item{faster default hasing algo}  {Use \code{xxhash64} rather than \code{sha512}}
#' }
#'
#' @param algo The hashing algorithm used for the cache, see
#' \code{\link[digest]{digest}} for available algorithms.
#'
#' @export
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
cache_memory2 <- function(algo = "xxhash64") {

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Setting up cache
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  last_access_time <- NULL
  cache            <- NULL


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Resetting the cache
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  cache_reset <- function() {
    cache            <<- new.env(TRUE, emptyenv())
    last_access_time <<- new.env(TRUE, emptyenv())
  }


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Adding something to the cache
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  cache_set <- function(key, value) {
    assign(key, as.numeric(Sys.time()), envir = last_access_time)
    assign(key, value                 , envir = cache)
  }


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Fetching something from the cache
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  cache_get <- function(key) {
    assign(key, as.numeric(Sys.time()), envir = last_access_time)
    get(key, envir = cache, inherits = FALSE)
  }


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Is key in cache?
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  cache_has_key <- function(key) {
    exists(key, envir = cache, inherits = FALSE)
  }


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Remove objects from the cache which are older than the given age_in_seconds
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  cache_expire <- function(age_in_seconds, verbose = FALSE) {
    time_now <- as.numeric(Sys.time())
    remove   <- vapply(last_access_time, function(x) {(time_now - x) > age_in_seconds}, logical(1))
    if (any(remove)) {
      remove_names <- names(remove)[remove]
      rm(list=remove_names, envir=last_access_time)
      rm(list=remove_names, envir=cache)
      if (verbose) {
        message("cache_memory2: Expired ", length(remove_names), " objects")
      }
    } else {
      if (verbose) {
        message("cache_memory2: No objects in cache exceeded he expiry age")
      }
    }
  }


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Initialise the cache
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  cache_reset()


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Return the function list for this cache
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  list(
    digest  = function(...) digest::digest(..., algo = algo),
    reset   = cache_reset,
    set     = cache_set,
    get     = cache_get,
    expire  = cache_expire,
    has_key = cache_has_key,
    keys    = function() ls(cache)
  )
}














