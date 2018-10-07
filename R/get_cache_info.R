
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Sum of the size of all files in a directory which have the given filename_length
#'
#' This function is used to get the filenames which are probably matches for the
#' current digest signature, as given by the filename_length
#'
#' @param path path to cache directory
#' @param filename_length length of filename of files to consider
#'
#' @return list with number of objects (n) and total size of objects (bytes)
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
get_cache_dir_info <- function(path, filename_length) {
  all_files <- list.files(path, full.names = TRUE)
  cache_files <- purrr::keep(all_files, ~nchar(basename(.x)) == filename_length)
  list(n = length(cache_files), bytes = sum(file.size(cache_files)))
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Get information about the memory or filesystem cache
#'
#' 'gcs' and 'aws' caches not handled yet.
#'
#' @param cache_funclist the function list returned by a call to
#'                       memoise::cache_memory() or memoise::cache_filesystem()
#'
#' @return named list of information: \itemize{
#' \item{cache} - {Cache type. Either 'memory', 'filesystem' or 'gcs or aws'}
#' \item{env} - {For 'memory' cache, the R environment in which objects are stored}
#' \item{path} - {For 'filesystem' caches, the path to the cache directory}
#' \item{cache_name} - {For 'gcs or aws' caches, the name of the cache}
#' \item{algo} - {Hashing algorithm for creating keys}
#' \item{bytes} - {Size (in bytes) of the cache}
#' \item{n} - {Number of objects in the cache}
#' \item{has_timestamp} - {Does the cache include timestamp information?}
#' \item{compress} - {Value for 'compress' variable}
#' }
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
get_cache_info <- function(cache_funclist) {
  stopifnot(is.list(cache_funclist))
  stopifnot('set' %in% names(cache_funclist))

  # Within the `_cache` environment, select the `set()` function and get
  # its environment
  env_of_cachefuncs <- environment(cache_funclist$set)

  # Now we can look up things about the environment in which the cache
  # get/set/reset/keys functions are set.
  memory_cache   <- rlang::env_get(env_of_cachefuncs, 'cache'           , default = NULL)
  cache_path     <- rlang::env_get(env_of_cachefuncs, 'path'            , default = NULL)
  cache_name     <- rlang::env_get(env_of_cachefuncs, 'cache_name'      , default = NULL)
  compress       <- rlang::env_get(env_of_cachefuncs, 'compress'        , default = FALSE)

  has_timestamp  <- exists('last_access_time', envir = env_of_cachefuncs, inherits = FALSE)


  if (!is.null(memory_cache) && is.environment(memory_cache)) {
    list(
      cache         = "memory",
      env           = memory_cache,
      algo          = env_of_cachefuncs$algo,
      bytes         = pryr::object_size(memory_cache),
      n             = length(ls(memory_cache)),
      has_timestamp = has_timestamp,
      compress      = compress
    )
  } else if (!is.null(cache_path) && is.character(cache_path) && is.null(cache_name)) {
    signature_nchars <- nchar(cache_funclist$digest(1))
    cache_dir_info   <- get_cache_dir_info(cache_path, signature_nchars)
    list(
      cache         = "filesystem",
      path          = cache_path,
      algo          = env_of_cachefuncs$algo,
      bytes         = cache_dir_info$bytes,
      n             = cache_dir_info$n,
      has_timestamp = has_timestamp,
      compress      = compress
    )
  } else {
    list(
      cache         = "gcs or s3",
      cache_name    = cache_name,
      algo          = env_of_cachefuncs$algo,
      bytes         = NA_integer_,
      n             = NA_integer_,
      has_timestamp = has_timestamp,
      compress      = compress
    )
  }

}



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Get information about the cache/caches for a memoised function
#'
#' @param f memoised function
#' @param verbose print information about the caches
#'
#' @return (invisible) A list of lists of information for each cache used for memoisation
#'
#' \itemize{
#' \item{cache} - {Cache type. Either 'memory' or 'filesystem'}
#' \item{env} - {For 'memory' cache, the R environment in which objects are stored}
#' \item{path} - {For 'filesystem' caches, the path to the cache directory}
#' \item{algo} - {Hashing algorithm for creating keys}
#' \item{bytes} - {Size (in bytes) of the cache}
#' \item{n} - {Number of objects in the cache}
#' \item{has_timestamp} - {Does the cache include timestamp information?}
#' \item{compress} - {Value for 'compress' variable}
#' }
#'
#' @export
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
get_memoise_info <- function(f, verbose=TRUE) {
  stopifnot(is.memoised(f))

  # A memoised function has all the memoise/cache info in its environemnt
  env_of_f <- environment(f)

  # The `_cache` object is a list of functions as returned by a call
  # to `memoise::cache_memory()` et al
  cache_list <- env_of_f$`_cache`

  if ('set' %in% names(cache_list)) {
    # Single cache
    cache_funclist <- cache_list
    all_info <- list(get_cache_info(cache_funclist))
  } else {
    # multiple caches
    all_info <- purrr::map(cache_list, get_cache_info)
  }

  if (verbose) {
    for (info in all_info) {
      msg <- paste(names(info), info, sep=": ", collapse=", ")
      message(msg)
    }
  }

  invisible(all_info)
}


