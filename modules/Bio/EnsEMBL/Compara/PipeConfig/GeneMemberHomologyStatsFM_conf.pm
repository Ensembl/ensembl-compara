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

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::GeneMemberHomologyStatsFM_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::GeneMemberHomologyStatsFM_conf -host mysql-ens-compara-prod-X -port XXXX \
        -compara_db <curr_rel_compara_eg_db_url> -collection <collection_name>

=head1 DESCRIPTION

A single-analysis pipeline to populate the "families" column of the gene_member_hom_stats table.

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::GeneMemberHomologyStatsFM_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version v2.4;

use Bio::EnsEMBL::Compara::PipeConfig::Parts::GeneMemberHomologyStats;

use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');   # we don't need Compara tables in this particular case

sub default_options {
    my ($self) = @_;
    return {
        %{ $self->SUPER::default_options() },

        'compara_db' => 'compara_curr',
        'collection' => undef,
    };
}

sub pipeline_analyses {
    my ($self) = @_;

    my $pipeline_analyses = Bio::EnsEMBL::Compara::PipeConfig::Parts::GeneMemberHomologyStats::pipeline_analyses_fam_stats($self);
    $pipeline_analyses->[0]->{'-input_ids'} = [
        {
            'db_conn'         => $self->o('compara_db'),
        },
    ];

    return $pipeline_analyses;
}

1;

