context("result-size-limit")


test_that("result size limit works", {

  r <- memoisetools::memoise_with_result_size_limit(rnorm, result_size_limit = 1000)

  # Small results are cached
  N <- 2
  small_result <- r(N)
  expect_identical(small_result, r(N))
  expect_identical(small_result, r(N))


  # Large results are not cached
  N <- 2000
  large_result <- r(N)
  expect_false(identical(large_result, r(N)))
  expect_false(identical(large_result, r(N)))

})
