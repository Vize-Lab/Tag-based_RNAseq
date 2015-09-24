#!/usr/bin/perl

my $usage= "

Prints out list of commands for launcher_creator.py 
to trim Illumina RNA-seq reads

Arguments:
1: glob to fastq files
2: database to map to, such as '/work/01211/cmonstr/amil_coralonly/amil_match2aten.fas\'
3: optional, the position of name-deriving string in the file name
	if it is by underscores or dots 
";

if (!$ARGV[0]) { die $usage;}
my $glob=$ARGV[0];
if (!$ARGV[1]) { die $usage;}
my $db=$ARGV[1];


opendir THIS, ".";
my @fqs=grep /$glob/,readdir THIS;
my $outname="";

foreach $fqf (@fqs) {
	if ($ARGV[2]) {
		my @parts=split(/[_\.]/,$fqf);
		$outname=$parts[$ARGV[2]-1].".sam";
	}
	else { $outname=$fqf.".sam";}
	print "gmapper $fqf $db -N 12 --fastq --strata --local --qv-offset 33 >$outname\n";
}

