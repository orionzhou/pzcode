#!/usr/bin/perl -w
#
# POD documentation
#---------------------------------------------------------------------------
=pod BEGIN
  
=head1 NAME
  
  galfilter.pl - filter records in a GAL file

=head1 SYNOPSIS
  
  galfilter.pl [-help] [-in input-file] [-out output-file]

  Options:
    -h (--help)   brief help message
    -i (--in)     input file
    -o (--out)    output file
    -m (--match)  minimum matches (default: 1) 
    -p (--ident)  minimum percent identity (default: 0.5) 
    -s (--score)  minimum score (default: 0) 

=cut
  
#### END of POD documentation.
#---------------------------------------------------------------------------


use strict;
use FindBin;
use lib "$FindBin::Bin";
use Getopt::Long;
use Pod::Usage;
use Location;
use Gal;

my ($fi, $fo) = ('') x 2;
my ($min_match, $min_ident, $min_score) = (1, 0.5, 0);
my ($fhi, $fho);
my $help_flag;

#--------------------------------- MAIN -----------------------------------#
GetOptions(
  "help|h"   => \$help_flag,
  "in|i=s"   => \$fi,
  "out|o=s"  => \$fo,
  "match|m=i"  => \$min_match,
  "ident|p=f"  => \$min_ident,
  "score|s=i"  => \$min_score,
) or pod2usage(2);
pod2usage(1) if $help_flag;
#pod2usage(2) if !$fi || !$fo;

if ($fi eq "" || $fi eq "stdin" || $fi eq "-") {
  $fhi = \*STDIN;
} else {
  open ($fhi, $fi) || die "Can't open file $fi: $!\n";
}

if ($fo eq "" || $fo eq "stdout" || $fo eq "-") {
  $fho = \*STDOUT;
} else {
  open ($fho, ">$fo") || die "Can't open file $fo for writing: $!\n";
}

print $fho join("\t", @HEAD_GAL)."\n";

my $cnt = 0;
while( <$fhi> ) {
  chomp;
  next if /(^id)|(^\#)|(^\s*$)/;
  my $ps = [split "\t"];
  next unless @$ps == 20;
  my ($id, $tId, $tBeg, $tEnd, $tSrd, $tSize, 
    $qId, $qBeg, $qEnd, $qSrd, $qSize,
    $ali, $mat, $mis, $qN, $tN, $ident, $score, $tLocS, $qLocS) = @$ps;
  $mat >= $min_match || next;
  $ident >= $min_ident || next;
  next if $score ne "" && $score < $min_score;
  print $fho join("\t", @$ps)."\n";
  $cnt ++;
}
print STDERR "$cnt rows passed filter\n";
close $fhi;
close $fho;


__END__
