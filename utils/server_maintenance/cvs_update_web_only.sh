#!/bin/ksh

# A simple script to run CVS update on directories used by webteam
# (thus avoiding breaking the API mid-release-cycle!)

web_dirs="conf ensembl-draw ensembl-external htdocs modules perl public-plugins sanger-plugins utils"

timestamp=$(date +"%Y%m%d%H%M")
ext='.log'
logfile="logs/cvs_up_$timestamp$ext"

if [[ ${PWD##*/} == "utils" ]]; then
  # Back out of the utils directory
  cd ..
elif [[ -d utils ]]; then
  : # We're in the right place
else
  # We don't know where we are or where we're supposed to be
  print -u2 "Please runt this script from the 'utils' directory"
  print -u2 "or from its parent directory"
  exit 1
fi

# Update each directory and output to log for easier checking
# of conflicts, etc.
for var in $web_dirs; do
  echo "Updating directory $var..."
  (
    cd $var
    print "********** CVS UPDATE - $var **********"
    cvs -q up -dP
  ) >>$logfile 2>&1
done 

print "CVS update complete!"
print "Output written to $logfile"
