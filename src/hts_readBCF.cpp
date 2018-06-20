#include <Rcpp.h>
#include <string>
#include <htslib/hts.h>
#include <htslib/vcf.h>
#include <vector>
#include "bcf_reader.hh"

using namespace Rcpp;
using namespace std;
// [[Rcpp::plugins(cpp11)]]


// [[Rcpp::export]]
List readBCFQuery_(SEXP fname, SEXP reg) {
  string filename = as<string>(fname);
  string region = as<string>(reg);
  gusld::BCFReader rdr(filename);
  vector<string> ctg_names;
  vector<int32_t> ctg_lenghts;

  if (region == "") {
    rdr.read_all();
  } else {
    rdr.read_region(region);
  }

  return List::create(
    Named("CHROM")=wrap(rdr.CHROM),
    Named("POS")=wrap(rdr.POS),
    Named("GT")=wrap(rdr.GT),
    Named("AD_ref")=wrap(rdr.AD_ref),
    Named("AD_alt")=wrap(rdr.AD_alt)
    );
}

// [[Rcpp::export]]
List readBCFContigs_(SEXP fname) {
  string filename = as<string>(fname);
  gusld::BCFReader rdr(filename);
  vector<string> ctg_names;
  vector<int32_t> ctg_lenghts;

  rdr.get_contig_names_lengths(ctg_names, ctg_lenghts);

  return List::create(Named("names")=wrap(ctg_names),
                      Named("lengths")=wrap(ctg_lenghts));
}