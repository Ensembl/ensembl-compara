=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

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

Bio::EnsEMBL::Compara::PipeConfig::HighConfidenceOrthologs_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::HighConfidenceOrthologs_conf -host mysql-ens-compara-prod-X -port XXXX \
        -division $COMPARA_DIV -compara_db <db_alias_or_ulr>

=head1 DESCRIPTION

A simple pipeline to populate the high- and low- confidence levels on a Compara database.

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::HighConfidenceOrthologs_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version v2.4;

use Bio::EnsEMBL::Compara::PipeConfig::Parts::HighConfidenceOrthologs;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{ $self->SUPER::default_options() },               # inherit other stuff from the base class

        'collection' => 'default',

        'high_confidence_capacity'    => 500,          # how many mlss_ids can be processed in parallel
        'import_homologies_capacity'  => 50,           # how many homology mlss_ids can be imported in parallel

        # In this structure, the "thresholds" are for resp. the GOC score, the WGA coverage and %identity
        'threshold_levels' => [ ],
        # 'threshold_levels' => [
        #     {
        #         'taxa'          => [ 'all' ],
        #         'thresholds'    => [ undef, undef, 25 ],
        #     },
        # ],

        'homology_dumps_dir' => $self->o('homology_dumps_shared_basedir') . '/' . $self->o('collection')    . '/' . $self->o('ensembl_release'),
        'goc_files_dir'      => $self->o('homology_dumps_dir'),
        'wga_files_dir'      => $self->o('homology_dumps_dir'),
    };
}

sub default_pipeline_name {         # Instead of ortholog_qm_alignment
    my ($self) = @_;
    return $self->o('collection') . '_' . $self->o('member_type') . '_high_conf';
}

sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class

        'range_label'        => $self->o('member_type'),
        'pipeline_dir'       => $self->o('pipeline_dir'),
        'homology_dumps_dir' => $self->o('homology_dumps_dir'),
        'goc_files_dir'      => $self->o('goc_files_dir'),
        'wga_files_dir'      => $self->o('wga_files_dir'),
        'hashed_mlss_id'     => '#expr(dir_revhash(#mlss_id#))expr#',
        'goc_file'           => '#goc_files_dir#/#hashed_mlss_id#/#mlss_id#.#member_type#.goc.tsv',
        'wga_file'           => '#wga_files_dir#/#hashed_mlss_id#/#mlss_id#.#member_type#.wga.tsv',
        'high_conf_file'     => '#pipeline_dir#/#hashed_mlss_id#/#mlss_id#.#member_type#.high_conf.tsv',
    }
}

sub no_compara_schema {}    # Tell the base class not to create the Compara tables in the database

sub pipeline_analyses {
    my ($self) = @_;
    my $pipeline_analyses = Bio::EnsEMBL::Compara::PipeConfig::Parts::HighConfidenceOrthologs::pipeline_analyses_high_confidence($self);
    $pipeline_analyses->[0]->{'-input_ids'} = [
        {
            'compara_db'        => $self->o('compara_db'),
            'member_type'       => $self->o('member_type'),
            'threshold_levels'  => $self->o('threshold_levels'),
        },
    ];

    return $pipeline_analyses;
}

1;
