package Gal;
use strict;
use Data::Dumper;
use Common;
use Location;
use Seq;
use List::Util qw/min max sum/;
use List::MoreUtils qw/first_index first_value insert_after apply indexes pairwise zip uniq/;
use vars qw/$VERSION @ISA @EXPORT @EXPORT_OK/;
require Exporter;
@ISA = qw/Exporter/;
@EXPORT = qw/@HEAD_GAL @HEAD_GALL
    /;
@EXPORT_OK = qw//;

our @HEAD_GAL = qw/id tId tBeg tEnd tSrd tSize
  qId qBeg qEnd qSrd qSize
  ali mat mis qN tN ident score tLoc qLoc/;

  my $ps = [];
  my ($id, $tId, $tBeg, $tEnd, $tSrd, $tSize, 
    $qId, $qBeg, $qEnd, $qSrd, $qSize,
    $ali, $mat, $mis, $qN, $tN, $ident, $score, $tLocS, $qLocS) = @$ps;


1;
__END__
