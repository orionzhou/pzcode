#include <iostream>
#include <iomanip>
#include <stdio.h>
#include <fstream>
#include <vector>
#include <map>
#include <cmath>
#include <time.h>
#include <boost/filesystem.hpp>
#include <boost/format.hpp>
#include <boost/regex.hpp>
#include <boost/program_options.hpp>
#include <boost/lexical_cast.hpp>
#include <boost/algorithm/string.hpp>
#include "location.h"
using namespace std;
using boost::format;
namespace fs = boost::filesystem;
namespace po = boost::program_options;

struct GalRecord {
    string id;
    string qId;
    uint32_t qBeg;
    uint32_t qEnd;
    uint32_t qLen;
    string qSrd;
    
    string tId;
    uint32_t tBeg;
    uint32_t tEnd;
    uint32_t tLen;
    string tSrd;
    
    uint32_t match;
    uint32_t misMatch;
    uint32_t baseN;
    float ident;
    double e;
    float score;

    LocVec qLoc;
    LocVec tLoc;
};
typedef vector<GalRecord> GalRecords;

void check_gal_record(const GalRecord& br) {
    if(br.qBeg > br.qEnd)
        cerr << format("%s: qBeg[%d] > qEnd[%d]\n") % br.qId % br.qBeg % br.qEnd;
    if(br.tBeg > br.tEnd)
        cerr << format("%s: tBeg[%d] > tEnd[%d]\n") % br.tId % br.tBeg % br.tEnd;
    if(br.qEnd-br.qBeg+1 != br.qLen)
        cerr << format("%s:%d-%d len not %d\n") % br.qId % br.qBeg % br.qEnd % br.qLen;
    if(br.tEnd-br.tBeg+1 != br.tLen)
        cerr << format("%s:%d-%d len not %d\n") % br.tId % br.tBeg % br.tEnd % br.tLen;
    if(br.qLen != br.tLen)
        cerr << format("%s:qLen/%d <> %s:tLen/%d\n") % br.qId % br.qLen % br.tId % br.tLen;
    if(br.qLen != br.match+br.misMatch+br.baseN)
        cerr << format("qLen/%d <> %d + %d + %d\n") % br.qLen % br.match % br.misMatch % br.baseN;
    if(br.score <= 0)
        cerr << format("%s:%d-%d score:%g\n") % br.qId % br.qBeg % br.qEnd % br.score;
    if(br.qLoc.size() != br.tLoc.size())
        cerr << format("unequal blocks: %s:%d-%d\n") % br.qId % br.qBeg % br.qEnd; 
    if(locVecLen(br.qLoc) != locVecLen(br.tLoc))
        cerr << format("unequal alnlen: %s:%d-%d\n") % br.qId % br.qBeg % br.qEnd; 
}
GalRecord make_gal_record(const vector<string>& ss) {   
    using boost::lexical_cast;
    
    GalRecord br;
    br.id = ss[0];

    br.qId = ss[1];
    br.qBeg = lexical_cast<uint32_t>(ss[2]);
    br.qEnd = lexical_cast<uint32_t>(ss[3]);
    br.qSrd = ss[4];
    br.qLen = lexical_cast<uint32_t>(ss[5]);
    
    br.tId = ss[6];
    br.tBeg = lexical_cast<uint32_t>(ss[7]);
    br.tEnd = lexical_cast<uint32_t>(ss[8]);
    br.tSrd = ss[9];
    br.tLen = lexical_cast<uint32_t>(ss[10]);
   
    br.match = ss[11].empty() ? 0 : lexical_cast<uint32_t>(ss[11]);
    br.misMatch = ss[12].empty() ? 0 : lexical_cast<uint32_t>(ss[12]);
    br.baseN = ss[13].empty() ? 0 : lexical_cast<uint32_t>(ss[13]);
    br.ident = ss[14].empty() ? 0 : lexical_cast<float>(ss[14]);
    br.e = ss[15].empty() ? 0 : lexical_cast<double>(ss[15]);
    br.score = ss[16].empty() ? lexical_cast<float>(br.match) :  lexical_cast<float>(ss[16]);

    br.qLoc = locStr2Vec(ss[17]);
    br.tLoc = locStr2Vec(ss[18]);

    check_gal_record(br);
    return br;
}

