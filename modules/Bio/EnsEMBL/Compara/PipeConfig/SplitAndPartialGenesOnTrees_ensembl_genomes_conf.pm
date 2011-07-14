
=pod 

=head1 NAME

  Bio::EnsEMBL::Compara::PipeConfig::SplitAndPartialGenesOnTrees_ensembl_genomes

=head1 SYNOPSIS

#1. update ensembl-hive, ensembl and ensembl-compara CVS repositories before each new release
#2. you may need to update 'schema_version' in meta table to the current release number in ensembl-hive/sql/tables.sql

#3. make sure that all default_options are set correctly

#4. Run init_pipeline.pl script:
init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::SplitAndPartialGenesOnTrees_ensembl_genomes -password <your_password> -kingdom <kingdom_name>

#5. Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output


=head1 DESCRIPTION  

    The PipeConfig file for SplitGenesOnTrees pipeline that should automate most of the pre-execution tasks.

=head1 CONTACT

  Please contact maurel@ebi.ac.uk mailing list with questions/suggestions.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::SplitAndPartialGenesOnTrees_ensembl_genomes_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        'ensembl_cvs_root_dir'  => $ENV{'ENSEMBL_CVS_ROOT_DIR'}, # this variable should be defined in your shell configs
        'email'                 => $ENV{'USER'}.'@ebi.ac.uk',    # NB: your EBI address may differ from the Sanger one!

        'pipeline_name'         => 'SG',   # name the pipeline to differentiate the submitted processes
        'kingdom'               => $self->o('kingdom'), # ensembl genomes kingdom : bacteria, fungi, metazoa, pan_homology, plants, protists.
    # connection parameters to various databases:

        'pipeline_db' => {                      # the production database itself (will be created)
            -host   => 'compara3',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),                    
            -dbname => $ENV{'USER'}.'_split_and_partial_genes_e_genomes',
        },

#      'source_db' => {                      # the source database (read only mode)
#          -host   => 'mysql.ebi.ac.uk',
#          -port   => 4157,
#          -user   => 'anonymous',
#          -pass   => '',
#          -dbname => 'ensembl_compara_'.$self->o('kingdom').'_9_62',
#        },

      'source_db' => {                      # the source database (read only mode)
        -host   => 'farm2-head1',
        -port   => 4275,
        -user   => 'ensro',
        -pass   => '', 
        -dbname => 'ensembl_compara_'.$self->o('kingdom').'_10_63',
      },




#      'source_db' => {                      # the source database (read only mode)
#        -host   => 'farm2-head1',
#        -port   => 4275,
#        -user   => 'ensro',
#        -pass   => '', 
#        -dbname => 'ensembl_compara_'.$self->o('kingdom').'_10_63',
#      },  

    };
}


sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class

        'email'             => $self->o('email'),           # for (future) automatic notifications (may be unsupported by your Meadows)
    };
}


