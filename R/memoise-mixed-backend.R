

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' A version of 'memoise::memoise' which does not cache results above the specified size
#'
#' This version of memoise also tracks the last access time for each
#' cached result.
#'
#' @param f     Function of which to create a memoised copy.
#' @param ... optional variables specified as formulas with no RHS to use as
#' additional restrictions on caching. See Examples for usage.
#' @param envir Environment of the returned function.
#' @param cache1 Cache function 1 - must use the same algo as cache2
#' @param cache2 Cache function 2 - must use the same algo as cache1
#' @param result_size_limit maximum size (in bytes) of results stored in cache1.
#'        Results above this size are stored in cache2. Default: 1048576 bytes (1MB)
#'
#' @importFrom memoise cache_memory is.memoised
#' @importFrom digest digest
#' @importFrom stats setNames
#'
#' @export
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
memoise_with_mixed_backend <- function(f, ..., envir = environment(f),
                                       cache1 = cache_memory2(),
                                       cache2 = cache_filesystem2(),
                                       result_size_limit = 1048576L) {
  f_formals <- formals(args(f))
  if(is.memoised(f)) {
    stop("`f` must not be memoised.", call. = FALSE)
  }

  if (environment(cache1$digest)$algo != environment(cache2$digest)$algo) {
    stop("'algo' must be the same for the 2 caches")
  }

  validate_formulas(...)
  additional <- list(...)

  memo_f <- function(...) {
    mc <- match.call()
    encl <- parent.env(environment())
    called_args <- as.list(mc)[-1]

    # Formals with a default
    default_args <- Filter(function(x) !identical(x, quote(expr = )), as.list(formals()))

    # That has not been called
    default_args <- default_args[setdiff(names(default_args), names(called_args))]

    # Evaluate all the arguments
    args <- c(lapply(called_args, eval, parent.frame()),
              lapply(default_args, eval, envir = environment()))

    hash <- encl$`_cache`[[1L]]$digest(
      c(as.character(body(encl$`_f`)), args,
        lapply(encl$`_additional`, function(x) eval(x[[2L]], environment(x))))
    )

    if (encl$`_cache`[[1L]]$has_key(hash)) {
      res <- encl$`_cache`[[1L]]$get(hash)
    } else if (encl$`_cache`[[2L]]$has_key(hash)) {
      res <- encl$`_cache`[[2L]]$get(hash)
    } else {
      # modify the call to use the original function and evaluate it
      mc[[1L]] <- encl$`_f`
      res <- withVisible(eval(mc, parent.frame()))
      #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      # Select backend based upon object size.
      #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      if (pryr::object_size(res$value) < encl$`_result_size_limit`) {
        encl$`_cache`[[1]]$set(hash, res)
      } else {
        encl$`_cache`[[2]]$set(hash, res)
      }
    }

    if (res$visible) {
      res$value
    } else {
      invisible(res$value)
    }
  }
  formals(memo_f) <- f_formals
  attr(memo_f, "memoised") <- TRUE

  # This should only happen for primitive functions
  if (is.null(envir)) {
    envir <- baseenv()
  }

  memo_f_env <- new.env(parent = envir)

  memo_f_env$`_cache` <- list()
  memo_f_env$`_cache`[[1L]] <- cache1
  memo_f_env$`_cache`[[2L]] <- cache2
  memo_f_env$`_f` <- f
  memo_f_env$`_additional` <- additional
  memo_f_env$`_result_size_limit` <- result_size_limit
  environment(memo_f) <- memo_f_env

  class(memo_f) <- c("memoised", "function")

  memo_f
}




if (FALSE) {
  r <- memoisetools::memoise_with_mixed_backend(
    rnorm,
    cache1=memoisetools::cache_memory2(),
    cache2=memoisetools::cache_filesystem2()
  )

  r(1)
  head(r(1000))
  head(r(1001))
  head(r(1002))
  head(r(2e5))
  head(r(2e5))

  get_memoise_info(r)


}

