#include <iostream>
#include <iomanip>
#include <stdio.h>
#include <vector>
#include <map>
#include <time.h>
#include <fstream>
#include <boost/filesystem.hpp>
#include <boost/format.hpp>
#include <boost/program_options.hpp>
#include <boost/regex.hpp>
#include <boost/assign/std/vector.hpp>
#include <boost/algorithm/string.hpp>
#include "ssp.h"
using namespace std;
using namespace boost::assign;
using boost::format;
namespace fs = boost::filesystem;
namespace po = boost::program_options;

set<string> read_selected_ids(const string& fi) {
  ifstream fhi(fi.c_str());
  if(!fhi.is_open()) {
    cout << format("cannot open file: %s") % fi;
    exit(1);
  }
  set<string> ids;
  string line;
  int idx_tag = -1, idx_id = -1;
  vector<string> ss;
  
  getline(fhi, line);
  boost::split(ss, line, boost::is_any_of("\t"));
  for(uint32_t j = 0; j < ss.size(); j ++) {
    if(ss[j] == "id") idx_id = j;
    if(ss[j] == "select") idx_tag = j;
  }
  if(idx_tag < 0 || idx_id < 0) {
    cout << format("cannot find columns: id, select\n");
    exit(1);
  }

  while(fhi.good()) {
    getline(fhi, line);
    if(line.length() == 0) continue;
    boost::split(ss, line, boost::is_any_of("\t"));
    if(ss[idx_tag] == "1") ids.insert(ss[idx_id]);
  }
  cout << format("%d ids read from %s\n") % ids.size() % fi;
  return ids;
}

int main( int argc, char* argv[] ) {
  int opt_conf, n_ind, n_type;
  string f_acc, f_in, f_id, d_out, opt_ind;
  clock_t time1 = clock();
  po::options_description cmdOpts("Allowed options");
  cmdOpts.add_options()
    ("help,h", "produce help message")
    ("f_acc,a", po::value<string>(&f_acc)->default_value("/project/youngn/zhoup/Scripts/conf/acc_ids.tbl"), "acc option file")
    ("opt_ind,t", po::value<string>(&opt_ind), "ind option")
    ("opt_conf,c", po::value<int>(&opt_conf)->default_value(1), "id_all tion")
    ("f_in,i", po::value<string>(&f_in), "input sequence file")
    ("f_id,d", po::value<string>(&f_id), "gene id file")
    ("d_out,o", po::value<string>(&d_out), "output directory")
    ("n_ind,n", po::value<int>(&n_ind)->default_value(84), "number of inds")
    ("n_type,p", po::value<int>(&n_type)->default_value(4), "number of types")
  ;
  po::variables_map vm;
  po::store(po::parse_command_line(argc, argv, cmdOpts), vm);
  po::notify(vm);
  if(vm.count("help") || !vm.count("opt_ind") || !vm.count("f_in") || !vm.count("f_id") || !vm.count("d_out")) {
    cout << cmdOpts << endl;
    return 1;
  }

  string types[] = {"cds", "intron", "utr3", "utr5"};
  for(int i = 0; i < n_type; i ++)
    system(("mkdir -p " + d_out + "/" + types[i]).c_str()); 

  IntVec idxs;
  StrVec inds;
  idxs = get_acc_idx(f_acc, opt_ind, inds, opt_conf);
 
  set<string> ids = read_selected_ids(f_id);
  ifstream fhi( f_in.c_str() );
  if(!fhi.is_open()) {
    cout << format("cannot open file: %s") % f_in;
    exit(1);
  }
  string line;
  getline(fhi, line);

  int cnt = 0;
  while(fhi.good()) {
    StrVec lines;
    for(int i = 0; i < n_ind * n_type; i ++) {
      getline(fhi, line);
      if(line.length() == 0) continue;
      lines.push_back(line);
    }
    if(lines.size() == 0) continue;

    string id;
    IntVec lens, num_Ns, num_snps;
    StrVec ss, seqs;
    for(uint32_t i = 0; i < idxs.size(); i ++) {
      int idx = idxs[i];
      for(int j = 0; j < n_type; j ++) {
        boost::split(ss, lines[idx*n_type+j], boost::is_any_of("\t"));
        if(i == 0 && j == 0) 
          id = ss[0];
        else
          if(id != ss[0]) {
            cout << format("%s line %d: not %s\n") % id % i % ss[0];
            exit(1);
          }

        if(ss[1] != inds[i]) {
          cout << format("%s line %d: %s not %s\n") % id % i % ss[1] % inds[i];
          exit(1);
        }
        if(ss[2] != types[j]) {
          cout << format("%s line %d: %s not %s\n") % id % i % ss[2] % types[j];
          exit(1);
        }
        lens.push_back( boost::lexical_cast<int>(ss[3]) );
        num_Ns.push_back( boost::lexical_cast<int>(ss[4]) );
        num_snps.push_back( boost::lexical_cast<int>(ss[5]) );
        seqs.push_back( ss[6] );
      }
    }
    
    if(ids.find(id) == ids.end()) continue;
    if( ++cnt % 100 == 0 ) cout << format("  %5d done\n") % cnt;
    for(int j = 0; j < n_type; j ++) {
      string type = types[j];
      if(lens[j] == 0) continue;
      string f_out = d_out + "/" + type + "/" + id + ".fas";
      ofstream fho(f_out.c_str());
      if (!fho.is_open()) { cout << format("cannot write output: %s\n") % f_out; return 1; } 
      for(uint32_t k = 0; k < idxs.size(); k ++) {
        fho << format(">%s\n") % inds[k];
        fho << format("%s\n") % seqs[k*n_type+j];
      }
      fho.close();
    }
  }
  fhi.close();

  cout << right << setw(50) << format("(running time: %.01f minutes)\n") % ( (double)(clock() - time1) / ((double)CLOCKS_PER_SEC * 60) );
  return EXIT_SUCCESS;
}



