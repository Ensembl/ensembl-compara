#!/bin/sh
#
# When run under LSF $LSB_HOSTS contains a list of hosts
# for us to run on.

#
# Parse host list and start MPI on the hosts
#

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

for HOST in $LSB_HOSTS; do
 echo $HOST >> /tmp/hostfile.$LSB_JOBID
done

lamboot  -v  /tmp/hostfile.$LSB_JOBID

# ADDME: check lamboot actually ran; bail if it didn't

# run clustalw
#
# The mpi options are important. They tell it to use
# fast communication on SMP node.  Check the docs
#

mpirun C -ssi rpi usysv /usr/local/ensembl/bin/clustalw-mpi -infile=$peptide_file -outfile=$peptide_file.clw

#
# shutdown MPI

lamhalt

rm /tmp/hostfile.$LSB_JOBID

# ADDME: Add a single handler for the mpi 'wipe' command, which
# will tidy everything up if we need to bkill the job.
