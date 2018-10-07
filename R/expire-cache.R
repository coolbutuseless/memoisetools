



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Delete objects in the cache older than the specified age
#'
#' @param f memoised function
#' @param age_in_seconds delete objects older than this age (in seconds)
#' @param verbose print information about the number of expired objects? default: FALSE
#'
#' @export
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
expire_cache <- function(f, age_in_seconds, verbose=FALSE) {
  stopifnot(is.memoised(f))

  cache_list <- environment(f)$`_cache`

  if ('expire' %in% names(cache_list)) {
    # Single cache in memoised functino
    cache_list$expire(age_in_seconds, verbose)
  } else if (!('set' %in% names(cache_list))) {
    # multiple caches
    for (cache_funclist in cache_list) {
      if ('expire' %in% names(cache_funclist)) {
        cache_funclist$expire(age_in_seconds, verbose)
      }
    }
  } else {
    message("No 'expire' method in current cache.")
  }
}
