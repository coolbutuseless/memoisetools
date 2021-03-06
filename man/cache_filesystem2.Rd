% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/cache-filesystem2.R
\name{cache_filesystem2}
\alias{cache_filesystem2}
\title{Filesystem Cache with last access timestamp recorded for each object}
\usage{
cache_filesystem2(path = tempdir(), algo = "xxhash64",
  compress = TRUE)
}
\arguments{
\item{path}{Directory in which to store cached items.}

\item{algo}{The hashing algorithm used for the cache, see
\code{\link[digest]{digest}} for available algorithms.}

\item{compress}{option passed to \code{saveRDS} i.e. TRUE, FALSE, 'gzip',
'bzip2', 'xz', default: FALSE.}
}
\description{
Use a cache on the local filesystem that will persist between R sessions.
}
\details{
This function differs from \code{memoise::cache_filesystem} in a number of ways:

\itemize{
  \item{use a tempdir if none specified}
  \item{absolute path}  {Full absolute path to cache is stored, even if
       initialised with a relative path}
  \item{compression}  {By default objects are compressed using gzip compression.
       See the \code{compress} argument}
  \item{timestamping}  {Each get/set to the cache is timestamped so that the
       last access time for every cached object is known}
  \item{expiry}  {The addition of timestamps allows for expiring objects older
       than a certain age. See the function \code{memoisetools::expire_cache}}
  \item{faster key lookup}  {the \code{has_key} method now uses the timestamp cache
       to determine if a given key exists or not. This makes it faster
       to check if a key exists, but will cause an error if they file doesn't
       actually exist on the filesystem (e.g. if you've deleted the file manually)}
}
}
