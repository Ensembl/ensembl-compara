=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

# init_pipeline.pl NTSpeciesTree_conf.pm msa_mlssid_list --msa_mlssid_list [619,641]


package Bio::EnsEMBL::Compara::PipeConfig::NTSpeciesTree_conf;

use strict;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
 my ($self) = @_;
 
 return {
  %{$self->SUPER::default_options},
  'pipeline_name' => 'MakeNTSpeciesTree',
  'db_suffix' => '_NTspeciesTree_',
# previous release db with alignments
  'previous_release_version' => '74',
  'core_db_version' => 74,
# list of method_link_species_set_id(s) for the multiple sequence alignments to generate the trees from 
  'msa_mlssid_csv_string' => join(',', qw(651 664 667 660)), 
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
     -user => 'ensro',
     -port => 3306,
     -host => 'ens-livemirror',
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
    -host    => 'ens-livemirror',
    -species => 'Multi',
    -port    => '3306',
    -user    => 'ensro',
    -dbname  => 'ensembl_compara_74',
  },
 };
}   
  
sub pipeline_create_commands {
 my ($self) = @_;
 return [ 
  @{$self->SUPER::pipeline_create_commands},
 ];
}

sub pipeline_wide_parameters {
 my $self = shift @_;
 return {
  %{$self->SUPER::pipeline_wide_parameters},
  
  'previous_compara_db' => $self->o('previous_compara_db'),
  'msa_mlssid_csv_string' => $self->o('msa_mlssid_csv_string'),
  'dummy_mlss_value' => $self->o('dummy_mlss_value'),
 };
}
sub resource_classes {
    my ($self) = @_; 
    return {
     %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
  
     'mem3600' => {'LSF' => '-C0 -M3600 -R"select[mem>3600] rusage[mem=3600]"' },
     'mem5600' => {'LSF' => '-C0 -M5600 -R"select[mem>5600] rusage[mem=5600]"' },
     'mem6600max' => {'LSF' => '-C0 -M6600 -R"select[mem>6600] rusage[mem=6600]" -W01:30' },
    };  
}

 
sub pipeline_analyses {
 my ($self) = @_;
 print "pipeline_analyses\n";
 return [
   {
    -logic_name => 'table_list_to_copy',
    -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
    -input_ids => [{}],
    -parameters => {
     'inputlist'    => [ 'genome_db', 'species_set', 'method_link', 'method_link_species_set', 
                         'species_tree_node', 'species_tree_root', 'ncbi_taxa_name', 'ncbi_taxa_node'  ],
     'column_names' => [ 'table' ],
    },
    -flow_into => {
     '2->A' => [ 'copy_tables' ],
     'A->1' => [ 'modify_copied_tables' ],
    },
   },

   {
     -logic_name => 'copy_tables',
     -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer', 
     -parameters => {
      'src_db_conn'   => $self->o('previous_compara_db'),
      'mode'          => 'overwrite',
      'filter_cmd'    => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/"',
     },
   },
   
   {
    -logic_name => 'modify_copied_tables',
    -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
    -parameters => {
     'sql' => [
        'DELETE str.*, stn.* FROM species_tree_root str INNER JOIN species_tree_node stn ON str.root_id = stn.root_id '.
        'WHERE str.method_link_species_set_id NOT IN (#msa_mlssid_csv_string#)',

        'DELETE mlss.* FROM method_link_species_set mlss WHERE mlss.method_link_species_set_id NOT IN (#msa_mlssid_csv_string#)',

        'DELETE ss.* FROM species_set ss LEFT OUTER JOIN method_link_species_set mlss ON mlss.species_set_id = ss.species_set_id '.
        'WHERE mlss.species_set_id IS NULL',
   
        'DELETE ml.* FROM method_link ml LEFT OUTER JOIN method_link_species_set mlss ON mlss.method_link_id = ml.method_link_id '.
        'WHERE mlss.method_link_id IS NULL',

	# we need a mlssid for the full compara species tree
	'INSERT INTO species_set (SELECT 1, genome_db_id FROM genome_db WHERE taxon_id)',
        
        'INSERT INTO method_link VALUES(1000000, "ORIGINAL_TREE", "GenomicAlignTree.tree_alignment")',
   
        'REPLACE INTO method_link_species_set (SELECT '.$self->o('dummy_mlss_value').','.$self->o('dummy_mlss_value').', species_set_id, "ORIGINAL_TREE", "OT", "OT"'.
        'FROM species_set WHERE species_set_id = 1)',
  
        'DELETE gdb.* FROM genome_db gdb LEFT OUTER JOIN species_set ss ON ss.genome_db_id = gdb.genome_db_id '.
        'WHERE ss.genome_db_id IS NULL',
       ],
    },
    -flow_into => 'mlss_factory',
   },

   { 
    -logic_name => 'mlss_factory',
    -parameters => { 
     'inputlist'  => '#expr([ eval #msa_mlssid_csv_string#])expr#',
     'column_names' => [ 'msa_mlssid' ],
    },
    -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
    -flow_into => { 
      2 => [ 'phylofit_factory' ],
      1 => [ 'merge_msa_trees' ],
    },  
    -meadow_type=> 'LOCAL',
  },

  {
   -logic_name => 'phylofit_factory',
   -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MakeNTSpeciesTree::PhylofitFactory',
   -parameters => {
     'previous_compara_db' => $self->o('previous_compara_db'),
   },
   -flow_into => { 
    '2' => [ 'run_phylofit' ],
   },  
   -max_retry_count => 1,
   -rc_name => 'mem3600',
  },
  
  {
   -logic_name => 'run_phylofit',
   -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MakeNTSpeciesTree::RunPhylofit',
   -parameters => {
    'phylofit_exe' => $self->o('phylofit_exe'),
    'previous_compara_db' => $self->o('previous_compara_db'),
    'core_dbs' => $self->o('core_dbs'),
   },
   -failed_job_tolerance => 90,
   -hive_capacity => 60,
   -batch_size => 10,
   -rc_name => 'mem6600max',
   -max_retry_count => 1,
  },
 
#  {
#   -logic_name => 'run_phylofit_more_mem',
#   -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MakeNTSpeciesTree::RunPhylofit',
#   -parameters => {
#    'phylofit_exe' => $self->o('phylofit_exe'),
#    'previous_compara_db' => $self->o('previous_compara_db'),
#    'core_dbs' => $self->o('core_dbs'),
#   },
#   -max_retry_count => 1,
#   -rc_name => 'mem5600',
#   -hive_capacity => 50, 
#  },

  {
   -logic_name => 'merge_msa_trees',
   -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MakeNTSpeciesTree::MergeMSATrees',
   -parameters => {'species_tree_bl' => $self->o('species_tree_bl'),},
   -max_retry_count => 1,
   -wait_for => [ 'run_phylofit' ],
  },

 ];
}

1;
