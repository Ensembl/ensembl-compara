=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::ncRNAtrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::ncRNAtrees_conf -password <your_password> -mlss_id <your_mlss_id>

=head1 DESCRIPTION  

This is the Ensembl PipeConfig for the ncRNAtree pipeline.
An example of use can be found in the Example folder.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::PatchMouseStrains_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;

use Bio::EnsEMBL::Compara::PipeConfig::GeneTreeHealthChecks_conf;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;   # For WHEN and INPUT_PLUS
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

            # Copy from master db
            'tables_from_master'    => [ 'ncbi_taxa_node', 'ncbi_taxa_name' ],

            #'gene_tree%', 'homology%', 'gene_align%'

            # ambiguity codes
            'allow_ambiguity_codes'    => 0,

            # Analyses usually don't fail
            'hive_default_max_retry_count'  => 1,

            'copy_capacity'                 => 4,

            # Params for healthchecks;
            'hc_priority'                     => 10,
            'hc_capacity'                     => 40,
            'hc_batch_size'                   => 10,



            'reg1' => {
                       -host   => 'mysql-ens-sta-1',
                       -port   => '4519',
                       -user   => 'ensro',
                      },

            'master_db' => {
                            -host   => 'mysql-ens-compara-prod-1.ebi.ac.uk',
                            -port   => 4485,
                            -user   => 'ensro',
                            -pass   => '',
                            -dbname => 'ensembl_compara_master',
                           },




           };
}



sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class

        'mlss_id'       => $self->o('mlss_id'),
        'master_db'     => $self->o('master_db'),
        'member_db'     => $self->o('member_db'),
        'prev_rel_db'   => $self->o('prev_rel_db'),
    }
}


sub resource_classes {
    my ($self) = @_;
    return {
        %{ $self->SUPER::resource_classes() },
        '250Mb_job'               => { 'LSF' => '-C0 -M250   -R"select[mem>250]   rusage[mem=250]"' },
        '500Mb_job'               => { 'LSF' => '-C0 -M500   -R"select[mem>500]   rusage[mem=500]"' },
        '1Gb_job'                 => { 'LSF' => '-C0 -M1000  -R"select[mem>1000]  rusage[mem=1000]"' },
        '2Gb_job'                 => { 'LSF' => '-C0 -M2000  -R"select[mem>2000]  rusage[mem=2000]"' },
        '4Gb_job'                 => { 'LSF' => '-C0 -M4000  -R"select[mem>4000]  rusage[mem=4000]"' },
        '8Gb_job'                 => { 'LSF' => '-C0 -M8000  -R"select[mem>8000]  rusage[mem=8000]"' },
        '16Gb_job'                 => { 'LSF' => '-C0 -M16000  -R"select[mem>16000]  rusage[mem=16000]"' },
        '32Gb_job'                 => { 'LSF' => '-C0 -M32000  -R"select[mem>32000]  rusage[mem=32000]"' },
    };
}

sub pipeline_analyses {
    my ($self) = @_;

    my %hc_params = (
        -analysis_capacity => $self->o('hc_capacity'),
        -priority          => $self->o('hc_priority'),
        -batch_size        => $self->o('hc_batch_size'),
    );

    return [

# ------------------------------------------------------[copy tables from master]-----------------------------------------------------

        {   -logic_name => 'copy_tables_from_master_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputlist'    => [ 'ncbi_taxa_node', 'ncbi_taxa_name', 'method_link' ],
                'column_names' => [ 'table' ],
            },
            -input_ids  => [ {} ],
            -flow_into  => {
                '2->A' => [ 'copy_table_from_master'  ],
                'A->1' => [ 'load_genomedb_factory' ],
            },
        },

        {   -logic_name => 'copy_table_from_master',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'   => '#master_db#',
                'mode'          => 'overwrite',
                'filter_cmd'    => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/"',
            },
        },

# ---------------------------------------------[load GenomeDB entries from master+cores]---------------------------------------------

        {   -logic_name => 'load_genomedb_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'compara_db'        => '#master_db#',   # that's where genome_db_ids come from
                'mlss_id'           => $self->o('mlss_id'),
                'extra_parameters'  => [ 'locator' ],
            },
            -flow_into => {
                '2->A' => { 'load_genomedb' => { 'master_dbID' => '#genome_db_id#', 'locator' => '#locator#' }, }, # fan
                'A->1' => [ 'create_mlss_ss' ],
            },
        },

        {   -logic_name => 'load_genomedb',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB',
            -parameters => {
                'registry_dbs'   => [ $self->o('reg1')],    # FIXME
            },
            -analysis_capacity => $self->o('copy_capacity'),
        },

        {   -logic_name => 'create_mlss_ss',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PrepareSpeciesSetsMLSS',
            -parameters => {
                'whole_method_links'        => [ 'NC_TREES' ],
                'singleton_method_links'    => [ 'ENSEMBL_PARALOGUES', 'ENSEMBL_HOMOEOLOGUES' ],
                'pairwise_method_links'     => [ 'ENSEMBL_ORTHOLOGUES' ],
            },
            -flow_into  => {
                1 => [ 'load_members_factory' ],
            },
        },

        {   -logic_name => 'load_members_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -flow_into  => {
                '2->A' => 'genome_member_copy',
                'A->1' => [ 'copy_gene_tree_tables' ],
            },
        },

        {   -logic_name        => 'genome_member_copy',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CopyCanonRefMembersByGenomeDB',
            -parameters        => {
                'reuse_db'              => '#member_db#',
                'biotype_filter'        => 'biotype_group LIKE "%noncoding"',
            },
            -analysis_capacity => $self->o('copy_capacity'),
            -rc_name           => '250Mb_job',
            #-flow_into          => [ 'map_member_ids' ],
        },

        {   -logic_name => 'copy_gene_tree_tables',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::TableFactory',
            -flow_into  => {
                '2->A' => 'copy_table_from_prev_rel_db',
                'A->1' => [ 'pipeline_entry' ],
            },
        },

        {   -logic_name    => 'copy_table_from_prev_rel_db',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'src_db_conn'   => '#prev_rel_db#',
                'mode'          => 'overwrite',
                'filter_cmd'    => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/"',
            },
            -analysis_capacity => $self->o('copy_capacity'),
        },

        #{   -logic_name => 'map_members_factory',
            #-module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            #-flow_into  => {
                #'2->A' => 'map_member_ids',
                #'A->1' => [ 'pipeline_entry' ],
            #},
        #},

        @{ Bio::EnsEMBL::Compara::PipeConfig::GeneTreeHealthChecks_conf::pipeline_analyses($self) },
    ];
}

1;

