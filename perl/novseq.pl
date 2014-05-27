#!/usr/bin/perl -w
#
# POD documentation
#---------------------------------------------------------------------------
=pod BEGIN
  
=head1 NAME
  
  novseq.pl - identify and characterize novel sequences

=head1 SYNOPSIS
  
  novseq.pl [-help] [-qry query-genome] [-tgt target-genome]

  Options:
    -h (--help)   brief help message
    -q (--qry)    query genome
    -t (--tgt)    target genome
    -s (--stat)   print statistics

=cut
  
#### END of POD documentation.
#---------------------------------------------------------------------------

use strict;
use Getopt::Long;
use Pod::Usage;
use FindBin;
use lib "$FindBin::Bin";
use Common;
use Data::Dumper;
use File::Path qw/make_path remove_tree/;
use File::Basename;
use List::Util qw/min max sum/;
use List::MoreUtils qw/first_index first_value insert_after apply indexes pairwise zip uniq/;

my ($qry, $tgt) = ('HM056', 'HM101');
my $help_flag;
my $stat_flag;

#--------------------------------- MAIN -----------------------------------#
GetOptions(
  "help|h"  => \$help_flag,
  "qry|q=s" => \$qry,
  "tgt|t=s" => \$tgt,
  "stat|s"  => \$stat_flag,
) or pod2usage(2);
pod2usage(1) if $help_flag;

my $data = '/home/youngn/zhoup/Data';
my $qry_fas = "$data/genome/$qry/11_genome.fas";
my $tgt_fas = "$data/genome/$tgt/11_genome.fas";
my $qry_2bit = "$data/db/blat/$qry.2bit";
my $tgt_2bit = "$data/db/blat/$tgt.2bit";
my $qry_size = "$data/genome/$qry/15.sizes";
my $tgt_size = "$data/genome/$tgt/15.sizes";
my $qry_size_bed = "$data/genome/$qry/15.bed";
my $tgt_size_bed = "$data/genome/$tgt/15.bed";
my $qry_gap = "$data/genome/$qry/16_gap.bed";
my $tgt_gap = "$data/genome/$tgt/16_gap.bed";

my $dir = "$data/misc3/$qry\_$tgt/41_novseq";
-d $dir || make_path($dir);
chdir $dir || die "cannot chdir to $dir\n";

if($stat_flag) {
  print_stat();
  exit;
}
#pipe1();
#pipe2();
pipe3();

