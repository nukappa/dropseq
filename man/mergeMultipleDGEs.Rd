% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/Tools.R
\name{mergeMultipleDGEs}
\alias{mergeMultipleDGEs}
\title{Merge multiple samples into a big DGE matrix}
\usage{
mergeMultipleDGEs(object)
}
\arguments{
\item{object}{A \code{list} of DGEs.}
}
\value{
A \code{data.frame} containing all DGEs merged.
}
\description{
Merge the DGEs of multiple samples into a big one that can be used for
further analysis.
}
