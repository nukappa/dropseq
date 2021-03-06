MixedSpeciesSample <- setClass(Class = "MixedSpeciesSample",
                         slots = c(species2 = "character"),
                         contains = "SingleSpeciesSample"
                         )

setMethod("initialize",
          "MixedSpeciesSample",
          function (.Object, species1="", species2="", cells=c(), genes=c(),
                    dge=data.frame()) {
            .Object@species1 = species1
            .Object@species2 = species2
            .Object@cells = names(dge)
            .Object@genes = rownames(dge)
            .Object@dge = dge
            .Object
          })

#' Split DGE by genes of species
#'
#' Splits the DGE of a \code{MixedSpeciesSample} into two \code{SingleSpeciesSample} DGEs.
#' The splitting is done by the prefixes of the gene names. If no prefixes are provided
#' the defaults are \code{hg_} for human and \code{mm_} for mouse respectively.
#'
#' @param object A \code{MixedSpeciesSample} object.
#' @param prefix1 The prefix of the gene names for species1.
#' @param prefix2 The prefix of the gene names for species2.
#' @return A list of \code{data.frames} corresponding to the genes of the two species.
setGeneric(name = "splitDgeByGenesOfSpecies",
           def = function(object, prefix1=NULL, prefix2=NULL) {
             standardGeneric("splitDgeByGenesOfSpecies")})
setMethod(f = "splitDgeByGenesOfSpecies",
          signature = "MixedSpeciesSample",
          function(object, prefix1, prefix2) {
            if (is.null(prefix1) & is.null(prefix2)) {
              if (object@species1 == "human" & object@species2 == "mouse") {
                object.species1 <- object@dge[grep("hg_", object@genes), ]
                rownames(object.species1) <- gsub("hg_", "", rownames(object.species1))
                object.species2 <- object@dge[grep("mm_", object@genes), ]
                rownames(object.species2) <- gsub("mm_", "", rownames(object.species2))
              }
              if (object@species1 == "melanogaster" & object@species2 == "virilis") {
                object.species2 <- object@dge[grep("Dvir_", object@genes), ]
                object.species1 <- object@dge[setdiff(1:(length(object@genes)),
                                                      grep("Dvir_", object@genes)), ]
              }
            }
            else {
              object.species1 <- object@dge[grep(prefix1, object@genes), ]
              rownames(object.species1) <- gsub(prefix1, "", rownames(object.species1))
              object.species2 <- object@dge[grep(prefix2, object@genes), ]
              rownames(object.species2) <- gsub(prefix2, "", rownames(object.species2))
            }
            return (list(object.species1, object.species2))
          })

#' Classify cells to species
#'
#'
#' Classify the cells to species according to the transcripts they express.
#' The differentiation of species is performed internally and according to
#' the \code{species1} and \code{species2} labels of the sample. If the
#' classificiation is not confident enough, the cell is characterized as doublet.
#'
#' @param object A \code{MixedSpeciesSample} object.
#' @param threshold The threshold which the ratio of transcripts of one species
#' over the other has to surpass in order to succesfully assign a cell to a species.
#' Below that threshold the cell is characterized as a doublet.
#' @param min.trans The minimum number of transcripts (UMIs) required for a cell.
#' @return A \code{data.frame} containing the cell barcodes, the number of transcripts
#' per species and the characterization of the cell.
setGeneric("classifyCellsAndDoublets",
           function(object, threshold=0.9, min.trans=500) {
             standardGeneric("classifyCellsAndDoublets")})
setMethod("classifyCellsAndDoublets",
          "MixedSpeciesSample",
          function(object, threshold, min.trans) {
            object.species1 <- splitDgeByGenesOfSpecies(object)[[1]]
            object.species2 <- splitDgeByGenesOfSpecies(object)[[2]]

            df <- data.frame("cell" = names(object@dge),
                             "s1" = as.vector(colSums(object.species1)),
                             "s2" = as.vector(colSums(object.species2)),
                             "species" = "", stringsAsFactors = F)
            for (i in 1:dim(df)[1]) {
               if (df$s1[i] + df$s2[i] < min.trans) {
                 df$species[i] = "undefined"
                 next
               }
              if (df$s1[i] > df$s2[i] & df$s1[i]/(df$s1[i] + df$s2[i]) > threshold) {
                df$species[i] = object@species1
                next
              }
              if (df$s2[i] > df$s1[i] & df$s2[i]/(df$s1[i] + df$s2[i]) > threshold) {
                df$species[i] = object@species2
                next
                }
              df$species[i] = "mixed"
            }
            names(df) <- c("cell", object@species1, object@species2, "species")

            return (df)
          })

