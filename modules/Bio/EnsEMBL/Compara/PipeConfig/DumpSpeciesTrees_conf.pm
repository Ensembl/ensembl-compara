=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::DumpSpeciesTrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::DumpSpeciesTrees_conf -compara_url <url_of_the_compara_db>

=head1 DESCRIPTION  

Dumps all the species-trees from the database

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::DumpSpeciesTrees_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpSpeciesTrees;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        #'compara_db' => 'mysql://ensro@compara4:3306/mp14_epo_17mammals_80',

        #Connection parameters for production database (the rest is defined in the base class)
        'host'              => 'mysql-ens-compara-prod-1.ebi.ac.uk',
        'port'              => 4485,

        'division'          => 'vertebrates',

        #Locations to write output files
        'dump_dir'          => $self->o('pipeline_dir'),
    };
}

sub no_compara_schema {}    # Tell the base class not to create the Compara tables in the database

sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        'dump_dir'      => $self->o('dump_dir'),
        'compara_db'    => $self->o('compara_db'),
        'reg_conf'      => $self->o('reg_conf'),
        'dump_species_tree_exe' => $self->o('dump_species_tree_exe'),
    };
}

sub pipeline_analyses {
    my ($self) = @_;

    my $pipeline_analyses = Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpSpeciesTrees::pipeline_analyses_dump_species_trees($self);
    $pipeline_analyses->[0]->{'-input_ids'} = [{}];

    return $pipeline_analyses;
}

1;
