#include <iostream>
#include <iomanip>
#include <stdio.h>
#include <vector>
#include <map>
#include <time.h>
#include <boost/filesystem.hpp>
#include <boost/format.hpp>
#include <boost/program_options.hpp>
#include <boost/regex.hpp>
#include <boost/algorithm/string.hpp>
#include <api/BamReader.h>
#include <api/BamWriter.h>
#include "bam_utils.h" 
using namespace std;
using boost::format;
namespace fs = boost::filesystem;
namespace po = boost::program_options;
using namespace BamTools;

typedef map<int32_t, uint32_t> IntMap;
struct LibStat {
  uint32_t total;
  uint32_t unmapped;
  uint32_t unpaired;
  uint32_t unpaired_dup;
  uint32_t unpaired_uniq;
  uint32_t paired;
  uint32_t paired_dup;
  uint32_t paired_uniq;
  uint32_t paired_proper;
  IntMap isd;
  LibStat() {
    total = 0;
    unmapped = 0;
    unpaired = 0;
    unpaired_dup = 0;
    unpaired_uniq = 0;
    paired = 0;
    paired_dup = 0;
    paired_uniq = 0;
    paired_proper = 0;
  }
};
typedef map<string, LibStat> StrLibMap;
int main(int argc, char *argv[]) {
  string fi, fo;
  clock_t time1 = clock();
  po::options_description cmdOpts("Allowed options");
  cmdOpts.add_options()
    ("help,h", "produce help message")
    ("in,i", po::value<string>(&fi), "input (BAM) file")
    ("out,o", po::value<string>(&fo), "output file")
  ;
  po::variables_map vm;
  po::store(po::parse_command_line(argc, argv, cmdOpts), vm);
  po::notify(vm);
  if(vm.count("help") || !vm.count("in") || !vm.count("out")) {
    cout << cmdOpts << endl;
    exit(1);
  }

  BamReader reader;
  if( !reader.Open(fi) ) {
    cout << format("cannot read from %s ...\n") % fi;
    exit(1);
  }

  StrLibMap m1;
  StrLibMap::iterator it1;
  pair< StrLibMap::iterator, bool > p1;

  IntMap::iterator it2;
  pair< IntMap::iterator, bool > p2;

  SamReadGroupDictionary rgd = reader.GetHeader().ReadGroups;
  for(SamReadGroupConstIterator it=rgd.ConstBegin(); it!=rgd.ConstEnd(); ++it) {
    string rg = it->ID;
    LibStat ls;
    p1 = m1.insert( pair<string, LibStat> (rg, ls) );
    if(p1.second == false) {
      cerr << format("read group [%s] appeared >1 times\n") % rg;
      exit(1);
    }
  }

  BamAlignment al;
  string rg;
  string tag_xt;
  bool is_uniq;
  while( reader.GetNextAlignment(al) ) {
    al.GetTag("RG", rg);
    it1 = m1.find(rg);
    if(it1 == m1.end()) {
      cout << format("cannot find library[%s] for %s\n") % rg % al.Name;
      exit(1);
    }
    LibStat& ls = it1->second;
    
    al.GetTag("XT", tag_xt);
    is_uniq = (tag_xt.compare("U") == 0 || tag_xt.compare("M") == 0);
    
    if( al.IsFirstMate() ) ls.total ++;
    if( !al.IsMapped() && !al.IsMateMapped() ) {
      if( al.IsFirstMate() ) ls.unmapped ++;
    } else if( al.IsMapped() && al.IsMateMapped() ) {
      if( al.IsFirstMate() ) {
        ls.paired ++;
      } else if( al.IsDuplicate() ) {
        ls.paired_dup ++;
      } else if( is_uniq ) {
        ls.paired_uniq ++;
        if( al.IsProperPair() ) {
          ls.paired_proper ++;
          int32_t is = al.InsertSize;
          if(is < 0) is = -is;
          p2 = ls.isd.insert( pair<int32_t, uint32_t> (is, 1) );
          if(p2.second == false) p2.first->second ++;
        }
      }
    } else {
      if( al.IsFirstMate() ) ls.unpaired ++;
      if( al.IsMapped() ) {
        if( al.IsDuplicate() ) {
          ls.unpaired_dup ++;
        } else if( is_uniq ) {
          ls.unpaired_uniq ++;
        }
      }
    }
  }
  reader.Close();

  string fo1 = fo + ".tbl";
  string fo2 = fo + "_isd.tbl";
  ofstream fho1( fo1.c_str() );
  ofstream fho2( fo2.c_str() );
  fho1 << "rg\ttotal\tunmapped\tunpaired\tpaired\tunpaired_dup\tunpaired_uniq\tpaired_dup\tpaired_uniq\tpaired_proper\n"; 
  fho2 << "rg\tis\tcnt\n";
  for( it1=m1.begin(); it1!=m1.end(); it1++ ) {
    string rg = it1->first;
    LibStat ls = it1->second;
    fho1 << format("%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n") 
      % rg % ls.total % ls.unmapped % ls.unpaired % ls.paired % ls.unpaired_dup 
      % ls.unpaired_uniq % ls.paired_dup % ls.paired_uniq % ls.paired_proper;
    for (it2 = ls.isd.begin(); it2!=ls.isd.end(); it2++) 
      fho2 << format("%s\t%d\t%d\n") % rg % it2->first % it2->second;
  }
  fho1.close();
  fho2.close();

  cout << right << setw(60) << format("(running time: %.01f minutes)\n") % ( (double)(clock() - time1) / ((double)CLOCKS_PER_SEC * 60) );
  return EXIT_SUCCESS;
}

