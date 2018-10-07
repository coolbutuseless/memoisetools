
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# This function is a clone of the private function in
# memoise v1.1.0.9000 (20180930)
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
validate_formulas <- function(...) {
  format.name <- function(x, ...) format(as.character(x), ...)
  is_formula <- function(x) {
    if (is.call(x) && identical(x[[1]], as.name("~"))) {
      if (length(x) > 2L) {
        stop("`x` must be a one sided formula [not ", format(x), "].", call. = FALSE)
      }
    } else {
      stop("`", format(x), "` must be a formula.", call. = FALSE)
    }
  }

  dots <- eval(substitute(alist(...)))
  lapply(dots, is_formula)
}