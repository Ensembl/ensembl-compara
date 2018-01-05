=pod
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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara:Pipeconfig::GeneSetQC_conf;

=head1 DESCRIPTION
	Automate quality assessment of gene set quality 

    -species_threshold : minimum number of species... for all of ensembl species we have decided on a minimum species threshold of 15
    -coverage_threshold : minimum avg percentage coverage.

Example run
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::GeneSetQC_conf -pipeline_name <GeneSetQC_trial> -host <host_server> -species_threshold <15> -coverage_threshold <50> -compara_db <>

=cut

package Bio::EnsEMBL::Compara::PipeConfig::GeneSetQC_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');
use Bio::EnsEMBL::Compara::PipeConfig::Parts::GeneSetQC;

sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},       # here we inherit anything from the base class

        'hive_use_param_stack'  => 1,           # switch on the new param_stack mechanism
    };
}


sub default_options {
    my $self = shift;
    return {
            %{ $self->SUPER::default_options() },
        'mlss_id'     => '' , #40101',
        'compara_db' => '', # 'mysql://ensro@compara2/wa2_protein_trees_snapshot_84'
        'genesetQC_capacity' => 200,
#        'compara_db' => 'mysql://ensro@compara4/OrthologQM_test_db'
    };
}

sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class
        'mlss_id' => $self->o('mlss_id'),
    #    'compara_db' => $self->o('compara_db'),
        'species_threshold' => $self->o('species_threshold'),
        'coverage_threshold' => $self->o('coverage_threshold'),
        'genesetQC_capacity' => $self->o('genesetQC_capacity'),
    };
}

sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
        'default'      => {'LSF' => '-C0 -M100   -R"select[mem>100]   rusage[mem=100]"' },
        '2Gb_job'      => {'LSF' => '-C0 -M2000  -R"select[mem>2000]  rusage[mem=2000]"' },
        '20Gb_job'      => {'LSF' => '-C0 -M20000  -R"select[mem>20000]  rusage[mem=20000]"' },
    };
}

sub pipeline_analyses {
    my ($self) = @_;
    return  [
# ---------------------------------------------[copy tables from compara_db]-----------------------------------------------------------------
        {   -logic_name => 'copy_tables_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputlist'    => [ 'genome_db', 'species_tree_node', 'species_tree_root', 'species_tree_node_tag', 'split_genes',
                                    'method_link_species_set', 'method_link_species_set_tag', 'species_set', 'ncbi_taxa_node', 'ncbi_taxa_name', 'seq_member', 'gene_member' ],
                'column_names' => [ 'table' ],
            },
            -input_ids  => [ { } ],
            -flow_into => {
                '2->A'  =>  ['copy_table'],
                'A->1'  =>  [ 'get_species_set' ],
            },
            -rc_name => 'urgent',
        },

        {   -logic_name    => 'copy_table',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'src_db_conn'   => $self->o('compara_db'),
                'mode'          => 'overwrite',
            },
        },

        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::GeneSetQC::pipeline_analyses_GeneSetQC($self)  },

    ];
}


1;
