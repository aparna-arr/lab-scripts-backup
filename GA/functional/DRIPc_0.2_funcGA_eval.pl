#!/usr/bin/env perl
use warnings ;
use strict ;
use Cache::FileCache;

# requires the use of a pre-set cache containing a wig file
# wig file should be span=10
# expects everything to be sorted
# expects wig file has all chrs in bed/fasta files given to stochhmm.

my ($gff, $threshold) = @ARGV ;
die "usage: $0 <stochhmm gff file> <threshold>\n" unless @ARGV == 2;
# going to ignore threshold since using a gff file with only significant regions listed
my $WIGFILE = "dripc_wig_chr8_small"; # SET TO NAME OF WIG IN CACHE
my $SCORE_THRESH = 10; # Set to min score/height for a peak
my $SIG_BLOCKS = 6123; # count these beforehand! Numbers output from make_cache.pl
my $UNSIG_BLOCKS = 592305; 
my $cache = new Cache::FileCache();
$cache -> set_cache_root("/data/aparna/GA/DRIPc/cache2") ; # Set cache root here

my ($name) = $gff =~ /\/(\d+).report$/ ;

if (!`wc -l $gff`){
  die "report file empty!";
}

my ($tp, $fp, $fn, $tn) ;

$fp = 0;
$tp = 0;
$fn = 0;
$tn = 0;
open (IN, "<", $gff) or die "Could not open $gff\n";
my %called; # stochhmm called peaks

while(<IN>) {
  my $line = $_;
  chomp $line ;

  if ($line !~ /^chr/) {
    next ;
  }

  my ($chr, $start, $end) = $line =~ /^chr(.+)\t.+\t.+\t(\d+)\t(\d+)\t.+$/;
  push(@{$called{$chr}}, {start =>$start, end => $end});  
}

close IN;

my $used_sig_blocks; # used significant blocks score > 2*thresh

foreach my $chrom (keys %called) {
  my $wig_chr_ref = $cache -> get("$WIGFILE\.$chrom.cache");
  my @wig_chr = @{$wig_chr_ref}; # should be sorted
  my $index = 0;

  for(my $i = 0; $i < @{$called{$chrom}}; $i++) {
    my $end = $called{$chrom}[$i]{end} ;
    my $start = $called{$chrom}[$i]{start} ;
    my $len = $end - $start ;
    my $siglen = 0;
    my $avg = 0;

    if ($len < 50) {
      $fp += $len; # maybe remove this? so tn count makes more sense.
      next;
    }
    if (!exists($wig_chr[$index]{start})) { # change to if $index == @wig_chr
      last;      
    }

    $index = binary_search($start, \@wig_chr, $index);
    
    while (exists($wig_chr[$index]{start}) && $wig_chr[$index]{start} + 9 <= $end) {

      if ($wig_chr[$index]{value} > 2*$SCORE_THRESH) {
        $used_sig_blocks++ ;
      }

      $avg+=$wig_chr[$index]{value} * 10;
      $index++;
      $siglen++;
    }

    $avg /= $len;

    if (!$siglen) {
      $fp += $len ;       
    }

    elsif ($avg > $SCORE_THRESH/8) {
      $tp += $len ;        
    }
    else {
      $fp += $len ;        
    }
  }   
}

$fn += $SIG_BLOCKS * 10 - $used_sig_blocks * 10;
$tn = $UNSIG_BLOCKS * 10 - $fp;

print "$name,$tp,$tn,$fp,$fn";

sub binary_search {
  my $num = $_[0] ;
  my @indexes = @{$_[1]} ;
  my $min_index = $_[2] ;
  my $first = $min_index ;
  my $last = @indexes - 1 ;
  my $middle = int (($last + $first )/2) ;
  
  if (!exists($indexes[$middle]{start})) {
    die "!exists $middle, prev is $indexes[$middle-1]{start}, last is $last first is $first\n";
  }

  while ($first <= $last) {
    if ($indexes[$middle]{start} < $num) {
      $first = $middle + 1 ;
    }
    elsif ($indexes[$middle]{start} == $num) {
      last ;
    }
    else {
      $last = $middle - 1 ;
    }
    $middle = int (($last + $first)/2) ;
  }

  if ($first > $last) {
    if ($num - $indexes[$middle]{start} > 0) {
      $middle++ ;
    } 
  }
    return ($middle) ; 
}
