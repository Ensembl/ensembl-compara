

#!/bin/sh
#
# When run under LSF $LSB_HOSTS contains a list of hosts
# for us to run on.

#
# Parse host list and start MPI on the hosts
#

#LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/ensembl/lib
#export LD_LIBRARY_PATH 

nb_arg=$#
peptide_file=$1

if [ ! -n $peptide_file ] || [ $nb_arg -gt 1 ]; then
 echo "This script takes one argument and one only, a FASTA file name"
 exit 1
fi

if [ ! -e $peptide_file ]; then
 echo "File $peptide_file does not exist"
 exit 2;
fi

echo "priting out LD_LIBRARY_PATH 1"
echo $LD_LIBRARY_PATH
LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/ensembl/lib
echo "priting out LD_LIBRARY_PATH 2"
echo $LD_LIBRARY_PATH

##for HOST in $LSB_HOSTS; do
## echo $HOST >> /tmp/hostfile.$LSB_JOBID
##done

##lamboot  -v  /tmp/hostfile.$LSB_JOBID

# ADDME: check lamboot actually ran; bail if it didn't

# run clustalw
#
# The mpi options are important. They tell it to use
# fast communication on SMP node.  Check the docs
#

# Parse the LSF hostlist into a format openmpi understands and find the number of CPUs we are running on.
echo $LSB_MCPU_HOSTS | awk '{for(i=1;i <=NF;i=i+2) print $i " slots=" $(i+1); }' >> /tmp/hostfile.$LSB_JOBID
CPUS=`echo $LSB_MCPU_HOSTS | awk '{for(i=2;i <=NF;i=i+2) { tot+=$i; } print tot }'`

# Now run our executable # Do not mess with the options without reading the openMPI FAQ!
mpirun  --mca mpi_paffinity_alone 1 --mca btl tcp,self  --hostfile /tmp/hostfile.$LSB_JOBID  --np $CPUS /usr/local/ensembl/bin/clustalw-mpi -infile=$peptide_file -outfile=$peptide_file.clw

##mpirun C -ssi rpi usysv /usr/local/ensembl/bin/clustalw-mpi -infile=$peptide_file -outfile=$peptide_file.clw

#
# shutdown MPI

##lamhalt

rm /tmp/hostfile.$LSB_JOBID

# ADDME: Add a single handler for the mpi 'wipe' command, which
# will tidy everything up if we need to bkill the job.
