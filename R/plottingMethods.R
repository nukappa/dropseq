plotCommonTheme <- theme(text = element_text(size = 24),
                         axis.title.y = element_text(vjust = 1.2),
                         axis.title.x = element_text(vjust = 0))

plotCommonGrid <- theme(panel.grid.major.x = element_blank(),
                        panel.grid.major.y = element_line(colour = "grey50", size = 0.1),
                        panel.grid.minor = element_blank())

#' Violin plot of an attribute
#'
#' @param object A \code{data.frame} such as the outputs of \code{computeGenesPerCell}
#' and \code{computeTranscriptsPerCell}.
#' @param attribute A \code{charracter string} describing the attribute.
setGeneric(name = "plotViolin",
           def = function(object, attribute="ATTRIBUTE MISSING") {standardGeneric("plotViolin")})
setMethod(f = "plotViolin",
          signature = "data.frame",
          function(object, attribute) {
            v <- (ggplot(object, aes_string(x = names(object)[3], y = names(object)[2],
                                            fill = names(object)[3]))
                  + geom_violin(size=1)
                  + scale_fill_grey(start = 0.9, end = 0.5)
                  + scale_y_continuous(limits = c(0, max(object[, 2])))
                  + ylab(paste("Number of", attribute)) + xlab("")
                  + geom_boxplot(width = 0.3, outlier.size = 0.5) + guides(fill = F)
                  + theme_minimal() + plotCommonTheme
                  + theme(panel.border = element_rect(colour = "black", fill=NA, size=1),
                          panel.grid.major = element_blank()))
            return (v)
          })

#' Histogram plot of an attribute
#'
#' @param object A \code{data.frame} such as the outputs of \code{computeGenesPerCell}
#' and \code{computeTranscriptsPerCell}.
#' @param attribute A \code{charracter string} describing the attribute.
setGeneric(name = "plotHistogram",
           def = function(object, attribute="ATTRIBUTE MISSING") {standardGeneric("plotHistogram")})
setMethod(f = "plotHistogram",
          signature = "data.frame",
          function(object, attribute) {
            plotLocalCommon <- (theme_minimal() + plotCommonGrid + plotCommonTheme
                                + theme(axis.text.y = element_blank(), axis.ticks = element_blank()))

            species1 = names(table(object$species))[1]
            g.sp1 <- (ggplot(object[object$species == species1, ], aes(counts))
                      + xlab(paste(species1, attribute, "per", species1, "cell")) + ylab("")
                      + geom_histogram(aes(y = ..density..), fill = "steelblue", alpha = 0.8)
                      + geom_density(col = "black", size = 1) + plotLocalCommon)

            if (length(table(object$species)) > 1) {
              species2 = names(table(object$species))[2]
              g.sp2 <- (ggplot(object[object$species == species2, ], aes(counts))
                        + xlab(paste(species2, attribute, "per", species2 , "cell")) + ylab("")
                        + geom_histogram(aes(y = ..density..), fill = "firebrick", alpha = 0.8)
                        + geom_density(col = "black", size = 1) + plotLocalCommon)
              return (grid.arrange(g.sp1, g.sp2, ncol = 2))
            }
            return (g.sp1)
          })

#' Plots the knee plot
#'
#' Plots the cumulative fraction of reads against cell barcodes (in descending
#' number of reads). This way provides a heuristic computation of the number of
#' STAMPS in the sample (see computational cookbook from Macosko et. al. 2015
#' for further details and reasoning).
#'
#' @param object A \code{data.frame} read from out_readcounts.txt.gz
#' @param cutoff The number of cells to take into account (default is 10000).
#' @param draw.knee.point Whether to annotate the knee point or not.
setGeneric("plotCumulativeFractionOfReads",
           function(object, cutoff=10000, draw.knee.point=TRUE) {
             standardGeneric("plotCumulativeFractionOfReads")})
setMethod("plotCumulativeFractionOfReads",
          "data.frame",
          function(object, cutoff, draw.knee.point) {
            df <- data.frame("cum"=cumsum(object[1:cutoff, 1])/max(cumsum(object[1:cutoff, 1])),
                             "cells"=1:cutoff)

            knee.point <- estimateCellNumber(object[1:cutoff, 1], max.cells=cutoff)

            g <- (ggplot(df, aes(cells, cum)) + geom_line(col="steelblue", size=1.25) + theme_minimal()
            + scale_x_continuous(expand=c(0.015, 0))
            + scale_y_continuous(expand = c(0.01, 0)) + ylab("Cumulative fraction of reads")
            + xlab("Cell barcodes (descending number of reads)")
            + theme(text=element_text(size=24),
                    plot.margin = unit(c(1, 1 , 0.5, 0.5), "cm"),
                    panel.border = element_rect(colour = "black", fill=NA, size=1),
                    panel.grid.major = element_blank()))
            if (draw.knee.point) {
              g <- (g + geom_vline(xintercept = knee.point, col='red', size=1)
                    + ggtitle(paste0('Number of STAMPS: ', knee.point))
                    + theme(title = element_text(size=16)))
            }
            return (g)
          })

