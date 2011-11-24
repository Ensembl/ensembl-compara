#! /bin/bash

# Usage :
#   cat ensembl-compara/sql/protein_tree-stats.sql | mysql.l compara2 mm14_compara_homology_65 -H | sed 's/\/TABLE>/\/TABLE>\n/g' | grep -v optimize | bash ensembl-compara/scripts/pipeline/get_stats_trees.sh pt > public-plugins/ensembl/htdocs/info/docs/compara/protein_trees.inc 
#   cat ensembl-compara/sql/protein_tree-stats.sql | sed 's/protein/nc/g' | sed 's/ENSEMBLPEP/ENSEMBLTRANS/' | sed 's/pep/trans/g' | mysql.l compara2 mp12_compara_nctrees_65 -H | sed 's/\/TABLE>/\/TABLE>\n/g' | grep -v optimize | bash ensembl-compara/scripts/pipeline/get_stats_trees.sh nc > public-plugins/ensembl/htdocs/info/docs/compara/nc_trees.inc


nentries=3

anchor[1]='coverage'
anchor[2]='sizes'
anchor[3]='treenodes'

title[1]='Gene coverage'
title[2]='Tree size'
title[3]='Predicted gene events'

desc[1]='Number of genes and members in total, included in trees (either species-specific, or encompassing other species), and orphaned (not in any tree)'
desc[2]='Sizes of trees (genes, and distinct species), grouped according to the root ancestral species'
desc[3]='For each ancestral species, number of speciation and duplication nodes (inc. dubious ones), with the average duplication score'


echo "<a name='$1_top'/><ul>"

for i in `seq 1 $nentries`
do
	echo "<li><a href='#$1_${anchor[$i]}'>${title[$i]}</a>: ${desc[$i]}</li>"
done

echo "</ul>"

for i in `seq 1 $nentries`
do
	echo "<br/><a name='$1_${anchor[$i]}' href='#$1_top'>Top&uarr;</a><h3>${desc[$i]}</h3>"
	read line
	echo $line | sed 's/BORDER=1/class="ss tint" style="width:auto"/'
done


