#### Indexing scripts
#
# These two scripts have been add to the utilities
# directory - and are for use in creating search engine
# databases
#
#### Scripts
#
# prepareFeatureDumps - dumps the dna-align and pep-align
#                       tables in both the core and est
#                       databases to text files
#
# indexDumper - creates tab-delimited text files ready
#               for converting to an index with your
#               favourite indexing tool
#
#### File paths
#
# each of these scripts create files in the current
# directory - with the following structure:
# 
#       input/{species}/{name}.txt
#
# Output from prepareFeatureDumper have file names of the
# form dump-*.txt
#
#### Running the scripts...
#
# The simplest execution is:
#
#   ./prepareFeatureDumps ALL
#   ./indexDumper ALL ALL
#
# which will run all the indexers for each species one
# after the other
# Each of the scripts can be run on a subset of species/
# indecies
# the first parameter is a ":" separated list of species:
# e.g.
#
#    ./prepareFeatureDumps Homo_sapiens:Mus_musculus:Fugu_rubripes
#
# The remaining parameters are a list of indecies
#
#    ./indexDumper Homo_sapiens:Mus_musculus:Fugu_rubripes Gene Peptide
#
# This allows the scripts to be run in parallel or only on 
# those indexes which have changed.
#
#### File formats
#
# The output of indexDumper is a tab delimited file with the following
# columns
#
#    species (optional - only output if INC_SPECIES is true)
#    Type of feature
#    Primary ID of feature
#    URL to link to
#    string to search over
#    Formatted HTML to display in return from search engine
#
#### How they work - how to extend...
#
# indexDumper works by looking for a function called dumpXXX
# if index XXX is asked for - so to add an additional index
# add a new function called dumpNewIndex and it will get executed
#
# The only odd function is dumpFeature which creates four indecies:
#
#  EST
#  MRNA
#  Protein
#  UniGene
#
#### Contact details
#
# Scripts lovingly crufted by James Smith (js5@sanger.ac.uk)
#
####