sub pipeline_create_commands {

    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation

            # additional table needed for keeping the output of 'find_split_genes_on_tree' analysis

        'mysql '.$self->dbconn_2_mysql('pipeline_db', 1)." -e 'CREATE TABLE split_genes_e_genomes (id_spg MEDIUMINT NOT NULL AUTO_INCREMENT, tagged_as_split_gene_by_gene_tree_pipeline int(1) NOT NULL, overlap int(10) NOT NULL, score_inter_union float(4,2) NOT NULL, first_aa_prot char(1), unknown_aa_prot1 int(10) NOT NULL, unknown_aa_prot2 int(10) NOT NULL, rounded_duplication_confidence_score float(4,3) NOT NULL, intersection_duplication_score int(10) NOT NULL, union_duplication_confidence_score int(10) NOT NULL, merged_by_gene_tree_pipeline char(50) NOT NULL, chr_name char(40) NOT NULL, chr_strand int(5) NOT NULL, first_part_split_gene_stable_id varchar(128) NOT NULL, second_part_split_gene_stable_id varchar(128) NOT NULL, protein1_label char(40) NOT NULL, protein1_length_in_aa int(20) NOT NULL, alignment_length int(20) NOT NULL, species_name char(40) NOT NULL, kingdom char(40) NOT NULL, PRIMARY KEY (id_spg)) ENGINE=InnoDB'",
 
'mysql '.$self->dbconn_2_mysql('pipeline_db', 1)." -e 'CREATE TABLE partial_genes_e_genomes (id_spg MEDIUMINT NOT NULL AUTO_INCREMENT, gene_stable_id varchar(128) NOT NULL, protein_tree_stable_id varchar(128) NOT NULL, coverage_on_core_regions_score float(6,3) NOT NULL, alignment_overlap_score float(6,3) NOT NULL, species_name char(40) NOT NULL, kingdom char(40) NOT NULL, PRIMARY KEY (id_spg)) ENGINE=InnoDB'",

'mysql '.$self->dbconn_2_mysql('pipeline_db', 1)." -e 'CREATE TABLE cocr_length_e_genomes (protein_tree_stable_id char(30) NOT NULL, coverage_on_core_regions_length int(30) NOT NULL, number_of_gene int(30) NOT NULL, kingdom char(40) NOT NULL,  PRIMARY KEY (protein_tree_stable_id)) ENGINE=InnoDB'",

'mysql '.$self->dbconn_2_mysql('pipeline_db', 1)." -e 'CREATE TABLE single_genes_e_genomes (id_spg MEDIUMINT NOT NULL AUTO_INCREMENT, gene_stable_id char(30) NOT NULL, protein_tree_stable_id char(30) NOT NULL, species_name char(40) NOT NULL,kingdom char(40) NOT NULL, PRIMARY KEY (id_spg)) ENGINE=InnoDB'",

 ];

}

sub pipeline_analyses {
    my ($self) = @_;
    return [
# ---------------------------------------------[getting all tree node ids]---------------------------------------------
        {   -logic_name => 'tree_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectFactory',
            -parameters => {
                'adaptor_name' => 'ProteinTreeAdaptor',
                'adaptor_method' => 'fetch_all',
                'column_names2getters'  => { 'protein_tree_id' => 'node_id' },
                'input_id' => { 'protein_tree_id' => '#protein_tree_id#', 'kingdom' => '#kingdom#', 'compara_db' => '#compara_db#', },
                'fan_branch_code' => 2,
            },
            -input_ids => [
              { 'compara_db' => $self->o('source_db'),'kingdom' => $self->o('kingdom'), },
            ],
            -flow_into => {
              2 => ['find_split_genes_on_tree', 'find_partial_genes_on_tree', 'coverage_on_core_region_length','find_single_genes_on_tree'],
            },
        },

# ---------------------------------------------[Split Genes analysis]---------------------------------------------

    { -logic_name => 'find_split_genes_on_tree',
      -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FindSplitGenesOnTree',
      -parameters => { 
      },
      -batch_size => 50,
      -hive_capacity => 200,
      -flow_into => {
        3 => [ 'mysql:////split_genes_e_genomes' ],
      },
   },

# ---------------------------------------------[Partial Genes analysis]---------------------------------------------

    {   -logic_name => 'find_partial_genes_on_tree',
      -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FindPartialGenesOnTree',
      -parameters => {
        'threshold' => 90,
      },
      -batch_size => 50,
      -hive_capacity => 200,
      -max_retry_count => 20,
      -flow_into => {
        3 => [ 'mysql:////partial_genes_e_genomes' ],
      },
    },
# ---------------------------------------------[Coverage on core region length analysis]---------------------------------------------

    {   -logic_name => 'coverage_on_core_region_length',
          -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FindCoreRegionLength',
          -parameters => {
            'threshold' => 90,
          },
          -batch_size => 50,
          -hive_capacity => 200,
          -max_retry_count => 10,
          -flow_into => {
            3 => [ 'mysql:////cocr_length_e_genomes' ],
          },
        },

# ---------------------------------------------[Single Genes in species analysis]---------------------------------------------

    {   -logic_name => 'find_single_genes_on_tree',
      -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FindSingleGenesOnTree',
      -parameters => {
      },
      -batch_size => 50,
      -hive_capacity => 200,
      -max_retry_count => 10,
      -flow_into => {
        3 => [ 'mysql:////single_genes_e_genomes' ],
      },
    },

  ];
}

1;

