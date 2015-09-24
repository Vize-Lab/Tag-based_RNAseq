
Firstly: make sure you have the following tools installed and 
available on your cluster:
python
SHRiMP
fastx_toolkit

(On TACC lonestar cluster, simply say
module load python
module load shrimp
module load fastx_toolkit
)

# installing RNA-seq processing scripts on your cluster:
# on your laptop: open terminal (on Windows, PuTTY), then:

ssh yourUserName@your.cluster
# punch in your password

#-----------------------
# installing RNA-seq scripts and setting up the workspace

# switch to root directory
cd 

# unless you have done it in the past, make directory called bin, 
# all your script should go in there:
mkdir bin 

# switch to bin:
cd bin 

# get the compressed scripts using wget:
wget http://www.bio.utexas.edu/research/matz_lab/matzlab/Methods_files/iRNAseq_SAM.zip

# unzip it:
unzip iRNAseq_SAM.zip 

# list the contents of the directory to make sure it worked
ll

# switch to the newly generated iRNAseq_SAM directory:
cd iRNAseq_SAM

# move all the files out of here one directory level up, so they will be in ~/bin/
mv * ../

# with directory one level up (to ~/bin/):
cd ..

# list the contents:
ll

# remove unnecessary files:
rm -rf iRNAseq_SAM*
rm -rf __MACOSX/

# list the full path to ~/bin/:
pwd

# mark and copy (command-C or control-C) the printout of pwd - you will need to paste it soon

#--------------------------------
# setting up working environment:

# switch to root:
cd 

# start nano editor on the file that will hold your environmental settings
nano .profile_user 

# paste this line, replacing "/pwd-path/copied/earlier/bin" with the path 
# with path copied from pwd output above:
export PATH="/pwd-path/copied/earlier/bin/:$PATH"

# press these keys to save it and exit (note what happens on the screen):
	ctrl-O - enter
	ctrl-X - enter

# make the environment changes take effect (will happen automatically next time you log in):
source .profile_user

#------------------------------
# configuring job creator file launcher_creator.py for easier use:

# switch to ~/bin/:
cd
cd bin

# start editing launcher_creator.py with nano:
nano launcher_creator.py
#	under def main(): 
#		edit the line saying 'email' to say default="you@myuniversity.edu"
#		edit the line saying 'allocation' to say default="yourAllocationBudget"
	ctrl-O - enter
	ctrl-X - enter
	
#------------------------------
# downloading sequence data: 

cd /where/you/want/readFilesToBe/

# download sequence files from a web link, if you were given one
wget http://blah/blah/*

# or you may need to use secure-copy:
scp yourUserName@computer.that.has.read.files:/path/to/read/files/* .

#-------------------------------
# unzipping and concatenating sequence files

# NOTE: if the jobs created by launcher_creator.py below don't run on your cluster,
# consult with the sysadmin of the cluster to see which parameters must be
# specified in the job header, and ask him/her to edit launcher_creator.py 
# accordingly for you - this should take approx. 30 seconds. 
  
# creating and launching a cluster job to unzip all files:
echo 'gunzip *.gz' >gunz
launcher_creator.py -j gunz -n gunz -l gunz.job
qsub gunz.job

# check status of your job (qw : in queue; r : running; nothing printed on the screen - complete) 
qstat 

# If your samples are split across multiple files from different lanes, 
# concatenating the corresponding fastq files by sample:
ngs_concat.pl commonTextInFastqFilenames  "FilenameTextImmediatelyBeforeSampleID(.+)FilenameTextImmediatelyAfterSampleID"

# make a directory to put away your raw files:
mkdir Raw

# move them all there:
mv commonTextInRawFastqFilenames Raw/

# look at the reads:
head -50 SampleName.fq 

# this little one-liner will show sequence-only:
head -100 SampleName.fq | grep -E '^[ACGT]+$'

#------------------------------
# adaptor and quality trimming:

# creating and launching the cleaning process for all files in the same time:
	# NOTE: if you get an error saying something about invalid quality values,
	# replace the first of the three lines below with this one: 
	# iRNAseq_trim_launch.pl '\.fq$' > clean 
iRNAseq_trim_launch_bgi.pl '\.fq$' > clean
launcher_creator.py -j clean -n clean -l clean.job
qsub clean.job

# how the job is doing?
qstat

# It is complete! I got a bunch of .trim files that are non-empty! 
# but did the trimming really work? 
# Use the same one-liner as before on the trimmed file to see if it is different
# from the raw one that you looked at before:
head -100 SampleName.fq.trim | grep -E '^[ACGT]+$'

#--------------------------------------
# download and format reference transcriptome:

cd /where/you/want/your/genomes/toLive/
mkdir db
cd db
# download the transcriptome data using wget or scp, for example, for A.millepora
wget https://dl.dropboxusercontent.com/u/37523721/A.millepora_igmNN_reannot_sep2013.zip
unzip A.millepora_igmNN_reannot_sep2013.zip
rm -rf __MACOSX/
cd A.millepora
pwd
# copy pwd result: /path/to/reference/ 

# go back to /where/reads/are/
cd /where/reads/are/

#--------------------------------------
# mapping reads to the transcriptome with SHRiMP (gmapper program) 
# replace /path/to/reference/myTranscriptome.fasta in the line below with the actual path 
# you just copied and the transcriptome's filename:
	# NOTE: if you had to run alternative command for trimming above, remove "| perl -pe 's/--qv-offset 33//' "
	# from the following line
iRNAseq_shrimpmap_SAM.pl trim /path/to/reference/myTranscriptome.fasta 1 | perl -pe 's/--qv-offset 33//' > maps
launcher_creator.py -j maps -n maps -l mapsjob 
cat mapsjob | perl -pe 's/12way \d+/1way 288/' | perl -pe 's/development/normal/'> maps.job
qsub maps.job

# how is the job?
qstat

# complete! I got a bunch of larch .sam files.
# what is the mapping efficiency? This will find relevant lines in the "job output" file
# that was created while the mapping was running
grep "Reads Matched" maps.e*

#---------------------------------------
# almost done! Just two small things left:
# generating read-counts-per gene: (again, creating a job file to do it simultaneously for all)

# NOTE: Must have a tab-delimited file giving correspondence between contigs in the transcriptome fasta file
# and genes. Typicaly, each gene is represented by several contigs in the transcriptome. 
# For Newbler-assembled (454-based) transcriptomes, this would be a table of contigs correspondence
# to isogroups. For Trinity transcriptomes, it would be contigs to components table.

samcount_launch.pl '\.sam' /path/to/reference/myTranscriptome_contig2gene.tab > sc
launcher_creator.py -j sc -n sc -l sc.job
qsub sc.job

# check on the job
qstat

# done! a bunch of .counts files were produced.
# assembling them all into a single table:
expression_compiler.pl *.sam.counts > allcounts.txt

# make sure allcounts.txt actually contains counts:
head allcounts.txt

# display full path to where you were doing all this:
pwd
# copy the path!

#---------------------------------------
# whew. Now just need to copy the result to your laptop!

# open new terminal window on Mac, or WinSCP on Windows
# navigate to the directory you want the file to be. 

# copy the file from lonestar using scp (in WinSCP, just paste the path you just copied
# into an appropriate slot (should be self-evident) and drag the allcounts.txt file
# to your local directory):

scp yourUserName@your.cluster:/path/you/just/copied/allcounts.txt .

# DONE! Next, we will be using R to make sense of the counts...