void gal_tiling(const GalRecords& grs, string& qId, ofstream& fho, const unsigned& len_min) {
    LocVec lv1;
    int i = 0;
    for(GalRecords::const_iterator it = grs.begin(); it != grs.end(); it++) {
        Location loc;
        loc.beg = it->qBeg;
        loc.end = it->qEnd;
        loc.score = it->score;
        loc.idxs.insert( i++ );
        lv1.push_back(loc);
    }

    LocVec lv2 = tiling(lv1, true);
    for(LocVec::const_iterator it = lv2.begin(); it != lv2.end(); it++) {
        Location loc = *it;
        uint32_t qBeg(loc.beg), qEnd(loc.end);
        uint32_t qLen = qEnd - qBeg + 1;
        if(qLen < len_min) continue;
        
        GalRecord gr = grs[ loc.idx_ext ];
        string id(gr.id), qSrd("+");
        string tSrd = gr.qSrd == gr.tSrd ? "+" : "-";
        float ident(gr.ident), score(gr.score);
        double e(gr.e);
       
        string tId = gr.tId;
        uint32_t rqb(qBeg-gr.qBeg+1), rqe(qEnd-gr.qEnd+1);
        LocVec rqloc = (rqloc = Location(), rqloc.beg = rqb, rqloc.end = rqe, rqloc);
        LocVec qLoc = locOvlp(gr.qLoc, rqLoc);
        rqb = qLoc.begin()->beg;
        rqe = qLoc.rbegin()->end;
        qBeg = gr.qBeg + rqb - 1;
        qEnd = gr.qEnd + rqe - 1;
        
        uint32_t rtb = coordTransform(rqb, gr.qLoc, "+", gr.tLoc, "+");
        uint32_t rte = coordTransform(rqe, gr.qLoc, "+", gr.tLoc, "+");
        LocVec rtloc = (rtloc = Location(), rtloc.beg = rtb, rtloc.end = rte, rtloc);
        LocVec tLoc = locOvlp(gr.tLoc, rtLoc);

        uint32_t tBeg = tSrd=="+" ? gr.tBeg+rtb-1 : gr.tEnd-rte+1;
        uint32_t tEnd = tSrd=="+" ? gr.tBeg+rte-1 : gr.tEnd-rtb+1;
        uint32_t tLen = tEnd - tBeg + 1;
        fho << format("%s\t%s\t%d\t%d\t%s\t%d\t%s\t%d\t%d\t%s\t%d".
            "\t\t\t\t%g\t%g\t%g\t%s\t%s\n") 
            % id % qId % qBeg % qEnd % qSrd % qLen % tId % tBeg % tEnd % tSrd % tLen 
            % ident % e % score % locVec2Str(qLoc) % locVec2Str(tLoc);
    }
    cout << qId << endl;
}

int main( int argc, char* argv[] ) {
    string fi, fo;
    unsigned len_min;
    clock_t time1 = clock();
    po::options_description cmdOpts("Allowed options");
    cmdOpts.add_options()
        ("help,h", "produce help message")
        ("in,i", po::value<string>(&fi), "input file")
        ("out,o", po::value<string>(&fo), "output file")
        ("min,m", po::value<unsigned>(&len_min)->default_value(1), "mininum tiling length")
    ;
    po::variables_map vm;
    po::store(po::parse_command_line(argc, argv, cmdOpts), vm);
    po::notify(vm);
    if(vm.count("help") || !vm.count("in") || !vm.count("out")) {
        cout << cmdOpts << endl;
        return 1;
    }

    ifstream fhi(fi.c_str());
    if(!fhi.is_open()) { cout << format("cannot read: %s\n") % fi; return false; }
    ofstream fho(fo.c_str());
    if(!fho.is_open()) { cout << format("cannot write: %s\n") % fo; return false; }
    fho << "id\tqId\tqBeg\tqEnd\tqSrd\tqLen"
        << "\ttId\ttBeg\ttEnd\ttSrd\ttLen"
        << "\tmatch\tmisMatch\tbaseN\tident\te\tscore\tqLoc\ttLoc" << endl;
    
    GalRecords grs;
    string qId_p = "";
    string line;
    while(fhi.good()) {
        getline(fhi, line);
        if(line.length() == 0) continue;
        boost::erase_all(line, " ");
        
        vector<string> ss;
        boost::split(ss, line, boost::is_any_of("\t"));
        if(ss[0] == "id") continue;
        
        GalRecord gr = make_gal_record(ss);
        if(gr.qId == qId_p) {
            grs.push_back(gr);
        } else {
            if(qId_p != "") {
                gal_tiling(grs, qId_p, fho, len_min);
            }
            grs.clear();
            grs.push_back(gr);
            qId_p = gr.qId;
        }
    }
    if(grs.size() > 0) {
        gal_tiling(grs, qId_p, fho, len_min);
    }

    cout << right << setw(60) << format("(running time: %.01f minutes)\n") % ( (double)(clock() - time1) / ((double)CLOCKS_PER_SEC * 60) );
    return EXIT_SUCCESS;
}
