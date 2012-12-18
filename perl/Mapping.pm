package Mapping;
use strict;
use Init;
use Common;
use Data::Dumper;
use Mtb;
use Gtb;
use List::Util qw/min max sum/;
use List::MoreUtils qw/first_index first_value insert_after apply indexes pairwise zip uniq/;
use vars qw/$VERSION @ISA @EXPORT @EXPORT_OK/;
require Exporter;
@ISA = qw/Exporter/;
@EXPORT = qw/pipe_blat pipe_gmap pipe_manual/;
@EXPORT_OK = qw//;

sub run_blat {
    my ($fi, $db, $fo, $qryType, $dbType) = 
        rearrange(["in", "db", "out", 'qrytype', 'dbtype'], @_);
    die "$fi is not there\n" unless -s $fi;
    $qryType ||= "dna";
    $dbType  ||= "dna";
    my $fDb = "$DIR_Db/blat/$db.2bit";
    die "$fDb is not there\n" unless -s $fDb;
    my $fOoc = "$DIR_Db/blat/$db\_11.ooc";
    unless( -s $fOoc ) {
        print "Ooc-file not exist -> making one\n";
        runCmd("blat $fDb $fi $fo -makeOoc=$fOoc", 1);
    }
    runCmd("blat $fDb $fi $fo -ooc=$fOoc -t=$dbType -q=$qryType -noTrimA", 1);
}
sub run_gmap {
    my ($fi, $fo, $p) = @_;
    my ($db, $skip) = map {$p->{$_}} qw/refdb skip/;
    $db ||= "mt_35";
    $skip = defined $skip ? $skip : 0;
    if($skip == 0) {
        print "\tmapping to $db\n";
        runCmd("gmap -d $db -t 4 -f 1 $fi > $fo");
    }
}

sub getGmapCoord {
    my ($fi) = @_;
    die "$fi is not there\n" unless -s $fi;
    open(FH, "<$fi");
    my $rst = {};
    while( <FH> ) {
        chomp;
        next if /^\#/;
        my @ps = split("\t");
        if($ps[1] =~ /^(\w+)\:(\d+)\.\.(\d+)$/) {
            $rst->{$1} = [] unless exists $rst->{$1};
            push @{$rst->{$1}}, [$2, $3, $ps[0]];
        } else{
            die "unknown coord format: ".$ps[1]."\n";
        }
    }
    return $rst;
}
sub g2L {
    my ($cName, $cStart, $cEnd, $cHash) = rearrange(['name', 'start', 'end', 'chash'], @_);
    my ($bName, $bStart, $bEnd, $bSize);
    my $flag = 0;
    for my $chrName (sort keys(%$cHash)) {
        next if $chrName ne $cName;
        my $idx = first_index {$_->[0]<=$cStart && $_->[1]>=$cStart} @{$cHash->{$chrName}};
        my $hit = $cHash->{$chrName}->[$idx];
        my ($hitStart, $hitEnd, $hitName) = @$hit[0..2];
        if($hitEnd < $cEnd) {
            print "\t$cName:$cStart..$cEnd across bac[$hitName] $chrName:$hitStart..$hitEnd\n";
            $flag = -1;
        } else {
            $bName = $hitName;
            $bStart = $cStart - $hitStart + 1;
            $bEnd   = $cEnd   - $hitStart + 1;
            $bSize  = $hitEnd - $hitStart + 1;
            $flag = 1;
        }
    }
    if($flag == -1) {
        return (-1);
    } elsif($flag == 0) {
        die "cannot find BAC\[$cName\]\n";
    } else {
        return ($bName, $bStart, $bEnd, $bSize);
    }
}
sub gmapCoordConv {
    my ($fi, $fo, $p) = @_;
    my $db = $p->{refdb};
    my $fC = "$DIR_Data/db/gmap/coords.$db";
    my $cHash = getGmapCoord($fC);
    my $t = readTable(-in=>$fi, -header=>1);
    my @rowsD;
    for my $i (0..$t->nofRow-1) {
        my ($hId, $hLocStr) = map {$t->elm($i, $_)} qw/hId hLoc/;
        my $hLoc = locStr2Obj($hLocStr, $hId);
        die "hit strand not 1\n" unless $hLoc->strand == 1;
        my ($hS, $hE) = ($hLoc->start, $hLoc->end);
        my ($hId1, $hS1, $hE1, $hLen1) = g2L(-name=>$hId, -start=>$hS, -end=>$hE, -chash=>$cHash);
        if($hId1 eq -1) {
            push @rowsD, $i;
            print "cannot find location for $hLocStr\n";
            next;
        }
        my $loc = Bio::Location::Split->new();
        for ($hLoc->each_Location(1)) {
            my ($s, $e) = ($_->start, $_->end);
            my ($s1, $e1) = map {$_-$hS+$hS1} ($s, $e);
            $loc->add_sub_Location(Bio::Location::Simple->new(-start=>$s1, -end=>$e1, -strand=>1));
        }
        my ($hLocStr1) = locObj2Str($loc);
        $t->setElm($i, "hLoc", $hLocStr1);
        $hId1 =~ s/^(\d)$/chr$1/;
        $t->setElm($i, "hId", $hId1);
    }
    $t->delRows(\@rowsD);
    my $fh = new IO::File $fo, "w";
    print $fh $t->tsv(1);
}

