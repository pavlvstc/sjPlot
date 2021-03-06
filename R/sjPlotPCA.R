#' @title Plot PCA results
#' @name sjp.pca
#'
#' @description Performs a principle component analysis on a data frame or matrix (with
#'                varimax or oblimin rotation) and plots the factor solution as ellipses or tiles. \cr \cr
#'                In case a data frame is used as argument, the cronbach's alpha value for
#'                each factor scale will be calculated, i.e. all variables with the highest
#'                loading for a factor are taken for the reliability test. The result is
#'                an alpha value for each factor dimension.
#'
#' @param plot.eigen If \code{TRUE}, a plot showing the Eigenvalues according to the
#'          Kaiser criteria is plotted to determine the number of factors.
#' @param type Plot type resp. geom type. May be one of following: \code{"circle"} or \code{"tile"}
#'          circular or tiled geoms, or \code{"bar"} for a bar plot. You may use initial letter only
#'          for this argument.
#'
#' @return (Invisibly) returns a \code{\link{structure}} with
#'          \itemize{
#'            \item the rotated factor loading matrix (\code{varim})
#'            \item the column indices of removed variables (for more details see next list item) (\code{removed.colindex})
#'            \item an updated data frame containing all factors that have a clear loading on a specific scale in case \code{data} was a data frame (See argument \code{fctr.load.tlrn} for more details) (\code{removed.df})
#'            \item the \code{factor.index}, i.e. the column index of each variable with the highest factor loading for each factor,
#'            \item the ggplot-object (\code{plot}),
#'            \item the data frame that was used for setting up the ggplot-object (\code{df}).
#'            }
#'
#' @inheritParams sjp.grpfrq
#' @inheritParams sjt.pca
#'
#' @examples
#' library(sjmisc)
#' data(efc)
#' # recveive first item of COPE-index scale
#' start <- which(colnames(efc) == "c82cop1")
#' # recveive last item of COPE-index scale
#' end <- which(colnames(efc) == "c90cop9")
#'
#' # manually compute PCA
#' pca <- prcomp(
#'   na.omit(efc[, start:end]),
#'   retx = TRUE,
#'   center = TRUE,
#'   scale. = TRUE
#' )
#' # plot results from PCA as circles, including Eigenvalue-diagnostic.
#' # note that this plot does not compute the Cronbach's Alpha
#' sjp.pca(pca, plot.eigen = TRUE, type = "circle", geom.size = 10)
#'
#' # use data frame as argument, let sjp.pca() compute PCA
#' sjp.pca(efc[, start:end])
#' sjp.pca(efc[, start:end], type = "tile")
#'
#'
#' @import ggplot2
#' @importFrom tidyr gather
#' @importFrom scales brewer_pal grey_pal
#' @importFrom stats na.omit prcomp varimax
#' @importFrom sjstats cronb
#' @importFrom psych principal
#' @export
sjp.pca <- function(data,
                    rotation = c("varimax", "oblimin"),
                    nmbr.fctr = NULL,
                    fctr.load.tlrn = 0.1,
                    plot.eigen = FALSE,
                    digits = 2,
                    title = NULL,
                    axis.labels = NULL,
                    type = c("bar", "circle", "tile"),
                    geom.size = .6,
                    geom.colors = "RdBu",
                    wrap.title = 50,
                    wrap.labels = 30,
                    show.values = TRUE,
                    show.cronb = TRUE) {
  # --------------------------------------------------------
  # check arguments
  # --------------------------------------------------------
  type <- match.arg(type)
  rotation <- match.arg(rotation)
  # --------------------------------------------------------
  # try to automatically set labels is not passed as argument
  # --------------------------------------------------------
  if (is.null(axis.labels) && is.data.frame(data)) {
    axis.labels <- unname(sjlabelled::get_label(data, def.value = colnames(data)))
  }
  # ----------------------------
  # set color palette
  # ----------------------------
  if (is.brewer.pal(geom.colors[1])) {
    geom.colors <- scales::brewer_pal(palette = geom.colors[1])(5)
  } else if (geom.colors[1] == "gs") {
    geom.colors <- scales::grey_pal()(5)
  }
  # ----------------------------
  # check if user has passed a data frame
  # or a pca object
  # ----------------------------
  if (inherits(data, "prcomp")) {
    pcadata <- data
    dataframeparam <- FALSE
  } else if (is.data.frame(data)) {
    pcadata <- stats::prcomp(stats::na.omit(data), retx = TRUE, center = TRUE, scale. = TRUE)
    dataframeparam <- TRUE
  }
  # ----------------------------
  # calculate eigenvalues
  # ----------------------------
  pcadata.eigenval <- pcadata$sdev ^ 2
  # ----------------------------
  # retrieve best amount of factors according
  # to Kaiser-critearia, i.e. factors with eigen value > 1
  # ----------------------------
  pcadata.kaiser <- which(pcadata.eigenval < 1)[1] - 1
  # ----------------------------
  # plot eigenvalues
  # ----------------------------
  if (plot.eigen) {
    # create data frame with eigen values
    mydat <- as.data.frame(cbind(xpos = seq_len(length(pcadata.eigenval)), eigen = pcadata.eigenval))
    # plot eigenvalues as line curve
    eigenplot <-
      # indicate eigen vlaues > 1
      ggplot(mydat, aes(x = .data$xpos, y = .data$eigen, colour = .data$eigen > 1)) +
        geom_line() + geom_point() +
        geom_hline(yintercept = 1, linetype = 2, colour = "grey50") +
        # print best number of factors according to eigen value
        annotate("text", label = sprintf("Factors: %i", pcadata.kaiser),
                 x = Inf, y = Inf, vjust = "top", hjust = "top") +
        scale_x_continuous(breaks = seq(1, nrow(mydat), by = 2)) +
        labs(title = NULL, y = "Eigenvalue", x = "Number of factors")
    plot(eigenplot)
    # print statistics
    message("--------------------------------------------")
    print(summary(pcadata))
    message("Eigenvalues:")
    print(pcadata.eigenval)
    message("--------------------------------------------")
  }
  # --------------------------------------------------------
  # varimax rotation, retrieve factor loadings
  # --------------------------------------------------------
  # check for predefined number of factors
  if (!is.null(nmbr.fctr) && is.numeric(nmbr.fctr)) pcadata.kaiser <- nmbr.fctr

  if (pcadata.kaiser < 2) {
    stop("Only one principal component extracted. Can't rotate loading matrices. You may use `nmbr.fctr` to extract more than one component.", call. = F)
  }

  # rotate matrix
  if (rotation == "varimax")
    pcadata.rotate <- varimaxrota(pcadata, pcadata.kaiser)
  else if (rotation == "oblimin")
    pcadata.rotate <- psych::principal(r = data, nfactors = pcadata.kaiser, rotate = "oblimin")

  # create data frame with factor loadings
  df <- as.data.frame(pcadata.rotate$loadings[, seq_len(ncol(pcadata.rotate$loadings))])
  # df <- as.data.frame(pcadata.varim$rotmat[, 1:pcadata.kaiser])
  # ----------------------------
  # check if user defined labels have been supplied
  # if not, use variable names from data frame
  # ----------------------------
  if (is.null(axis.labels)) axis.labels <- row.names(df)
  # ----------------------------
  # Prepare length of title and labels
  # ----------------------------
  # check length of diagram title and split longer string at into new lines
  if (!is.null(title)) title <- sjmisc::word_wrap(title, wrap.title)
  # check length of x-axis-labels and split longer strings at into new lines
  if (!is.null(axis.labels)) axis.labels <- sjmisc::word_wrap(axis.labels, wrap.labels)
  # --------------------------------------------------------
  # this function checks which items have unclear factor loadings,
  # i.e. which items do not strongly load on a single factor but
  # may load almost equally on several factors
  # --------------------------------------------------------
  getRemovableItems <- function(dataframe) {
    # clear vector
    removers <- c()
    # iterate each row of the data frame. each row represents
    # one item with its factor loadings
    for (i in seq_len(nrow(dataframe))) {
      # get factor loadings for each item
      rowval <- as.numeric(abs(df[i, ]))
      # retrieve highest loading
      maxload <- max(rowval)
      # retrieve 2. highest loading
      max2load <- sort(rowval, TRUE)[2]
      # check difference between both
      if (abs(maxload - max2load) < fctr.load.tlrn) {
        # if difference is below the tolerance,
        # remeber row-ID so we can remove that items
        # for further PCA with updated data frame
        removers <- c(removers, i)
      }
    }
    # return a vector with index numbers indicating which items
    # have unclear loadings
    return(removers)
  }
  # --------------------------------------------------------
  # this function retrieves a list with the column index ("factor" index)
  # where each case of the data frame has its highedt factor loading.
  # So we know to which "group" (factor dimension) each case of the
  # data frame belongs to according to the pca results
  # --------------------------------------------------------
  getItemLoadings <- function(dataframe) {
    # return a vector with index numbers indicating which items
    # loads the highest on which factor
    return(apply(dataframe, 1, function(x) which.max(abs(x))))
  }
  # --------------------------------------------------------
  # this function calculates the cronbach's alpha value for
  # each factor scale, i.e. all variables with the highest loading
  # for a factor are taken for the reliability test. The result is
  # an alpha value for each factor dimension
  # --------------------------------------------------------
  getCronbach <- function(dataframe, itemloadings) {
    # clear vector
    cbv <- c()
    # iterate all highest factor loadings of items
    for (n in seq_len(length(unique(itemloadings)))) {
      # calculate cronbach's alpha for those cases that all have the
      # highest loading on the same factor
      cbv <- as.data.frame(rbind(cbv, cbind(nr = n, sjstats::cronb(stats::na.omit(dataframe[, which(itemloadings == n)])))))
    }
    # just for vertical position adjustment when we print the alpha values
    vpos <- rep(c(-0.25, -1), nrow(cbv))
    cbv <- cbind(cbv, vpos[seq_len(nrow(cbv))])
    names(cbv) <- c("nr", "alpha", "vpos")
    # cbv now contains the factor numbers and the related alpha values
    # for each "factor dimension scale"
    return(cbv)
  }
  # ----------------------------------
  # Cronbach's Alpha can only be calculated when having a data frame
  # with each component / variable as column
  # ----------------------------------
  if (dataframeparam) {
    # get alpha values
    alphaValues <- getCronbach(data, getItemLoadings(df))
  } else {
    message("Cronbach's Alpha can only be calculated when having a data frame with each component / variable as column.")
    show.cronb <- FALSE
  }
  # -------------------------------------
  # create list with factor loadings that indicate
  # on which column inside the data frame the highest
  # loading is
  # -------------------------------------
  factorindex <- getItemLoadings(df)
  # retrieve those items that have unclear factor loadings, i.e.
  # which almost load equally on several factors. The tolerance
  # that indicates which difference between factor loadings is
  # considered as "equally" is defined via fctr.load.tlrn
  removableItems <- getRemovableItems(df)
  # rename columns, so we have numbers on x axis
  names(df) <- seq_len(ncol(df))
  # convert to long data
  df <- tidyr::gather(df, "xpos", "value", !! seq_len(ncol(df)), factor_key = TRUE)
  # we need new columns for y-positions and point sizes
  df <- cbind(df, ypos = seq_len(nrow(pcadata.rotate$loadings)), psize = exp(abs(df$value)) * geom.size)
  if (!show.values) {
    valueLabels <- ""
  } else {
    valueLabels <- sprintf("%.*f", digits, df$value)
  }
  # --------------------------------------------------------
  # start with base plot object here
  # --------------------------------------------------------
  if (type == "bar") {
    heatmap <- ggplot(df, aes(x = rev(factor(.data$ypos)), y = abs(.data$value), fill = .data$value))
  } else {
    heatmap <- ggplot(data = df, aes(x = .data$xpos, y = .data$ypos, fill = .data$value))
  }
  # --------------------------------------------------------
  # determine the geom type, either points when "type" is "circles"
  # --------------------------------------------------------
  if (type == "circle") {
    geo <- geom_point(shape = 21, size = df$psize)
  } else if (type == "tile") {
    # ----------------------------------------
    # or boxes / tiles when "type" is "tile"
    # ----------------------------------------
    geo <- geom_tile()
  } else {
    # ----------
    # or bars
    # ----------
    geo <- geom_bar(stat = "identity", width = geom.size)
  }
  heatmap <- heatmap + geo +
    # --------------------------------------------------------
    # fill gradient colour from distinct color brewer palette.
    # negative correlations are dark red, positive corr. are dark blue,
    # and they become lighter the closer they are to a correlation
    # coefficient of zero
    # --------------------------------------------------------
    scale_fill_gradientn(colours = geom.colors, limits = c(-1, 1)) +
    labs(title = title, x = NULL, y = NULL, fill = NULL) +
    guides(fill = FALSE)
  # --------------------------------------------------------
  # facet bars, and flip coordinates
  # --------------------------------------------------------
  if (type == "bar") {
    heatmap <- heatmap +
      scale_x_discrete(labels = rev(axis.labels)) +
      scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, .2)) +
      facet_grid(~xpos) +
      geom_text(label = valueLabels, hjust = -0.2) +
      coord_flip()
  } else {
    heatmap <- heatmap +
      geom_text(label = valueLabels) +
      scale_y_reverse(breaks = seq(1, length(axis.labels), by = 1),
                      labels = axis.labels)
    # --------------------------------------------------------
    # show cronbach's alpha value for each scale
    # --------------------------------------------------------
    if (show.cronb) {
      heatmap <- heatmap +
        annotate("text", x = alphaValues$nr, y = Inf, parse = TRUE,
                 label = sprintf("alpha == %.*f", digits, alphaValues$alpha),
                 vjust = -0.5)
    }
  }
  # --------------------------------------------------------
  # print plot
  # --------------------------------------------------------
  graphics::plot(heatmap)
  # --------------------------------------------------------
  # if we have a data frame, all factors which do not clearly
  # load on a specific dimension (see patameter "fctr.load.tlrn")
  # will be removed and the updated data frame will be returned.
  # the user may calculate another PCA with the updated data frame
  # in order to get more clearly factor loadings
  # --------------------------------------------------------
  remdf <- NULL
  if (any(class(data) == "data.frame")) {
    message("Following items have no clear factor loading:")
    if (!is.null(removableItems)) {
      message(colnames(data)[removableItems])
      remdf <- data[, -removableItems]
    } else {
      message("none.")
    }
  }
  # --------------------------------------------------------
  # return structure with various results
  # --------------------------------------------------------
  invisible(structure(class = "sjcpca",
                      list(varim = pcadata.rotate,
                           removed.colindex = removableItems,
                           removed.df = remdf,
                           factor.index = factorindex,
                           plot = heatmap,
                           df = df)))
}