sub pipe1 {
  runCmd("gal2gax.pl -i ../23_blat/41.3.gal -o 41.3.gax");
  runCmd("gax2bed.pl -i 41.3.gax -p tgt -o - | sortBed -i stdin | \\
    mergeBed -i stdin > 41.3.bed");
  runCmd("subtractBed -a $qry_size_bed -b $qry_gap | \\
    subtractBed -a stdin -b 41.3.bed | bedfilter.pl -l 50 -o 01.bed");
  runCmd("rm 41.3.gax 41.3.bed");
  runCmd("seqret.pl -d $qry_fas -b 01.bed -o 01.fas");
}
sub pipe_dust {
  my ($fi, $fo) = @_;
  -d $fo || make_path($fo);
  runCmd("dustmasker -in $fi -outfmt interval -out $fo/01.txt");
  dust2bed("$fo/01.txt", "$fo/11.bed");  
  runCmd("bedfilter.pl -i $fo/11.bed -l 10 -o $fo.bed");
}
sub pipe_trf {
  my ($fi, $fo) = @_;
  -d $fo || make_path($fo);
  runCmd("trf407b.linux64 $fi 2 7 7 80 10 50 500 -h -d -m");
  runCmd("mv $fi.2.7.7.80.10.50.500.dat $fo/01.dat");
  runCmd("mv $fi.2.7.7.80.10.50.500.mask $fo/01.mask");
  trf2tbl("$fo/01.dat", "$fo.tbl");
  runCmd("awk 'BEGIN{OFS=\"\\t\"} {print \$1, \$2-1, \$3}' $fo.tbl \\
    | sortBed -i stdin | mergeBed -i stdin > $fo.bed");
}
sub pipe2 {
  pipe_dust("01.fas", "03.dust");
  pipe_trf("01.fas", "05.trf");
  runCmd("cat 03.dust.bed 05.trf.bed | bedcoord.pl | \\
    sortBed -i stdin | mergeBed -i stdin > 09.bed");
  runCmd("subtractBed -a 01.bed -b 09.bed | \\
    bedfilter.pl -l 50 -o 11.bed");
  runCmd("seqret.pl -d $qry_fas -b 11.bed -o 11.fas");
}
sub pipe3 {
  runCmd("blastnr.pl -i 11.fas -o 17.blastnr"); #blastnr on Itasca
  cat_seq("11.bed", "17.blastnr.tbl", "19.bed");
  runCmd("awk 'BEGIN{OFS=\"\\t\"} {if(\$4!=\"foreign\") print}' 19.bed > 21.bed");
  runCmd("seqret.pl -d $qry_fas -b 21.bed -o 21.fas");
  runCmd("usearch.pl -i 21.fas -o 31");
  runCmd("bedcoord.pl -i 31.bed -o 41.bed");
}
sub print_stat {
  print "raw novseq\n";
  runCmd("bedlen.pl -i 01.bed");
  print "repeat-masked\n";
  runCmd("bedlen.pl -i 11.bed");
  
  print "\tforeign\n";
  runCmd("awk 'BEGIN{OFS=\"\\t\"} {if(\$4==\"foreign\") print}' 19.bed | bedlen.pl");
  print "\tplant\n";
  runCmd("awk 'BEGIN{OFS=\"\\t\"} {if(\$4==\"plant\") print}' 19.bed | bedlen.pl");
  print "\tunc\n";
  runCmd("awk 'BEGIN{OFS=\"\\t\"} {if(\$4==\"unc\") print}' 19.bed | bedlen.pl");
  
  print "filtered plant+unc:\n";
  runCmd("bedlen.pl -i 21.bed");
  print "\tCDS\n";
  runCmd("intersectBed -a 21.bed -b \$genome/$qry/51.bed/cds.bed | bedlen.pl");
  print "de-duped\n";
  runCmd("bedlen.pl -i 41.bed");
  print "\tCDS\n";
  runCmd("intersectBed -a 41.bed -b \$genome/$qry/51.bed/cds.bed | bedlen.pl");
}

sub dust2bed {
  my ($fi, $fo) = @_;
  open(my $fhi, "<$fi") or die "cannot read $fi\n";
  open(my $fho, ">$fo") or die "cannot write $fo\n";
  my $id;
  while(<$fhi>) {
    chomp;
    if(/^\>(\S+)$/) {
      $id = $1;
    } else {
      my ($beg, $end) = split "-";
      print $fho join("\t", $id, $beg, $end + 1)."\n";
    }
  }
  close $fhi;
  close $fho;
}
sub trf2tbl {
  my ($fi, $fo) = @_;
  open(my $fhi, "<$fi") or die "cannot read $fi\n";
  open(my $fho, ">$fo") or die "cannot write $fo\n";
  my $id;
  while(<$fhi>) {
    chomp;
    if(/^Sequence:\s*([\w\-\_]+)$/) {
      $id = $1;
    } elsif(/^\d/) {
      my ($beg, $end, $size, $copy, $size2, $mat, $ide, $score,
        $pa, $pt, $pc, $pg, $ent, $seq) = split " ";
      print $fho join("\t", $id, $beg, $end, "($seq)x".$copy, $score)."\n";
    }
  }
  close $fhi;
  close $fho;
}
sub cdhit2bed {
  my ($fi, $fo) = @_;
  open(my $fhi, "<$fi") or die "cannot read $fi\n";
  open(my $fho, ">$fo") or die "cannot write $fo\n";
  my ($h, $hl);
  while(<$fhi>) {
    chomp;
    if(/^\>(\S+)$/) {
      my ($id, $beg, $end) = split("-", $1);
      print $fho join("\t", $id, $beg - 1, $end)."\n";
    }
  }
  close $fhi;
  close $fho;
}
sub cat_seq {
  my ($fi, $fc, $fo) = @_;
  my $h;
  open(my $fhi, "<$fi") or die "cannot read $fi\n";
  my $n = 1;
  while(<$fhi>) {
    chomp;
    my ($seqid, $beg, $end) = split "\t";
    my $id = join("-", $seqid, $beg + 1, $end);
    $h->{$id} = [$n ++, 'unc'];
  }
  close $fhi;

  my $tc = readTable(-in => $fc, -header => 1);
  for my $i (0..$tc->lastRow) {
    my ($id, $size, $ali, $cat) = $tc->row($i);
    exists $h->{$id} || die "no $id in $fi\n";
    $h->{$id}->[1] = $cat;
  }

  my $hl;
  open(my $fho, ">$fo") or die "cannot write $fo\n";
  for my $id (sort {$h->{$a}->[0] <=> $h->{$b}->[0]} keys(%$h)) {
    my ($seqid, $beg, $end) = split("-", $id);
    my $cat = $h->{$id}->[1];
    $hl->{$cat} ||= 0;
    $hl->{$cat} += $end - $beg + 1;
    print $fho join("\t", $seqid, $beg - 1, $end, $cat)."\n";
  }
  close $fho;

  for my $cat (sort(keys(%$hl))) {
    printf "  %10s\t%10d\n", $cat, $hl->{$cat};
  }
}


__END__
intersectBed -c -a /home/youngn/zhoup/Data/genome/HM340.APECCA/51.bed/mrna.bed -b HM340.APECCA_HM101/41_novseq/41.bed | awk 'BEGIN{FS="\t";C=0} {if($7>0) C+=1} END{print C}'
intersectBed -a /home/youngn/zhoup/Data/genome/HM340.APECCA/51.bed/mrna.bed -b HM340.APECCA_HM101/41_novseq/41.bed | bedlen.pl
