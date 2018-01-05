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

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::GeneMemberHomologyStats_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::GeneMemberHomologyStats_conf
    seed_pipeline.pl -url ${EHIVE_URL} -logic_name find_collection_species_set_id -input_id '{"collection" => "collection_name", "db_conn" => "mysql://ensro\@comparaX/hom_db"}'

=head1 DESCRIPTION

    A simple pipeline to populate the gene_member_hom_stats table.
    This table can now hold statistics for different collections and once
    instance of the pipeline can be seeded multiple times in order to gather
    statistics for multiple collections.

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::GeneMemberHomologyStats_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;

use Bio::EnsEMBL::Compara::PipeConfig::Parts::GeneMemberHomologyStats;

use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');   # we don't need Compara tables in this particular case

sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},       # here we inherit anything from the base class

        'hive_use_param_stack'  => 1,           # switch on the new param_stack mechanism
    };
}


sub pipeline_analyses {
    my ($self) = @_;

    my $pipeline_analyses = Bio::EnsEMBL::Compara::PipeConfig::Parts::GeneMemberHomologyStats::pipeline_analyses_hom_stats($self);
    $pipeline_analyses->[0]->{'-input_ids'} = [
        {
            'db_conn'         => $self->o('compara_db'),
            'collection'      => 'default',
            'clusterset_id'   => 'default',
        },
        {
            'db_conn'         => $self->o('compara_db'),
            'collection'      => 'murinae',
            'clusterset_id'   => 'murinae',
        },
    ];

    return $pipeline_analyses;
}

1;

