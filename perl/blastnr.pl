#!/usr/bin/perl -w
#
# POD documentation
#---------------------------------------------------------------------------
=pod BEGIN
  
=head1 NAME
  
  blastnr.pl - blast NR/NT database

=head1 SYNOPSIS
  
  blastnr.pl [-help] [-in input-file] [-out output-file]

  Options:
    -h (-help)   brief help message
    -i (--in)    input sequence file
    -o (--out)   output file (prefix)

=cut
  
#### END of POD documentation.
#---------------------------------------------------------------------------


use strict;
use FindBin;
use lib "$FindBin::Bin";
use Getopt::Long;
use Pod::Usage;
use File::Basename;
use File::Path qw/make_path remove_tree/;
use Common;

my ($fi, $fo) = ('') x 2;
my $db = "\$data/db/blast/current/nt";
my $help_flag;

#--------------------------------- MAIN -----------------------------------#
GetOptions(
  "help|h"   => \$help_flag,
  "in|i=s"   => \$fi,
  "out|o=s"  => \$fo,
) or pod2usage(2);
pod2usage(1) if $help_flag;
pod2usage(2) if !$fi || !$fo;

-d $fo || make_path($fo);
#chdir $fo || die "cannot chdir to $fo\n";

-s "$fo/01.tbl" || die "blastnr output $fo/01.tbl not found\n";
runCmd("blast2gal.pl -i $fo/01.tbl | galfilter.pl -s 80 -o $fo/02.gal");
runCmd("galtiling.pl -i $fo/02.gal -o -m 10 -o $fo/03.tiled.gal");
runCmd("blastanno.pl -i $fo/03.tiled.gal -o $fo/04.anno.gal");
sum_cat("$fo/04.anno.gal", "$fo.tbl");

sub sum_cat {
  my ($fi, $fo) = @_;
  my $t = readTable(-in => $fi, -header => 1);

  open(my $fho, ">$fo") or die "cannot write $fo\n";
  print $fho join("\t", qw/id size ali cat/)."\n";
  $t->sort("qId", 1, 0, "qBeg", 0, 0);
  my $ref = group($t->colRef("qId"));
  for my $qId (sort(keys(%$ref))) {
    my ($idxb, $cnt) = @{$ref->{$qId}};
    my $hc;
    for my $idx ($idxb..$idxb+$cnt-1) {
      my ($ali1, $cat1) = map {$t->elm($idx, $_)} qw/ali cat/;
      $hc->{$cat1} ||= 0;
      $hc->{$cat1} += $ali1;
    }
    my @cats = sort {$hc->{$a} <=> $hc->{$b}} keys(%$hc);

    my $str = join(" ", map {$_."[".$hc->{$_}."]"} keys(%$hc));
    print "$qId: $str\n" if @cats > 1;
    
    my $cat = $cats[-1];
    my $ali = $hc->{$cat};
    my $qSize = $t->elm($idxb, "qSize");
    print $fho join("\t", $qId, $qSize, $ali, $cat)."\n";
  }
  close $fho;
}

