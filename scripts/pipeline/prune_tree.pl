#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2017] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


use warnings;
use strict;

use Getopt::Long;

use Bio::EnsEMBL::Utils::IO qw/:spurt/;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::SpeciesTree;
use Bio::EnsEMBL::Compara::Graph::NewickParser;

#
# Script to take a full species tree and a set of required species taken from a database
# and prune it to leave only the required species.
#

my $help;
my $url;
my $tree_file;
my $output_taxon_file;
my $output_tree_file;
my $species_set_id;

GetOptions('help'        => \$help,
       'url=s'          => \$url,
       'tree_file=s'       => \$tree_file,
	   'taxon_output_filename=s' => \$output_taxon_file,
	   'njtree_output_filename=s' => \$output_tree_file,
    'species_set_id=i'  => \$species_set_id,
);

if ($help) { usage(); }

my $compara_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-url => $url)
    or die "Must define a url";

if (defined $output_taxon_file) {
    my $species_tree    = Bio::EnsEMBL::Compara::Utils::SpeciesTree->create_species_tree(-COMPARA_DBA => $compara_dba);

    spurt($output_taxon_file, $species_tree->newick_format('ncbi_taxon'));
}

if (defined $output_tree_file) {

    my $blength_tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree( `cat $tree_file` );
    my $pruned_tree  = Bio::EnsEMBL::Compara::Utils::SpeciesTree->prune_tree( $blength_tree, $compara_dba, $species_set_id );

    spurt($output_tree_file, $pruned_tree->newick_format('simple'));
}

sub usage {
  warn "Specifically used in the LowCoverageGenomeAlignment pipeline\n";
  warn "prune_tree.pl [options]\n";
  warn "  -help                          : print this help\n";
  warn "  -url <url>                     : connect to compara at url and use \n";
  warn "  -tree_file <file>              : read in full newick tree from file\n";
  warn "  -taxon_output_filename <file>  : filename to write taxon_ids to\n";
  warn "  -njtree_output_filename <file> : filename to write pruned treee to\n";
  warn "  -species_set_id <int>          : the ID of the species set giving the list of species (all the species, otherwise)\n";
  warn "NOTE: The matching is done on the name\n";
  exit(1);  
}