#' Split DGE by genes and cells of species
#'
#' @param object A \code{MixedSpeciesSample} object.
#' @param threshold The threshold which the ratio of transcripts of one species
#' over the other has to surpass in order to succesfully assign a cell to a species.
#' @return A list \code{data.frames} representing the DGEs for each species.
setGeneric("splitDgeByGenesAndCellsOfSpecies",
           function(object, threshold=0.9) {
             standardGeneric("splitDgeByGenesAndCellsOfSpecies")})
setMethod("splitDgeByGenesAndCellsOfSpecies",
          "MixedSpeciesSample",
          function(object, threshold) {
            split.dge <- splitDgeByGenesOfSpecies(object)

            object.species1 <- split.dge[[1]]
            object.species2 <- split.dge[[2]]

            df <- classifyCellsAndDoublets(object, threshold)

            object.species1 <- object.species1[, df[df$species == object@species1, ]$cell]
            object.species2 <- object.species2[, df[df$species == object@species2, ]$cell]

            object.species1 <- object.species1[which(rowSums(object.species1) != 0), ]
            object.species2 <- object.species2[which(rowSums(object.species2) != 0), ]

            return (list(object.species1, object.species2))
          })

#' Separate the mixed species sample into two single species samples
#'
#' @param object A \code{MixedSpeciesSample} object.
#' @param threshold The threshold which the ratio of transcripts of one species
#' over the other has to surpass in order to succesfully assign a cell to a species.
#' @return A list of two \code{SingleSpeciesSample} objects.
setGeneric("splitMixedSpeciesSampleToSingleSpecies",
           function(object, threshold=0.9) {
             standardGeneric("splitMixedSpeciesSampleToSingleSpecies")})
setMethod("splitMixedSpeciesSampleToSingleSpecies",
          "MixedSpeciesSample",
          function(object, threshold) {
            splitted.species <- splitDgeByGenesAndCellsOfSpecies(object, threshold)
            s1 <- new("SingleSpeciesSample",
                      species1 = object@species1,
                      cells = object@cells,
                      genes = rownames(splitted.species[[1]]),
                      dge = splitted.species[[1]])
            s2 <- new("SingleSpeciesSample",
                      species1 = object@species2,
                      cells = object@cells,
                      genes = rownames(splitted.species[[2]]),
                      dge = splitted.species[[2]])
            return (list(s1, s2))
          })

setMethod("computeGenesPerCell",
          "MixedSpeciesSample",
          function(object, min.umis, threshold=0.9) {
            return(rbind.fill(lapply(splitMixedSpeciesSampleToSingleSpecies(object, threshold),
                                     computeGenesPerCell, min.umis=min.umis)))
          })

setMethod("computeTranscriptsPerCell",
          "MixedSpeciesSample",
          function(object, threshold=0.9) {
            return (rbind.fill(lapply(splitMixedSpeciesSampleToSingleSpecies(object, threshold),
                                      computeTranscriptsPerCell)))
          })

setMethod("removeCells",
          "MixedSpeciesSample",
          function(object, cells) {
            return (new("MixedSpeciesSample", species1=object@species1, species2=object@species2,
                        dge=removeCells(object@dge, cells)))
          })

setMethod("removeLowQualityCells",
          "MixedSpeciesSample",
          function(object, min.genes) {
            return (new("MixedSpeciesSample", species1=object@species1, species2=object@species2,
                        dge=removeLowQualityCells(object@dge, min.genes)))
          })

setMethod("keepBestCells",
          "MixedSpeciesSample",
          function(object, num.cells, min.num.trans) {
            return (new("MixedSpeciesSample", species1=object@species1, species2=object@species2,
                        dge=keepBestCells(object@dge, num.cells, min.num.trans)))
          })

setMethod("removeLowQualityGenes",
          "MixedSpeciesSample",
          function(object, min.cells) {
            return (new("MixedSpeciesSample", species1=object@species1, species2=object@species2,
                        dge=removeLowQualityGenes(object@dge, min.cells)))
          })

#' List cells that are candidates for collapsing.
#'
#' Identify and list cells which share 11 bases in their barcodes and only the last
#' one is different. The cells are marked as candidates if and only if they're classified
#' as belonging to the same species.
#' @param A \code{MixedSpeciesSample} object.
setMethod("listCellsToCollapse",
          "MixedSpeciesSample",
          function (object, threshold=0.9) {
            return(unlist(lapply(splitMixedSpeciesSampleToSingleSpecies(object, threshold),
                                 listCellsToCollapse), recursive = F))
          })