setGeneric("plotHistogramCorrelations",
           function(object, xlab="", col="steelblue") {
             standardGeneric("plotHistogramCorrelations")})
setMethod("plotHistogramCorrelations",
          "vector",
          function(object, xlab, col) {
            g <- (ggplot(data.frame("correlation"=object), aes(correlation))
                  + geom_histogram(binwidth=0.005, fill=col)
                  + ylab("") + xlab(xlab) + theme_minimal() + plotCommonGrid + plotCommonTheme)
            return (g)
          })

#' Heatmap of the correlation matrix for pairs of cells.
#'
#' @param object A \code{data.frame} representing the DGE matrix.
setGeneric(name = "plotHeatmapCorrelationMatrixDGE",
           def = function(object) {standardGeneric("plotHeatmapCorrelationMatrixDGE")})
setMethod(f = "plotHeatmapCorrelationMatrixDGE",
          signature = "data.frame",
          function(object) {
            heatmap_palette <- colorRampPalette(c("#3794bf", "#FFFFFF", "#df8640"))
            heatmap.2(cor(as.matrix(object)), trace = "none", labRow = F,
                      labCol = F, dendrogram = "row", col=heatmap_palette(20))
          })

#' Plot mitochondrial content
#'
#' Violin plots of mitochondrial content of one or more samples.
#'
#' @param object A list of mitochondrial content percentages, as computed by the
#' \code{ComputeMitochondrialContent} function.
#' @param log_scale Should the y-axis be in the log-scale?
#' @param sample_names The sample names
setGeneric("plotMitochondrialContent",
           function(object, log_scale=TRUE, sample_names=paste0('sample', 1:length(object))) {
             standardGeneric("plotMitochondrialContent")
           })
setMethod("plotMitochondrialContent",
          "list",
          function(object, log_scale, sample_names) {
            object <- lapply(object, as.numeric)
            mtrx <- matrix(data=NA, nrow = max(sapply(object, length)), ncol = length(object))
            df <- data.frame(mtrx)
            names(df) <- sample_names

            for (sample in 1:length(object)) {
              df[1:length(object[[sample]]), sample] <- object[[sample]]
            }

            g <- (ggplot(melt(df), aes(variable, value)) + geom_violin(fill="grey")
                  + ylab("% of cytoplasmic reads") + xlab("") + theme_minimal()
                  + plotCommonTheme + plotCommonGrid
                  + geom_boxplot(width = 0.1, outlier.size = 0.5))
            if (log_scale) {g <- g + scale_y_log10()}
            return (g)
          })

#' Plot separation of species
#'
#' Scatter plot of all cells by transcripts of species (a.k.a. barnyard plot). Species
#' and doublets are separated by different colors.
#'
#' @param object A \code{data.frame} produced by the \code{classifyCellsAndDoublets}
#' function.
setGeneric(name = "plotCellTypes",
           def = function(object) {standardGeneric("plotCellTypes")})
setMethod(f = "plotCellTypes",
          signature = "data.frame",
          function(object) {
            cell.types.plot <- (ggplot(data = object, aes_string(names(object)[2], names(object)[3],
                                                                 col = names(object)[4]))
                                + geom_point(size = 4, alpha = 0.4) + theme_classic()
                                + xlab(paste(names(object)[2], "transcripts (UMIs)"))
                                + ylab(paste(names(object)[3], "transcripts (UMIs)"))
                                + scale_color_manual(values = c("steelblue", "purple", "firebrick", "grey"),
                                                     labels = c(paste0(names(object)[2], " (",
                                                                       table(object$species)[names(object)[2]], ")"),
                                                                paste0("mixed (", table(object$species)['mixed'], ")"),
                                                                paste0(names(object)[3], " (",
                                                                       table(object$species)[names(object)[3]], ")"),
                                                                paste0("low UMIs", " (",
                                                                       table(object$species)['undefined'], ")")))
                                + plotCommonTheme
                                + scale_x_continuous(expand=c(0.015, 0), limits = c(0, max(object[2:3])+2500))
                                + scale_y_continuous(expand=c(0.03, 0), limits = c(0, max(object[2:3])+2500))
                                + guides(col = guide_legend(override.aes = list(alpha=1)))
                                + theme(legend.title = element_blank(),
                                        legend.position = c(0.85, 0.85),
                                        axis.line.x = element_line(colour = "black"),
                                        axis.line.y = element_line(colour = "black"),
                                        plot.margin = unit(c(0.5, 0.5, 0.5, 0.5), "cm"),
                                        panel.border = element_rect(colour = "black", fill=NA, size=1)))
            return(cell.types.plot)
          })
