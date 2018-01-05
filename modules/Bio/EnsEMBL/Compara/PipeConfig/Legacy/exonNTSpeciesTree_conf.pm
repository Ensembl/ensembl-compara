=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

# init_pipeline.pl exonNTSpeciesTree_conf


package Bio::EnsEMBL::Compara::PipeConfig::Legacy::exonNTSpeciesTree_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;   # For INPUT_PLUS

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
 my ($self) = @_;
 
 return {
  %{$self->SUPER::default_options},
  'pipeline_name' => 'MakeNTSpeciesTree2',
  'db_suffix' => '_new_ExonSpeciesTree_',
# previous release db with alignments
  'previous_release_version' => '74',
  'core_db_version' => 74,
# method_link_species_set_id(s) for the multiple sequence alignments to generate the trees 
  'msa_mlssid_csv_string' => '651,664,667,660',
# and a hash with assoiciated reference species
  'msa_mlssid_and_reference_species' => { 651 => 90,  664 => 142, 667 => 37, 660 => 90, }, 
# coord system name to find genes (applies to all the species)
  'coord_system_name' => 'chromosome',
  'phylofit_exe' => '/software/ensembl/compara/phast/phyloFit', 
  'species_tree_bl' => '~/src/ensembl-compara/scripts/pipeline/species_tree_blength.nh',
# dummy mlss and mlss_id value for the stored species_tree_blength.nh
  'dummy_mlss_value' => 1000000,

  'pipeline_db' => { # the production database itself (will be created)
    -driver => 'mysql',
    -host   => 'compara4',
    -port   => 3306,
    -user   => 'ensadmin',
    -pass   => $self->o('password'),
    -dbname => $self->o('ENV', 'USER').$self->o('db_suffix').$self->o('rel_with_suffix'),
  },

  'core_dbs' => [
   {   
     -driver => 'mysql',
     -user => 'anonymous',
     -port => 5306,
     -host => 'ensembldb.ensembl.org',
     -dbname => '', 
     -db_version => $self->o('core_db_version'),
   },  
#   {   
#    -driver => 'mysql',
#    -user => 'ensro',
#    -port => 3306,
#    -host => 'ens-staging2',
#    -dbname => '',
#    -db_version => $self->o('core_db_version'),
#   },
  ],
# compara db with the alignments (usually the previous release db)
  'previous_compara_db' => {
    -driver  => 'mysql',
    -host    => 'compara3',
    -species => 'Multi',
    -port    => '3306',
    -user    => 'ensro',
    -dbname  => 'mp12_ensembl_compara_74',
  },
 };
}   
  

