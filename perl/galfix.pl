#!/usr/bin/perl -w
#
# POD documentation
#------------------------------------------------------------------------------
=pod BEGIN
  
=head1 NAME
  
  galfix.pl - Check and fix a GAL file

=head1 SYNOPSIS
  
  galfix.pl [-help] [-in input-file] [-qry qry-fasta] [-tgt tgt-fasta] [-out output-file]

  Options:
      -help   brief help message
      -in     input file
      -out    output file
      -qry    query-seq file 
      -tgt    target-seq file

=cut
  
#### END of POD documentation.
#-----------------------------------------------------------------------------


use strict;
use FindBin;
use lib "$FindBin::Bin";
use Getopt::Long;
use Pod::Usage;
use Location;
use Gal;

my ($fi, $fo) = ('') x 2;
my ($fq, $ft) = ('') x 2; 
my ($fhi, $fho);
my $help_flag;

#----------------------------------- MAIN -----------------------------------#
GetOptions(
    "help|h"   => \$help_flag,
    "in|i=s"   => \$fi,
    "out|o=s"  => \$fo,
    "qry|q=s"  => \$fq,
    "tgt|t=s"  => \$ft,
) or pod2usage(2);
pod2usage(1) if $help_flag;
pod2usage(2) if !$fi || !$fo;
pod2usage(2) if !$fq || !$ft;

if ($fi eq "stdin" || $fi eq "-") {
    $fhi = \*STDIN;
} else {
    open ($fhi, $fi) || die "Can't open file $fi: $!\n";
}

if ($fo eq "stdout" || $fo eq "-") {
    $fho = \*STDOUT;
} else {
    open ($fho, ">$fo") || die "Can't open file $fo for writing: $!\n";
}

print $fho join("\t", qw/id qId qBeg qEnd qSrd qSize tId tBeg tEnd tSrd tSize
    match misMatch baseN ident e score qLoc tLoc/)."\n";

my $cnt = 0;
while( <$fhi> ) {
    chomp;
    next if /(^id)|(^\#)|(^\s*$)/;
    my $ps = [ split "\t" ];
    next unless @$ps == 19;

    my ($flag, $nps) = gal_fix($ps, $fq, $ft);
    print $fho join("\t", @$nps)."\n";
    $cnt += $flag;
}
print STDERR "$cnt rows fixed\n";
close $fhi;
close $fho;


__END__