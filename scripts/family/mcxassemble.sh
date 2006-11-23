#!/usr/local/bin/bash

nb_arg=$#
file_prefix=$1
subhost=$HOST
pwd=$PWD

if [ ! -n $file_prefix ] || [ $nb_arg -gt 1 ]; then
 echo "This script takes one argument and one only, a prefix filename"
 exit 1
fi

if [ ! -e $file_prefix.tab ] ||  [ ! -e $file_prefix.hdr ] ||  [ ! -e $file_prefix.raw ]; then
 echo "$file_prefix.tab, $file_prefix.hdr or $file_prefix.raw does not exist"
 exit 2
fi

bsub -q bigmem -R 'select[mem>=6000] rusage[mem=6000]' -o $file_prefix.mcxassemble.err \
<<EOF
#!/usr/local/bin/bash 
. /usr/local/lsf/conf/profile.lsf
set -e
pushd /tmp
tmp_prefix=$file_prefix.\$\$
lsrcp $subhost:$pwd/$file_prefix.tab \$tmp_prefix.tab
lsrcp $subhost:$pwd/$file_prefix.hdr \$tmp_prefix.hdr
lsrcp $subhost:$pwd/$file_prefix.raw \$tmp_prefix.raw
/nfs/acari/abel/bin/mcxassemble -b \$tmp_prefix -r max -xo bin --binary
status=\$?
lsrcp \$tmp_prefix.bin $subhost:$pwd/$file_prefix.bin
/bin/rm -f \$tmp_prefix.*
popd
exit \$status
EOF
