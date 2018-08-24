=pod

=head1 NAME

    InsertPseudogenesInAllTrees

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Hive::Examples::Factories::PipeConfig::RunListOfCommandsOnFarm_conf -password <your_password> -inputfile file_with_cmds.txt

=head1 DESCRIPTION

    This is an example pipeline put together from basic building blocks:

    Analysis_1: JobFactory.pm is used to turn the list of commands in a file into jobs

        these jobs are sent down the branch #2 into the second analysis

    Analysis_2: SystemCmd.pm is used to run these jobs in parallel.

=head1 LICENSE

    Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
    Copyright [2016-2017] EMBL-European Bioinformatics Institute

    Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

         http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software distributed under the License
    is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and limitations under the License.

=head1 CONTACT

    Please subscribe to the Hive mailing list:  http://listserver.ebi.ac.uk/mailman/listinfo/ehive-users  to discuss Hive-related questions or to be notified of our updates

=cut


package Bio::EnsEMBL::Compara::PipeConfig::InsertPseudogenesInAllTrees;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly

=head2 default_options

    Description : Implements default_options() interface method of Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf that is used to initialize default options.
                  In addition to the standard things it defines three options:
                    o('capacity')   defines how many files can be run in parallel
                
                  There are rules dependent on two options that do not have defaults (this makes them mandatory):
                    o('password')           your read-write password for creation and maintenance of the hive database
                    o('inputfile')          name of the inputfile where the commands are

=cut

sub default_options {
    my ($self) = @_;
    return {
       %{ $self->SUPER::default_options() },               # inherit other stuff from the base class

      'pipeline_name' => 'PopulateTrees',                  # name used by the beekeeper to prefix job names on the farm
      'capacity'  => 100,                                 # how many commands can be run in parallel
      'treebest_exe' => '/nfs/software/ensembl/latest/linuxbrew/bin/treebest',
      'mafft_home' => '/nfs/software/ensembl/latest/linuxbrew/',
      'low_mem_capacity' => 100,
      'high_mem_capacity' => 40,
      'copy_db' => 1,
      'main_core_dbs' => [{
                -user => 'ensro',
                -port => 4240,
                -host => 'mysql-ensembl-mirror.ebi.ac.uk',
                -driver => 'mysql',
                -dbname => '',
                -db_version => 93,
            },],
       'registry_url' => 'mysql://ensro@mysql-ensembl-mirror:4240/92',
       'pseudopipe_data' => $self->o('ensembl_cvs_root_dir')."ensembl-compara/modules/Bio/EnsEMBL/Compara/PipeConfig/Example/PseudopipeFactoryInfo.txt",
    };
}

sub pipeline_checks_pre_init {
    my ($self) = @_;
 
}

sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class

        'compara_db'     => $self->o('compara_db'),
        'db_conn'        => $self->o('db_conn'),

        'treebest_exe'   => $self->o('treebest_exe'),
        'mafft_home'     => $self->o('mafft_home'),

        'low_mem_capacity' => $self->o('low_mem_capacity'),
        'high_mem_capacity' => $self->o('high_mem_capacity'),
        'copy_db' => $self->o('copy_db'),
    };
}

sub resource_classes {
    my ($self) = @_;

    return {
        %{$self->SUPER::resource_classes},
        'high_memory' => { 'LSF' => '-C0 -M32000 -R"rusage[mem=32000]"' },
    		'four_cores' => { 'LSF' => '-n 4 -C0 -M32000 -R"rusage[mem=32000]"' },
    		'four_cores_high_memory' => { 'LSF' => '-n 4 -C0 -M32000 -R"rusage[mem=32000]"' },
    };
}

=head2 pipeline_analyses

    Description : Implements pipeline_analyses() interface method of Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf that defines the structure of the pipeline: analyses, jobs, rules, etc.
                  Here it defines two analyses:

                    * 'create_jobs'  reads commands line-by-line from inputfile
                      Each job of this analysis will dataflow (create jobs) via branch #2 into 'run_cmd' analysis.

                    * 'run_cmd'   actually runs the commands in parallel

=cut

