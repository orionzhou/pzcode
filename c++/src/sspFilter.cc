#include <iostream>
#include <iomanip>
#include <stdio.h>
#include <vector>
#include <time.h>
#include <boost/filesystem.hpp>
#include <boost/format.hpp>
#include <boost/program_options.hpp>
#include <boost/assign/std/vector.hpp>
#include <boost/lexical_cast.hpp>
#include <boost/progress.hpp>
#include <Sequence/FastaExplicit.hpp>
#include <Sequence/PolySites.hpp>
#include <Sequence/PolySNP.hpp>
#include <Sequence/PolyTableSlice.hpp>
#include <Sequence/SeqExceptions.hpp>
#include "ssp.h"

using namespace std;
using boost::format;
using namespace boost::assign;
using namespace Sequence;
namespace fs = boost::filesystem;
namespace po = boost::program_options;

int main(int argc, char *argv[]) {
  string fi, fo, out_format;
  int co_maf, co_mis;
  bool co_bia;
  clock_t time1 = clock();
  po::options_description cmdOpts("Allowed options");
  cmdOpts.add_options()
    ("help,h", "produce help message")
    ("in,i", po::value<string>(&fi), "input (simpleSNP) file")
    ("out,o", po::value<string>(&fo), "output file")
    ("out_format,f", po::value<string>(&out_format)->default_value("ssp"), "output format")
    ("co_mis,m", po::value<int>(&co_mis)->default_value(-1), "missing data cutoff")
    ("co_maf,a", po::value<int>(&co_maf)->default_value(0), "MAF minimum cutoff")
    ("co_bia,b", po::value<bool>(&co_bia)->default_value(0), "only keep bi-allelic positions")
  ;

  po::variables_map vm;
  po::store(po::parse_command_line(argc, argv, cmdOpts), vm);
  po::notify(vm);

  if(vm.count("help") || !vm.count("in") || !vm.count("out")) {
    cout << cmdOpts << endl;
    return 1;
  }

  SimpleSNP ssp;
  ifstream fh01( fi.c_str() );
  ssp.read(fh01);
  fh01.close();

  unsigned n_ind = ssp.size(), n_pos = ssp.numsites();
  cout << format("before filtering:  %3d inds, %6d positions\n") % n_ind % n_pos;
  co_mis = (co_mis == -1) ? n_ind : co_mis;

  ssp.FilterMissing(co_mis);
  n_pos = ssp.numsites();
  cout << format("after filter [co_mis=%3d]:  %6d positions\n") % co_mis % n_pos;

  ssp.ApplyFreqFilter(co_maf);
  n_pos = ssp.numsites();
  cout << format("after filter [co_maf=%3d]:  %6d positions\n") % co_maf % n_pos;

  if(co_bia) {
    ssp.RemoveMultiHits();
    n_pos = ssp.numsites();
    cout << format("after filter [co_bia=%3d]:  %6d positions\n") % co_bia % n_pos;
  }
 	
  ssp.write(fo, out_format);

  cout << right << setw(60) << format("(running time: %.01f minutes)\n") % ( (double)(clock() - time1) / ((double)CLOCKS_PER_SEC * 60) );
  return EXIT_SUCCESS;
}



