package Bio::EnsEMBL::Compara::PipeConfing::FilterPseudogenesInput_conf;

use warnings;
use strict;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');

sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return 
    {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class
        'compara_db'     => $self->o('compara_db'),
    };
}

sub pipeline_analyses 
{


    my ($self) = @_;
    return [
      {
       -logic_name => 'create_pseudogene_db',
       -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DbCmd',
       -input_ids => [ {'inputfile'    => '/homes/ggiroussens/modules/FilterInput/FactoryInfo.txt',} ],   
       -parameters => {
        'db_conn' => '#compara_db#',
        'input_query' => qq{CREATE TABLE IF NOT EXISTS pseudogenes_data (
	    parent_id             VARCHAR(40) NOT NULL,
            pseudogene_id         VARCHAR(40),
            parent_transcript_id  VARCHAR(40),
            transcript_id         VARCHAR(40),
            tree_id               INT(10) unsigned,
            score                 INT(10) unsigned,
            evalue                FLOAT DEFAULT 1000,
            parent_species        VARCHAR(60) NOT NULL,
            parent_query          VARCHAR(60) NOT NULL,
            parent_type           enum("gene", "slice", "sequence", "protein", "transcript") NOT NULL,
            pseudogene_species    VARCHAR(60) NOT NULL,
            pseudogene_query      VARCHAR(60) NOT NULL,
            pseudogene_type       enum("gene", "slice", "sequence", "protein", "transcript") NOT NULL,
            status                enum("OK", "PARENT", "ALIGNMENT", "REFERENCE", "NO GENE") NOT NULL,
            filepath              VARCHAR(255) NOT NULL,
            line                  INT(10),
            UNIQUE KEY            file_data (filepath, line)
        ) COLLATE=latin1_swedish_ci ENGINE=InnoDB;},
        },
        -flow_into => { 1 => 'job_factory' },
      },

      {   -logic_name => 'job_factory',
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
          -module     => 'Bio::EnsEMBL::Compara::RunnableDB::Pseudogenes::FilterInput::SplitFiles',
          -flow_into => {
              '2' => {'search_pseudogenes' => INPUT_PLUS() },
            },
      },

      {   -logic_name => 'search_pseudogenes',
          -module     => 'Bio::EnsEMBL::Compara::RunnableDB::Pseudogenes::FilterInput::SearchPseudogenesInDataBase',
          -parameters => {
              'registry_url' => 'mysql://ensro@mysql-ensembl-mirror:4240/92',				
	    },
          -analysis_capacity => 150,
      },
    ];
}

1;