sub pipeline_wide_parameters {
 my $self = shift @_;
 return {
  %{$self->SUPER::pipeline_wide_parameters},
  
  'previous_compara_db' => $self->o('previous_compara_db'),
  'msa_mlssid_and_reference_species' => $self->o('msa_mlssid_and_reference_species'),
  'msa_mlssid_csv_string' => $self->o('msa_mlssid_csv_string'),
  'dummy_mlss_value' => $self->o('dummy_mlss_value'),
  'core_dbs' => $self->o('core_dbs'),
  'coord_system_name' => $self->o('coord_system_name'),
 };
}
sub resource_classes {
    my ($self) = @_; 
    return {
     %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
  
     'mem3600' => {'LSF' => '-C0 -M3600 -R"select[mem>3600] rusage[mem=3600]"' },
     'mem5600' => {'LSF' => '-C0 -M5600 -R"select[mem>5600] rusage[mem=5600]"' },
    };  
}

 
sub pipeline_analyses {
 my ($self) = @_;
 print "pipeline_analyses\n";
 return [
    @{$self->init_basic_tables_analyses($self->o('previous_compara_db'), 'modify_copied_tables', 1, 1, 0, [{}])},
   
   {
    -logic_name => 'modify_copied_tables',
    -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
    -parameters => {
     'sql' => [
        'DELETE str.*, stn.* FROM species_tree_root str INNER JOIN species_tree_node stn ON str.root_id = stn.root_id '.
        'WHERE str.method_link_species_set_id NOT IN (#msa_mlssid_csv_string#)',

        'DELETE mlss.* FROM method_link_species_set mlss WHERE mlss.method_link_species_set_id NOT IN (#msa_mlssid_csv_string#)',

        'DELETE sh.* FROM species_set_header sh LEFT OUTER JOIN method_link_species_set mlss ON mlss.species_set_id = sh.species_set_id '.
        'WHERE mlss.species_set_id IS NULL',

        'DELETE ss.* FROM species_set ss LEFT OUTER JOIN method_link_species_set mlss ON mlss.species_set_id = ss.species_set_id '.
        'WHERE mlss.species_set_id IS NULL',
   
        'DELETE ml.* FROM method_link ml LEFT OUTER JOIN method_link_species_set mlss ON mlss.method_link_id = ml.method_link_id '.
        'WHERE mlss.method_link_id IS NULL',

	# we need a mlssid for the full compara species tree
	'INSERT INTO species_set_header VALUES (1, "all", NULL, NULL)',
	'INSERT INTO species_set (SELECT 1, genome_db_id FROM genome_db WHERE taxon_id)',
        
        'INSERT INTO method_link VALUES(1000000, "ORIGINAL_TREE", "GenomicAlignTree.tree_alignment")',
   
        'REPLACE INTO method_link_species_set (SELECT '.$self->o('dummy_mlss_value').','.$self->o('dummy_mlss_value').', species_set_id, "ORIGINAL_TREE", "OT", "OT"'.
        'FROM species_set WHERE species_set_id = 1)',
  
        'DELETE gdb.* FROM genome_db gdb LEFT OUTER JOIN species_set ss ON ss.genome_db_id = gdb.genome_db_id '.
        'WHERE ss.genome_db_id IS NULL',
       ],
    },
    -flow_into =>  {
     '2->A' => [ 'mlss_factory' ],
     'A->1' => [ 'merge_msa_trees' ],
    },
   },

   { 
    -logic_name => 'mlss_factory',
    -parameters => { 
     'inputlist'  => '#expr([ split(",", #msa_mlssid_csv_string#) ])expr#',
     'column_names' => [ 'msa_mlssid' ],
    },
    -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
    -flow_into => { 
      2 => [ 'slice_factory' ],
    },  
    -meadow_type=> 'LOCAL',
  },
  
  {
   -logic_name => 'slice_factory',
   -parameters => {},
   -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MakeNTSpeciesTree::SliceFactory',
   -flow_into => {
    2 => [ 'gene_factory' ],
   },
  },

  {
   -logic_name => 'gene_factory',
   -parameters => {},
   -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MakeNTSpeciesTree::GeneFactory',
   -flow_into => {
     2 => [ 'exon_phylofit_factory' ]
   },
  },

  {
   -logic_name => 'exon_phylofit_factory',
   -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MakeNTSpeciesTree::ExonPhylofitFactory',
   -parameters => {
     'previous_compara_db' => $self->o('previous_compara_db'),
     'phylofit_exe' => $self->o('phylofit_exe'),
   },
   -flow_into => {
    '2' => { '?accu_name=phylofit_trees&accu_address={tree_mlss_id}{block_id}&accu_input_variable=phylofit_tree_string' => INPUT_PLUS(), },
   },
   -hive_capacity => 20,
   -batch_size => 10,
   -max_retry_count => 1,
   -rc_name => 'mem3600',
  },
 
  {
   -logic_name => 'merge_msa_trees',
   -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MakeNTSpeciesTree::MergeEMSAtrees',
   -parameters => {'species_tree_bl' => $self->o('species_tree_bl'),},
   -max_retry_count => 1,
  },

 ];
}

1;