sub pipeline_analyses 
{
    my ($self) = @_;
    return [

    {   -logic_name => 'wait_for_copy',
        -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
        -input_ids => [ {'inputfile'    => $self->o('pseudopipe_data'),} ],
        -flow_into  => { 
             '1->B' => ['create_pseudogene_db', WHEN('#copy_db#' => 'create_tables_in_compara_db'),],
             'B->1' => {'create_jobs_for_one_tree' => {}}, 
            },
    },

   ### Those job are in charge of processing the input files.
   ### This part should probably have a master/source/ref db in addition to the compara_db...
   {   -logic_name => 'create_pseudogene_db',
       -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DbCmd',
       -parameters => {
        'db_conn' => '#compara_db#',
        'input_query' => qq{CREATE TABLE IF NOT EXISTS pseudogenes_data (
            parent_id               VARCHAR(40) NOT NULL,
            pseudogene_id           VARCHAR(40),
            parent_transcript_id    VARCHAR(40),
            transcript_id           VARCHAR(40),
            tree_id                 INT(10) unsigned,
            score                   INT(10) unsigned,
            evalue                  FLOAT DEFAULT 1000,
            parent_species          VARCHAR(60) NOT NULL,
            parent_query            VARCHAR(60) NOT NULL,
            parent_type             enum("gene", "slice", "sequence", "protein", "transcript") NOT NULL,
            pseudogene_species      VARCHAR(60) NOT NULL,
            pseudogene_query        VARCHAR(60) NOT NULL,
            pseudogene_type         enum("gene", "slice", "sequence", "protein", "transcript") NOT NULL,
            status                  enum("OK", "PARENT", "ALIGNMENT", "REFERENCE", "NO GENE") NOT NULL,
            filepath                VARCHAR(255) NOT NULL,
            line                    INT(10),
            UNIQUE KEY              file_data (filepath, line),
            KEY                     parent_id (parent_id),
            KEY                     pseudogene_id (pseudogene_id),
            KEY                     root_id (tree_id)
        ) COLLATE=latin1_swedish_ci ENGINE=InnoDB;},
        },
        -flow_into => { 
            '1->A' => 'create_jobs_for_files',
            'A->1' => 'clear_data',
          },
      },

      {   -logic_name => 'create_jobs_for_files',
          -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
          -parameters => {
              'column_names' => ['path', 'header', 'target_species', 'target_type', 'target_col', 'ref_species', 'ref_type', 'ref_col' ],
              'delimiter' => "\t",	
                  },
          -flow_into => {
              '2' => ['split_files'],
            },
      },

      {   -logic_name => 'split_files',
          -module     => 'FilterInput::SplitFiles',
          -flow_into => {
              '2' => {'search_pseudogenes' => INPUT_PLUS() },
            },
      },

      {   -logic_name => 'search_pseudogenes',
          -module     => 'Bio::EnsEMBL::Compara::RunnableDB::Pseudogenes::FilterInput::SearchPseudogenesInDataBase',
          -parameters => {
              'registry_url' => $self->o('registry_url'),				
	              },
          -analysis_capacity => 150,
      },

      {   -logic_name => 'clear_data',
          -module     => 'Bio::EnsEMBL::Compara::RunnableDB::Pseudogenes::FilterInput::ClearData',
          -parameters => {
              'registry_url' => $self->o('registry_url'),				
	              },
      },

      {    -logic_name => 'create_tables_in_compara_db',
          -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DbCmd',
          -parameters => {
              'db_conn' => '#compara_db#',
              'input_file' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/sql/table.sql",
                 },
          -flow_into => { 1 => 'copy_tables_from_db_conn_factory' },
      },

      ## These jobs are responsible for copying an existing database (the latest in order to run the analysis
      {   -logic_name => 'copy_tables_from_db_conn_factory',
          -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
          -parameters => {
              'inputlist'    => [ 'ncbi_taxa_node', 'ncbi_taxa_name', 'method_link', 'species_set', 'species_set_header', 'method_link_species_set',     'method_link_species_set_tag', 'method_link_species_set_attr',  'gene_member', 'seq_member', 'sequence', 'other_member_sequence', 'exon_boundaries', 'gene_tree_root', 'gene_tree_root_tag', 'gene_tree_root_attr', 'gene_tree_node', 'gene_tree_node_tag', 'gene_tree_node_attr', 'species_tree_root', 'species_tree_node', 'species_tree_node_attr', 'species_tree_node_tag', 'gene_align', 'gene_align_member', 'dnafrag', 'genome_db', 'meta', 'gene_tree_object_store'],
              'column_names' => [ 'table' ],      },
          -flow_into  =>  {
                    '2->A' => 'copy_table_from_db_conn',
                    'A->1' => 'set_genome_db_locator_factory',
                          },
          -can_be_empty => 1,
    },

    {   -logic_name => 'copy_table_from_db_conn',
        -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
        -parameters => {
          'dest_db_conn'   => '#compara_db#',
          'mode'          => 'overwrite',
          'filter_cmd'    => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/"',
             },
      -analysis_capacity => 4,
      -can_be_empty => 1,
    },

    { -logic_name => 'set_genome_db_locator_factory',
      -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
      -flow_into => { 
          2 => 'update_genome_db_locator',
          1 => 'create_method_link',
              },
    },

    { # this sets up the locator field in the genome_db table
      -logic_name => 'update_genome_db_locator',
      -module     => 'Bio::EnsEMBL::Compara::Production::EPOanchors::UpdateGenomeDBLocator',
      -parameters => {
          'main_core_dbs' => $self->o('main_core_dbs'),
         },
    },

    {   -logic_name => 'create_method_link',
        -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
        -parameters => {
    'db_conn'   => '#compara_db#',
     'sql' => [
      'INSERT IGNORE method_link (type, class) VALUES ("ENSEMBL_PSEUDOGENES_ORTHOLOGUES", "Homology.homology");',
      'INSERT IGNORE method_link (type, class) VALUES ("ENSEMBL_PSEUDOGENES_PARALOGUES", "Homology.homology");',
      q{ALTER TABLE homology
  CHANGE COLUMN description description ENUM('ortholog_one2one', 'ortholog_one2many', 'ortholog_many2many', 'within_species_paralog', 'other_paralog', 'gene_split', 'between_species_paralog', 'alt_allele', 'homoeolog_one2one', 'homoeolog_one2many', 'homoeolog_many2many', 'pseudogene_ortholog', 'pseudogene_paralog') NULL DEFAULT NULL},
                  ],
                         },
        -flow_into => [ 'create_mlss' ],
        -can_be_empty => 1,
    },

    {   -logic_name => 'create_mlss',
        -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
        -parameters => {
          'program'    => '/homes/ggiroussens/src/ensembl-compara/scripts/pipeline/create_mlss.pl',
          'cmd' => "perl #program# --method_link_type ENSEMBL_PSEUDOGENES_PARALOGUES --force --sg --collection 'ensembl' --source 'ensembl' --compara #compara_db#; perl #program# --method_link_type ENSEMBL_PSEUDOGENES_ORTHOLOGUES --force --pw --collection 'ensembl' --source 'ensembl' --compara #compara_db#",
                             },
        -flow_into => {
            '1' => [ 'create_clustersets' ],    
                      },
        -can_be_empty => 1,
    },

    {   -logic_name => 'create_clustersets',
        -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CreateClustersets',
        -parameters => {
            additional_clustersets => ["copy", "raxml_update"],
            member_type => 'protein',
            mlss_id => 40115, 
                },  
        -can_be_empty => 1,
    },

  ## The jobs after this are run separatly on each tree and will add every pseuodgenes to the tree they work on.


    {     -logic_name => 'create_new_trees',
          -module => "Bio::EnsEMBL::Compara::RunnableDB::Pseudogenes::MakePseudogenesTree",
          -parameters => {
              mlss_id => '40115',
              member_type => 'protein',
                  }, 
          -flow_into => {2 => 'compute_new_alignment'},
          -analysis_capacity => 1,
          -can_be_empty => 1,
    },

    {   -logic_name => 'compute_new_alignment',
        -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Mafft',
        -parameters => 
        { 
          mafft_home => '/nfs/software/ensembl/latest/linuxbrew/',
          cdna => 1,
          db_conn => "#compara_db#",
        },
        -flow_into => {
            1 => 'nc_tree',
        },
        -can_be_empty => 1,
    },

      {   -logic_name => 'create_jobs_for_one_tree',
          -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
          -parameters => {
              'inputquery' => q{SELECT SUBSTRING(all_roots, 1, IF(LOCATE(',' , all_roots) > 0, LOCATE(',' , all_roots) - 1, LENGTH(all_roots))) AS root_id, GROUP_CONCAT(pseudogene_id) AS pseudogene_id
FROM (SELECT pseudogene_id, GROUP_CONCAT(tree_id ORDER BY evalue SEPARATOR ', ') AS all_roots, COUNT(*) FROM good_pseudogenes WHERE pseudogene_id IS NOT NULL AND tree_id IS NOT NULL GROUP BY pseudogene_id) AS T GROUP BY root_id}, 
              'column_names' => ['gene_tree_id', 'pseudogenes'],
              'db_conn' => '#compara_db#',
                  },
          -flow_into => {
              '2' => [WHEN '#copy_db#' => 'copy_trees', ELSE 'add_pseudogenes_nodes'],
              '1' => 'create_new_trees',
            },
      },

    {   -logic_name => 'copy_trees',
        -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CopyLocalTree',
        -parameters => {
            input_clusterset_id => 'default',
            output_clusterset_id => 'copy',
               },  
         -flow_into => {
              1 => [ 'add_pseudogenes_nodes' ],
                   },
         -analysis_capacity => 120,
         -can_be_empty => 1,
    },


    {   -logic_name => 'add_pseudogenes_nodes',
        -module => "Bio::EnsEMBL::Compara::RunnableDB::Pseudogenes::AddPseudogenesNodes",
        -parameters => {},
        -flow_into => { 1 => ['update_alignement'] },
    },

  {   -logic_name    => 'update_alignement',
      -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Mafft_update',
      -parameters    => 
        { 
          mafft_home => '/nfs/software/ensembl/latest/linuxbrew/',
          cdna => 1,
          db_conn => "#compara_db#",
          escape_branch => 2,
        },
      -flow_into => {
          1 => [ 'update_tree' ],   # will create a fan of jobs
          -1 => [ 'update_alignement_high_memory' ],
          2 => 'compute_new_alignment',
          },
      -analysis_capacity => 100,
   },

        {   -logic_name    => 'update_alignement_high_memory',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Mafft_update',
            -parameters    => 
        { 
          mafft_home => '/nfs/software/ensembl/latest/linuxbrew/',
          cdna => 1,
          db_conn => "#compara_db#",
        },
      -flow_into => {
          1 => [ 'update_tree_high_mem' ],   # will create a fan of jobs
          },
      -rc_name => 'high_memory',
      -analysis_capacity => 10,
        },


        {   -logic_name    => 'update_tree',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_update',
            -parameters    => 
                { 
                  raxml_number_of_cores => 4,
                  raxml_pthread_exe_avx => '/nfs/software/ensembl/latest/linuxbrew/bin/raxmlHPC-PTHREADS-AVX',
                  raxml_pthread_exe_sse3 => '/nfs/software/ensembl/latest/linuxbrew/bin/raxmlHPC-PTHREADS-SSE3',
                  cdna => 1,
                  remove_columns => 0,
                },
          -flow_into => {
            -1 => [ 'update_tree_high_mem' ],
            1 => [ 'add_pseudogene_tag_to_nodes' ],   # will create a fan of jobs
            2 => [ 'nc_tree'], ## When the tree has less than 4 members
                },
          -rc_name => 'four_cores',
          -analysis_capacity => 40,
        },

        {   -logic_name => 'nc_tree',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCGenomicTree',
            -parameters => {
                'cdna'                      => 1,
                'treebest_exe'              => $self->o('treebest_exe'),
                'output_clusterset_id'      => 'raxml_update',
                'method'                    => 'nj',
            },
            -flow_into => {
                1 => [ 'add_pseudogene_tag_to_nodes' ],
            },
        },


        {   -logic_name    => 'update_tree_high_mem',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML_update',
            -parameters    => 
        { 
          raxml_number_of_cores => 4,
          raxml_pthread_exe_avx => '/nfs/software/ensembl/latest/linuxbrew/bin/raxmlHPC-PTHREADS-AVX',
          raxml_pthread_exe_sse3 => '/nfs/software/ensembl/latest/linuxbrew/bin/raxmlHPC-PTHREADS-SSE3',
          cdna => 1,
          remove_columns => 0,
        },
      -rc_name => 'four_cores_high_memory',
          -flow_into => {
      1 => { 'add_pseudogene_tag_to_nodes' => INPUT_PLUS({"HM" => 1})}, 
          },
      -analysis_capacity => 10,
        },

        {   -logic_name    => 'add_pseudogene_tag_to_nodes',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::Pseudogenes::PseudogeneTag',
            -parameters    => {
            input_clusterset_id => 'raxml_update',
                },
        -flow_into => { 1 => [ WHEN '#HM#' => 'compute_paralogues_high_mem', ELSE  "compute_paralogues"],  },
        },

        {   -logic_name    => 'compute_paralogues',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthoTree',
            -parameters    => {
                input_clusterset_id => 'raxml_update',
                 },
            -flow_into => { -1 => [ 'compute_paralogues_high_mem' ],
                1 => [ 'hc_homologies' ],
             },
            -analysis_capacity => 100,
        },
        
        {   -logic_name    => 'compute_paralogues_high_mem',
        -module        => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthoTree',
        -parameters    => {
        input_clusterset_id => 'raxml_update',
    },
      -flow_into => { 1 => [ 'hc_homologies' ], },
      -rc_name => 'high_memory',i
      -analysis_capacity => 40,
  },

  {     -logic_name => 'hc_homologies',
        -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
        -parameters => 
        {
            mode => 'tree_homologies',
        },
     },
   ];
}

1;

