#!/usr/bin/perl

$usage="

samcount:

counts reads mapping to isogrops in SAM files

Arguments <defaults>:

arg1: SAM file (by cluster, contig, or isotig)
arg2: a table in the form 'reference_seq<tab>gene_ID', giving the correspondence of 
reference sequences to genes. With 454-deived transcriptome, the gene_ID would be isogroup; 
with Trinity-derived transcriptiome,it would be component.

dup.reads=keep|toss : whether to remove exact sequence-duplicate reads mapping to the 
same position in the reference. In RNA-seq practice, the duplicates are typically kept. 
We find that tossing them typically improve, rather than hamper, the power to detect DEs 
due to diminishing variation, and is clearly a more conservative way. 
<toss> 

mult.iso=random|toss : if a read maps to multiple isogroups, it is disregarded by default.
Set this option to 'random' if you want to randomly pick an isogroup to assign a count to 
(this is a less conservative, but generally accepted way to deal with multiple mapping) 
<toss>

";

my $t1=shift @ARGV or die $usage;
my $t2=shift @ARGV or die $usage;
my $rmdup="toss";
if ("@ARGV"=~/dup.reads=keep/) { 
	$rmdup="keep";
	warn "\nkeeping duplicate reads\n";
}
else {	warn "\nremoving duplicate reads\n"; }
my $miso="toss";
if ("@ARGV"=~/mult.iso=random/) { 
	$miso="random";
	warn "adding a count to a randomly picked isogroup when a read maps to multiple isogroups\n";
}
else { warn "disregarding reads mapping to multiple isogroups\n"; }

open SAM, $t1 or die "cannot open $t1\n";
open C2I, $t2 or die "cannot open $t2\n";

my %c2i={};
my %count={};
my %hit={};
my %refhit={};
my $c="";
my $i="";
my $f="";
my $r="";
my $pos="";
my $seq="";

while (<C2I>) {
	chop;
	($c,$i)=split(/\s+/,$_);
#	$c=~s/[a-zA-Z]+//;
#	$i=~s/[a-zA-Z]+//;
	$c2i{$c}=$i;
}

while (<SAM>) {
	if ($_=~/^@/) { next;}
	chop;
	($r,$flag,$c,$pos,$mapq,@rest)=split(/\s/,$_);
	if ($mapq==0) { next;}
#	$c=~s/[a-zA-Z]+//;
	$i=$c2i{$c};
	if ($i!~/\d+/) { warn "$c has no isogroup designation\n";} 
	my @sseq=grep(/[ATGCatgc-]{30,}/,@rest);
	next if (!$sseq[0]);
	$seq=$sseq[0];
	my $toss=0;
	if ($rmdup eq "toss") {
		foreach $sr (@{$refhit{$c}{$pos}}) {
			if ($sr=~/$seq/ | $seq=~/$sr/) {
#print "----------\n$c $pos\n",join("\n",@{$refhit{$c}{$pos}}),"\ndiscarding duplicate:\n\t$r\n\t$seq\n\t$sr\n";
				$toss=1;
				last;
			}
		}
	}
	if ($toss==0) {
#print "$c $pos\nadding\n\t$seq\n";
		push @{$refhit{$c}{$pos}},$seq;
		push @{$hit{$r}},$i unless ("@{$hit{$r}}"=~/ $i / | ${$hit{$r}}[0] eq $i | ${$hit{$r}}[$#{$hit{$r}}] eq $i);
	}
}

foreach $r (keys %hit){
	next if ($r=~/HASH/);
	if($#{$hit{$r}}>0) {
		if($miso eq "random") {
			my $pick=${$hit{$r}}[rand @{$hit{$r}}];
			$count{$pick}++;
#print "--------\n$r many hits:\n@{$hit{$r}}\npicked $pick\n";
		}
	}
	else { 
#print "--------\n$r one hit:\n\t@{$hit{$r}}\n\tadding ${$hit{$r}}[0]\n";
		$count{${$hit{$r}}[0]}++;
	}
}

foreach $i (sort keys %count) {
	next if ($i=~/HASH/);
	print "$i\t$count{$i}\n";
}

