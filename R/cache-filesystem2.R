
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Filesystem Cache with last access timestamp recorded for each object
#'
#' Use a cache on the local filesystem that will persist between R sessions.
#'
#' This function differs from \code{memoise::cache_filesystem} in a number of ways:
#'
#' \itemize{
#'   \item{use a tempdir if none specified}
#'   \item{absolute path}  {Full absolute path to cache is stored, even if
#'        initialised with a relative path}
#'   \item{compression}  {By default objects are compressed using gzip compression.
#'        See the \code{compress} argument}
#'   \item{timestamping}  {Each get/set to the cache is timestamped so that the
#'        last access time for every cached object is known}
#'   \item{expiry}  {The addition of timestamps allows for expiring objects older
#'        than a certain age. See the function \code{memoisetools::expire_cache}}
#'   \item{faster key lookup}  {the \code{has_key} method now uses the timestamp cache
#'        to determine if a given key exists or not. This makes it faster
#'        to check if a key exists, but will cause an error if they file doesn't
#'        actually exist on the filesystem (e.g. if you've deleted the file manually)}
#' }
#'
#' @param path Directory in which to store cached items.
#' @param compress option passed to \code{saveRDS} i.e. TRUE, FALSE, 'gzip',
#'        'bzip2', 'xz', default: FALSE.
#' @inheritParams cache_memory2
#'
#' @export
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
cache_filesystem2 <- function(path = tempdir(), algo = "xxhash64", compress=TRUE) {

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Setting up cache.
  # Ensure path is absolute path
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  last_access_time <- new.env(TRUE, emptyenv())
  if (!dir.exists(path)) {
    dir.create(path, showWarnings = FALSE)
  }
  path <- normalizePath(path)

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Resetting the cache
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  cache_reset <- function() {
    last_access_time <<- new.env(TRUE, emptyenv())
    cache_files <- list.files(path, full.names = TRUE)
    suppressWarnings({
      file.remove(cache_files)
    })
  }


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Adding something to the cache
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  cache_set <- function(key, value) {
    assign(key, as.numeric(Sys.time()), envir = last_access_time)
    saveRDS(value, file = file.path(path, key), compress = compress)
  }


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Fetching something from the cache
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  cache_get <- function(key) {
    assign(key, as.numeric(Sys.time()), envir = last_access_time)
    readRDS(file = file.path(path, key))
  }


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # avoid a filesystem access here by just checking if the key is timestamped
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  cache_has_key <- function(key) {
    # file.exists(file.path(path, key))
    !is.null(last_access_time[[key]])
  }


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Remove objects from the cache which are older than the given age_in_seconds
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  cache_expire <- function(age_in_seconds, verbose=FALSE) {
    time_now <- as.numeric(Sys.time())
    remove   <- vapply(last_access_time, function(x) {(time_now - x) > age_in_seconds}, logical(1))
    if (any(remove)) {
      remove_names <- names(remove)[remove]
      rm(list=remove_names, envir=last_access_time)
      file.remove(file.path(path, remove_names))
      if (verbose) {
        message("cache_filesystem2: Expired ", length(remove_names), " objects")
      }
    } else {
      if (verbose) {
        message("cache_filesystem2: No objects in cache exceeded the expiry age")
      }
    }
  }


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Initialise 'last_access_time' to the current time for all files
  # in the memoise path which match the length of the digest
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  filename_length <- nchar(digest::digest(1, algo=algo))
  all_files       <- list.files(path, full.names = TRUE)
  cache_files     <- purrr::keep(all_files, ~nchar(basename(.x)) == filename_length)

  for (filename in cache_files) {
    last_access_time[[basename(filename)]] <- as.numeric(Sys.time())
  }


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
    keys    = function() list.files(path)
  )
}



