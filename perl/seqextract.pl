#!/usr/bin/perl -w
#
# POD documentation
#------------------------------------------------------------------------------
=pod BEGIN
  
=head1 NAME
  
  seqextract.pl - extract one or more sequence records from an input fasta file

=head1 SYNOPSIS
  
  seqextract.pl [-help] [-out output-file] [-id id-file] <input-file> <IDs>

  Options:
      -help   brief help message
      -out    output file, instead of stdout
      -id     a file containing IDs

=head1 DESCRIPTION

  This program extracts sequences from the input fasta file

=head1 OPTIONS

=over 6
  
=item B<-help>
  
  Print a usage summary.

=item B<input-file>
  
  Needs to be fasta format

=item B<IDs>
  
  Fasta IDs

=item B<output-file>

  To write to stdout, the user could either specify 'stdout' or simply leave this
  augument empty.

=back
  
=head1 BUGS
  
=head1 REFERENCES
  
=head1 VERSION
  
  0.1
  
=cut
  
#### END of POD documentation.
#-----------------------------------------------------------------------------

use strict;
use Getopt::Long;
use Pod::Usage;
use Bio::Seq;
use Bio::SeqIO;

my $fi = '';
my $fo = '';
my $f_id = '';
my $fhi;
my $fho;
my $help_flag;

#----------------------------------- MAIN -----------------------------------#
GetOptions(
    "help|h"  => \$help_flag,
    "out|o=s" => \$fo,
    "id|i=s" => \$f_id,
) or pod2usage(2);
pod2usage(1) if $help_flag;

my @ids;
($fi, @ids)= @ARGV;
if(!$fi) {
    pod2usage(2);
} elsif ($fi eq '-' || $fi eq "stdin") {
    $fhi = \*STDIN;
} else {
    open ($fhi, $fi) || die "Can't open file $fi: $!\n";
}

if(!$fo || $fo eq "stdout") {
    $fho = \*STDOUT;
} else {
    open ($fho, ">$fo") || die "Can't open file $fo for writing: $!\n";
}

if($f_id && -s $f_id) {
    open(FHD, "<$f_id") or die "cannot open ID-file for reading\n";
    my $flag_head = 1;
    while(<FHD>) {
        chomp;
        next if /^\#/;
        my @ps = split "\t";
        next if @ps == 0;
        my $id = $ps[0];
        if($flag_head == 1 && $id =~ /id/i) {
            $flag_head = 0;
            next;
        }
        push @ids, $id;
    }
    close FHD;
}

my $seqHI = Bio::SeqIO->new(-fh=>$fhi, -format=>'fasta');
my $seqHO = Bio::SeqIO->new(-fh=>$fho, -format=>'fasta');
my %h = map {$_=>1} @ids;
my $cnt = 0;
while(my $seqO = $seqHI->next_seq()) {
    my ($id) = ($seqO->id);
    if(exists $h{$id}) {
        $seqHO->write_seq($seqO);
        $cnt ++;
    }
}
$seqHI->close();
$seqHO->close();
printf "  %4d sequences extracted\n", $cnt;

exit 0;



