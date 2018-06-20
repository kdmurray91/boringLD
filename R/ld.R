require(doFuture)
require(foreach)
require(dplyr)

rho2halfmax = function(r, n, maxd=100000) {
  # This is a horrible hack as I can't seem to solve the below for d, and do
  # f(r, rsq, n)(r, rsq(d=1)/2, n)  to find distance of halfmaximal analytically
  d = as.numeric(1:maxd)
  r2 = ((10+r*d)/((2+r*d)*(11+r*d))) *(1+((3+r*d)*(12+12*r*d+(r*d)^2))/(n*(2+r*d)*(11+r*d)))
  d[min(which(r2 < max(r2)/2))]
}

#' window_halfmax
#'
#' @param bcf Indexed BCF or VCF file
#' @param region Region of genome
#' @param minMAF Minimum SNP minor allle freq
#' @param maxMissing Maximum SNP missing data rate
#'
#' @return data.frame with one row and columns rho, halfmax, region, nsnp
#' @export
window_halfmax = function(bcf, region, minMAF, maxMissing) {
  geno = bcf_getGTandAD(bcf, region, minMAF = minMAF, maxMissing = maxMissing)
  # number of SNPs
  if (is.null(geno) || geno$nSNP < 2) {
    warning("Too few SNPs for window ", region)
    return(NULL)
  }
  d = as.matrix(dist(geno$POS))
  d = d[upper.tri(d)]
  rsq = cor(geno$GT_minor, use="pairwise.complete.obs") ^2
  rsq = rsq[upper.tri(rsq)]

  # fits decay eqn. from Hill & Weir, via that blog post we used in brachy paper
  n = geno$nIndiv
  fit = nls(rsq ~ ((10+r*d)/((2+r*d)*(11+r*d))) *(1+((3+r*d)*(12+12*r*d+(r*d)^2))/(n*(2+r*d)*(11+r*d))),
        start=c(r=0.1), control=nls.control(maxiter=100000, warnOnly=T))
  fit = summary(fit)

  rho = fit$parameters[1]
  halfmax = rho2halfmax(rho, n)
  if (!fit$convInfo$isConv || rho < 0) {
    warning("LD decay model failed to converge (or found rho of ", rho, " < 0)")
    rho = NA
    halfmax = NA
  }

  return(data.frame(rho=rho, halfmax=halfmax, nsnp = geno$nSNP, stringsAsFactors = F))
}

#' windowed_halfmax
#'
#' @param bcf Indexed BCF or VCF file
#' @param windowsize Size of each window
#' @param slide Number of bases to skip between each window start
#' @param minMAF Minimum SNP minor allle freq
#' @param maxMissing Maximum SNP missing data rate
#' @param windows restrict analyses to these windows (expected to be created with bcf_getWindows)
#'
#' @return data.frame  columns rho, halfmax, region, nsnp
#' @export
windowed_halfmax = function (bcf, windowsize, slide=windowsize, minMAF=0.1, maxMissing=0.8, windows=NULL) {
  if (is.null(windows)) {
    windows = bcf_getWindows(bcf, windowsize=windowsize, slide = slide)
  }
  window_i = seq_len(nrow(windows))
  chunks = split(window_i, ceiling(window_i / (length(window_i)/1000)))
  export=c("bcf", "windows", "minMAF", "maxMissing")
  halfmax = foreach(chunk=chunks, .combine=rbind, .export = export) %dopar% {
    windows[chunk,] %>%
      dplyr::mutate(halfmax=purrr::map(region, ~ window_halfmax(bcf, .x, minMAF, maxMissing))) %>%
      tidyr::unnest(halfmax)
  }
  halfmax
}