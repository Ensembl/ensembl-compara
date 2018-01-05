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


=pod 

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::GeneTreeObjectStore_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::GeneTreeObjectStore_conf -gene_tree_db mysql://...

=head1 DESCRIPTION  

    A simple pipeline to populate all the gene-tree related JSONs

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::GeneTreeObjectStore_conf;

use strict;
use warnings;

#use Bio::EnsEMBL::Hive::Version 2.4;

use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');   # we don't need Compara tables in this particular case


sub default_options {
    my ($self) = @_;
    return {
        %{ $self->SUPER::default_options() },               # inherit other stuff from the base class

        #'production_registry' => "--reg_conf ".$self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/production_reg_conf.pl",
        #'gene_tree_db'        => 'compara_curr',

        'capacity'    => 50,                                                        # how many trees can be dumped in parallel
        'batch_size'  => 20,                                                        # how may trees' dumping jobs can be batched together

    };
}

sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class

         #'default'      => { 'LSF' => [ '', $self->o('production_registry') ], 'LOCAL' => [ '', $self->o('production_registry') ]  },
         #'1Gb_job'      => { 'LSF' => [ '-C0 -M1000  -R"select[mem>1000]  rusage[mem=1000]"', $self->o('production_registry') ] },
         '1Gb_job'      => { 'LSF' => '-C0 -M1000  -R"select[mem>1000]  rusage[mem=1000]"' },
    };
}

sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},

        'gene_tree_db'        => $self->o('gene_tree_db'),
    };
}


sub pipeline_analyses {
    my ($self) = @_;
    return [

        {   -logic_name => 'tree_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -input_ids  => [ {} ],
            -parameters => {
                'db_conn'       => '#gene_tree_db#',
                'inputquery'    => 'SELECT root_id AS gene_tree_id FROM gene_tree_root WHERE tree_type = "tree" AND clusterset_id = "default"',
            },
            -flow_into  => {
                2   => [ 'exon_boundaries', 'cafe' ],
            },
        },

        {   -logic_name    => 'exon_boundaries',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectStore::GeneTreeAlnExonBoundaries',
            -parameters    => {
                'compara_db'    => '#gene_tree_db#',
            },
            -hive_capacity => $self->o('capacity'),
            -batch_size    => $self->o('batch_size'),
            -rc_name       => '1Gb_job',
        },

        {   -logic_name    => 'cafe',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectStore::GeneTreeCAFE',
            -parameters    => {
                'compara_db'    => '#gene_tree_db#',
            },
            -hive_capacity => $self->o('capacity'),
            -batch_size    => $self->o('batch_size'),
            -rc_name       => '1Gb_job',
        },
    ];
}

1;

