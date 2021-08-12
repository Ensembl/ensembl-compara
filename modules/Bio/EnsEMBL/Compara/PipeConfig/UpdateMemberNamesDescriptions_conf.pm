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

Bio::EnsEMBL::Compara::PipeConfig::UpdateMemberNamesDescriptions_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::UpdateMemberNamesDescriptions_conf -host mysql-ens-compara-prod-X -port XXXX \
        -division $COMPARA_DIV

=head1 DESCRIPTION  

The PipeConfig file for the pipeline that imports alternative alleles as homologies.

=cut


package Bio::EnsEMBL::Compara::PipeConfig::UpdateMemberNamesDescriptions_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::PipeConfig::Parts::UpdateMemberNamesDescriptions;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        'pipeline_name'   => 'member_description_update_'.$self->o('rel_with_suffix'),   # also used to differentiate submitted processes

        #Pipeline capacities:
        'update_capacity'                           => '5',
        #Outgroup species to exclude from GenomeDBFactory
        'exclude_species'  => [],

    };
}

sub no_compara_schema {}    # Tell the base class not to create the Compara tables in the database

sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},       # here we inherit anything from the base class
        'hive_use_param_stack'  => 1,           # switch on the new param_stack mechanism
    }
}


sub pipeline_analyses {
    my ($self) = @_;

    my $pipeline_analyses = Bio::EnsEMBL::Compara::PipeConfig::Parts::UpdateMemberNamesDescriptions::pipeline_analyses_member_names_descriptions($self);
    $pipeline_analyses->[0]->{'-input_ids'} = [ {
        'compara_db'    => $self->o('compara_db'),
    } ];
    return $pipeline_analyses;
}

1;