sub mappingStat {
    my ($fi, $colId, $colLoc) = @_;
    $colId ||= "idQ";
    $colLoc ||= "locQ";
    my $t = readTable(-in=>$fi, -header=>1);
    $t->sort($colId, 1, 0);
    my $ref = group($t->colRef($colId));
    my $cntQ = scalar(keys %$ref);
    printf "%d queries:\n", $cntQ;
    my $nLocCol = first_index {$_ eq $colLoc} $t->header;
    my $t2 = $t->match_pattern("\$_->[$nLocCol] eq ''");
    my $cntUn = $t2->nofRow;
    printf "  %d are not mapped\n", $cntUn;
    my $cntMa = $cntQ - $cntUn;
    my $cntH = $t->nofRow - $cntUn;
    printf "  %d are mapped to %d positions:\n", $cntMa, $cntH;
    my @dups = grep {$ref->{$_}->[1] > 1} keys %$ref;
    my $cntDupHits = @dups ? sum( map {$ref->{$_}->[1]} @dups ) : 0;
    my $uniq = $cntMa - @dups;
    printf "    %d are uniquely mapped\n", $uniq;
    printf "    %d are non-uniquely mapped to %d positions\n", scalar(@dups), $cntDupHits;
}

sub pipe_blat {
    my ($f01, $dir, $p) = rearrange(['fseq', 'dir', 'p'], @_);
    my $f02 = "$dir/02.psl";
    run_blat(-in=>$f01, -db=>$p->{refdb}, -out=>$f02, -qrytype=>'dna');
    my $f03 = "$dir/03.mtb";
    psl2Mtb($f02, $f03);
    my $f05 = "$dir/05_filtered.mtb";
    mtbFilter($f03, $f05, $p);
    my $f06 = "$dir/06_rmdup.mtb";
    mtbRmDup($f05, $f06);
    my $f07 = "$dir/07_all.mtb";
    mtbExpand(-fi=>$f06, -fs=>$f01, -fo=>$f07);
    mappingStat($f07);
    my $f08 = "$dir/08.gtb";
    mtb2Gtb($f07, $f08, 1);
    my $f09 = "$dir/09.gff";
    gtb2Gff($f08, $f09);
}
sub pipe_gmap {
    my ($f01, $dir, $p) = rearrange(['fseq', 'dir', 'p'], @_);
    my $f02 = "$dir/02.psl";
    run_gmap($f01, $f02, $p);
    my $f03 = "$dir/03.mtb";
    psl2Mtb($f02, $f03);
    my $f04 = "$dir/04.mtb";
    gmapCoordConv($f03, $f04, $p);
    my $f05 = "$dir/05_filtered.mtb";
    mtbFilter($f04, $f05, $p);
    my $f06 = "$dir/06_rmdup.mtb";
    mtbRmDup($f05, $f06);
    my $f07 = "$dir/07_all.mtb";
    mtbExpand(-fi=>$f06, -fs=>$f01, -fo=>$f07);
    mappingStat($f07);
    my $f08 = "$dir/08.gtb";
    mtb2Gtb($f07, $f08, 1);
    my $f09 = "$dir/09.gff";
    gtb2Gff($f08, $f09);
}
sub pipe_manual {
    my ($dir) = @_;
    my $f11 = "$dir/11.mtb";
    mappingStat($f11);
    my $f12 = "$dir/12.gtb";
    mtb2Gtb($f11, $f12, 1);
    my $f13 = "$dir/13.gff";
    gtb2Gff($f12, $f13);
}


1;
__END__