setMethod("collapseCellsByBarcode",
          "MixedSpeciesSample",
          function(object, threshold=0.9) {
            listOfCells <- listCellsToCollapse(object, threshold)
            if (length(listOfCells) == 0) {
              return(object)
            }

            for (index in 1:length(listOfCells)) {
              object@dge <- cbind(object@dge, rowSums(object@dge[, listOfCells[[index]]]))
            }
            object@dge <- object@dge[, !names(object@dge) %in% unlist(listOfCells)]

            names(object@dge)[(length(names(object@dge)) - length(listOfCells)
                               + 1):length(names(object@dge))] <- unlist(listOfCells)[seq(1, length(unlist(listOfCells)), 2)]
            object@cells <- names(object@dge)
            return (object)
          })

#' Compare gene expression levels between two mixed species samples
#'
#' @param object1 A \code{MixedSpeciesSample} object.
#' @param object2 A \code{MixedSpeciesSample} object.
#' @param threshold1 The threshold for the firs sample.
#' @param threshold2 The threshold for the second sample.
#' @return A plot comparing the gene expression levels by species.
setMethod("compareGeneExpressionLevels",
          "MixedSpeciesSample",
          function(object1, object2, threshold1, threshold2, name1="sample1", name2="sample2") {
            object1.species1 <- splitDgeByGenesAndCellsOfSpecies(object1, threshold1)[[1]]
            object1.species2 <- splitDgeByGenesAndCellsOfSpecies(object1, threshold1)[[2]]
            object2.species1 <- splitDgeByGenesAndCellsOfSpecies(object2, threshold2)[[1]]
            object2.species2 <- splitDgeByGenesAndCellsOfSpecies(object2, threshold2)[[2]]

            common.genes.species1 <- intersect(row.names(object1.species1), row.names(object2.species1))
            common.genes.species2 <- intersect(row.names(object1.species2), row.names(object2.species2))

            object1.species1 <- object1.species1[row.names(object1.species1) %in% common.genes.species1, ]
            object1.species2 <- object1.species2[row.names(object1.species2) %in% common.genes.species2, ]
            object2.species1 <- object2.species1[row.names(object2.species1) %in% common.genes.species1, ]
            object2.species2 <- object2.species2[row.names(object2.species2) %in% common.genes.species2, ]

            object1.species1 <- max(colSums(object1.species1)) * sweep(object1.species1, MARGIN=2,
                                                                       FUN='/', colSums(object1.species1))
            object1.species2 <- max(colSums(object1.species2)) * sweep(object1.species2, MARGIN=2,
                                                                       FUN='/', colSums(object1.species2))
            object2.species1 <- max(colSums(object2.species1)) * sweep(object2.species1, MARGIN=2,
                                                                       FUN='/', colSums(object2.species1))
            object2.species2 <- max(colSums(object2.species2)) * sweep(object2.species2, MARGIN=2,
                                                                       FUN='/', colSums(object2.species2))

            big.df <- data.frame("genes" = c(common.genes.species1, common.genes.species2),
                                 "sample1" = c(log2(rowSums(object1.species1)+1),
                                               log2(rowSums(object1.species2)+1)),
                                 "sample2" = c(log2(rowSums(object2.species1)+1),
                                               log2(rowSums(object2.species2)+1)),
                                 "species" = c(rep(object1@species1, length(common.genes.species1)),
                                               rep(object1@species2, length(common.genes.species2))))

            cor.species1 <- signif(cor(big.df$sample1[big.df$species == object1@species1],
                                       big.df$sample2[big.df$species == object1@species1],
                                       method="pearson"), 2)

            cor.species2 <- signif(cor(big.df$sample1[big.df$species == object1@species2],
                                       big.df$sample2[big.df$species == object1@species2],
                                       method="pearson"), 2)

            levels(big.df$species) <- c(paste0(object1@species1, " (R=", cor.species1, ")"),
                                        paste0(object1@species2, " (R=", cor.species2, ")"))

            comp.plot <- (ggplot(data = big.df, aes(x = sample1, y = sample2))
                          + xlab(paste0(expression(log2), " (ATPM+1) [", name1, "]"))
                          + ylab(paste0(expression(log2), " (ATPM+1) [", name2, "]"))
                          + geom_point(aes(col=species), alpha = 1, size = 2)
                          + facet_grid(~ species, labeller = ) + guides(col = F)
                          + theme_minimal() + plotCommonGrid + plotCommonTheme
                          + theme(axis.ticks.y = element_blank(),
                                  panel.grid.major = element_blank(),
                                  panel.border = element_rect(colour = "black", fill=NA, size=1)))

            return (comp.plot)
          })
