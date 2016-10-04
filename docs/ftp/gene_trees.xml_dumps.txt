More information about the file formats can be found:
 - OrthoXML at http://orthoxml.org
 - PhyloXML at http://www.phyloxml.org

This directory contains all the XML dumps of the gene-tree related resources:
 - the gene trees themselves
 - the orthologies, which are derived from the gene trees
 - the CAFE trees, which analyze the expansion and contraction of gene families

Compara.{release}.{protein|ncrna}_{species_collection}.allhomologies.orthoxml.xml.gz
  Contains all the orthologies in a single OrthoXML file. Each orthology is
  stored as an orthologGroup containing two genes.

Compara.{release}.{protein|ncrna}_{species_collection}.allhomologies_strict.orthoxml.xml.gz
  Contains all the "strict" orthologies in a single OrthoXML file. Each
  orthology is stored as an orthologGroup containing two genes.
  In this file, all the homologies are fully compliant with the species tree.

Compara.{release}.{protein|ncrna}_{species_collection}.alltrees.orthoxml.xml.gz
  Contains all the trees in a single OrthoXML file. All the trees are
  attached to the root 'groups' tag.


The following three files are tar archives containing one file per tree.
CAUTION: Be aware that untaring any of these files will create in your current
	   directory hundreds or thousands of files !

Compara.{release}.{protein|ncrna}_{species_collection}.tree.orthoxml.tar.gz
  Each file will contain one tree, in OrthoXML format.

Compara.{release}.{protein|ncrna}_{species_collection}.tree.phyloxml.tar.gz
  Each file will contain one tree, in PhyloXML format.

Compara.{release}.{protein|ncrna}_{species_collection}.tree.cafe_phyloxml.tar.gz
  Each file will contain one CAFE tree, in PhyloXML format.

