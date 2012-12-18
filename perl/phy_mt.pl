#!/usr/bin/perl
use strict;
use Init;
use Common;
use Seq;
use File::Basename;
use Ssp;
use Medicago;
use Data::Dumper;

my $opt_ind = "acc26";
my ($accs, $opt_conf) = get_mt_ids($opt_ind);
my $chrs = [ map {"chr".$_} (1..8) ];

my $pre = ($opt_conf == 1) ? "acc84" : "acc288";
my $d00 = "$DIR_Repo/mt_35/30_vnt_$pre/11_snps/01_ssp";
my $dir = "$DIR_Repo/mt_35/31_phylogeny/$opt_ind";
my $d01 = "$dir/01_ssp";
my $d08 = "$dir/08_stat";
my $d11 = "$dir/11_ssp";
#ssp_pipe($d00, $d01, $d08, $d11, $opt_ind, $opt_conf);

my $d15 = "$dir/15_phy";
my $d16 = "$dir/16_aln";
my $d17 = "$dir/17_nex";
my $d18 = "$dir/18_structure";
#ssp_convert($d11, $d15, $chrs, "phylip");
#ssp_convert($d15, $d16, $chrs, "aln");
#ssp_convert($d15, $d17, $chrs, "nexus");
#ssp_convert($d11, $d18, $chrs, "structure");
my $d19 = "$dir/19";
#ssp_sample($d11, $d19, $chrs);

my $d21 = "$dir/21_phynj";
#run_clustalw_nj($d16, $d21, $chrs); 
my $d22 = "$dir/22_phyml";
#run_phyml($d15, $d22, $chrs);

sub ssp_pipe {
    my ($d00, $d01, $d08, $d11, $opt_ind, $opt_conf) = @_;
    system("mkdir -p $d01") unless -p $d01;
    system("mkdir -p $d08") unless -p $d08;
    system("mkdir -p $d11") unless -p $d11;
    for my $chr (@$chrs) {
#    next unless $chr eq "chr1";
        runCmd("sspSelectInds -i $d00/$chr.txt -o $d01/$chr.ssp -t $opt_ind -c $opt_conf", 1);
        runCmd("sspStat -i $d01/$chr.ssp -o $d08/$chr.tbl", 1);
        my $f_tmp = "tmp1.ssp";
        runCmd("sspFilter -i $d01/$chr.ssp -o $f_tmp -m 5 -a 1");
        runCmd("sspSample -i $f_tmp -o $d11/$chr.ssp -n 10000");
        system("rm $f_tmp");
    }
}
sub ssp_convert {
    my ($dirI, $dirO, $chrs, $format) = @_;
    system("mkdir -p $dirO") unless -d $dirO;
    for my $chr (@$chrs) {
#    next if $chr eq "chr1";
        my $fo = "$dirO/$chr.$format";
        if($format =~ /^(aln)|(nexus)$/) {
            my $fi = "$dirI/$chr.phylip";
            runCmd("seqret $fi $fo -osformat $format");
        } elsif($format =~/^(phylip)|(structure)$/) {
            my $fi = "$dirI/$chr.ssp";
            runCmd("sspConvert -i $fi -o $fo -f $format");
        }
    }
}
sub run_clustalw_nj {
    my ($dirI, $dirO, $chrs) = @_;
    system("mkdir -p $dirO") unless -d $dirO;
    for my $chr (@$chrs) {
        next unless $chr eq "chr5";
        my $fi = "$dirI/$chr.aln";
        my $fo = "$dirI/$chr.phb";
        runCmd("clustalw2 -INFILE=$fi -BOOTSTRAP=1000 -OUTORDER=INPUT -OUTPUTTREE=phylip -BOOTLABELS=node -CLUSTERING=NJ -KIMURA", 1);
        system("mv $fo $dirO");
    }
}
sub run_phyml {
    my ($dirI, $dirO, $chrs) = @_;
    system("mkdir -p $dirO") unless -d $dirO;
    for my $chr (@$chrs) {
#    next unless $chr ge "chr7";
        my $fi = "$dirI/$chr.phylip";
        my $fo = "$dirO/$chr.nwk";
        runCmd("PhyML -i $fi -d nt");
        system("mv $fi\_phyml_tree.txt $fo");
        system("rm $fi\_phyml*");
    }
}



