#!/usr/local/bin/bash

nb_arg=$#
file_prefix=$1
subhost=$HOST
pwd=$PWD

if [ ! -n $file_prefix ] || [ $nb_arg -gt 1 ]; then
 echo "This script takes one argument and one only, a prefix filename"
 exit 1
fi

if [ ! -e $file_prefix.sym ]; then
 echo "$file_prefix.sym does not exist"
 exit 2
fi

bsub -q bigmem -R 'select[mem>2000] rusage[mem=3000] alpha' -o $file_prefix.mcx.err \
<<EOF
#!/usr/local/bin/bash 
. /usr/local/lsf/conf/profile.lsf
set -e
pushd /tmp
tmp_prefix=$file_prefix.\$\$
lsrcp $subhost:$pwd/$file_prefix.sym \$tmp_prefix.sym
/nfs/acari/abel/bin/mcx /\$tmp_prefix.sym lm tp -1 mul add /\$tmp_prefix.sym.check wm
status=\$?
lsrcp \$tmp_prefix.sym.check $subhost:$pwd/$file_prefix.sym.check
/bin/rm -f \$tmp_prefix.*
popd
exit \$status
EOF
