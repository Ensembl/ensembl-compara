#! /bin/sh

# A simple script to run CVS update on directories used by webteam
# (thus avoiding breaking the API mid-release-cycle!)

web_dirs="conf ensembl-draw ensembl-external htdocs modules perl public-plugins sanger-plugins utils"

timestamp=`date +%Y%m%d%H%M`
ext='.log'
logfile="logs/cvs_up_$timestamp$ext"

# come out of utils directory
cd ..

# update each directory and output to log for easier checking of conflicts, etc.
for var in $web_dirs
do
  echo "Updating directory $var..."
  cd $var
  echo "********** CVS UPDATE - $var **********" >> ../$logfile
  cvs up -dP >&! >> ../$logfile
  cd ..
done 

echo "CVS update complete!"
echo "Output written to $logfile"

exit 1
