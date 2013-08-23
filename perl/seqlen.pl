#!/usr/bin/perl -w
#
# POD documentation
#------------------------------------------------------------------------------
=pod BEGIN
  
=head1 NAME
  
  seqlen.pl - report sequence lengths in an input sequence file 

=head1 SYNOPSIS
  
  seqlen.pl [-help] [-in input-file] [-out output-file]

  Options:
      -help   brief help message
      -in     input file
      -out    output file

=head1 DESCRIPTION

  This program reports lengths of each sequence record in the input file

=cut
  
#### END of POD documentation.
#-----------------------------------------------------------------------------

use strict;
use Getopt::Long;
use Pod::Usage;
use Bio::Seq;
use Bio::SeqIO;

my ($fi, $fo) = ('') x 2;
my $help_flag;

#----------------------------------- MAIN -----------------------------------#
GetOptions(
    "help|h"  => \$help_flag,
    "in|i=s"  => \$fi,
    "out|o=s" => \$fo,
) or pod2usage(2);
pod2usage(1) if $help_flag;
pod2usage(2) if !$fi || !$fo;

open(my $fhi, "<$fi") || die "Can't open file $fi for reading";
open(my $fho, ">$fo") || die "Can't open file $fo for writing";
print $fho join("\t", qw/id length/)."\n";

my $seqHI = Bio::SeqIO->new(-fh=>$fhi, -format=>'fasta');
while(my $seqO = $seqHI->next_seq()) {
    my ($id, $len) = ($seqO->id, $seqO->length);
    print $fho join("\t", $id, $len)."\n";
}
$seqHI->close();

exit 0;