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

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::ImportAltAlleGroupsAsHomologies_conf

=head1 DESCRIPTION  

The PipeConfig file for the pipeline that imports alternative alleles as homologies.

=cut


package Bio::EnsEMBL::Compara::PipeConfig::ImportAltAlleGroupsAsHomologies_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::PipeConfig::Parts::ImportAltAlleGroupsAsHomologies;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub default_pipeline_name {         # Instead of import_alt_allele_groups_as_homologies
    return 'alt_allele_import';
}

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        # Only needed if the member_db doesn't have genome_db.locator
        'division' => 'vertebrates',

        'master_db'       => 'compara_master',  # Source of MLSSs
        'member_db'       => 'compara_members', # Source of GenomeDBs and members

        #Pipeline capacities:
        'import_altalleles_as_homologies_capacity'  => '300',
    };
}

sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},       # here we inherit anything from the base class
        'hive_use_param_stack'  => 1,           # switch on the new param_stack mechanism
    }
}


sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class

        'mafft_exe'     => $self->o('mafft_exe'),
        'master_db'     => $self->o('master_db'),
    }
}


sub pipeline_analyses {
    my ($self) = @_;

    my $pipeline_analyses = Bio::EnsEMBL::Compara::PipeConfig::Parts::ImportAltAlleGroupsAsHomologies::pipeline_analyses_alt_alleles($self);

    $pipeline_analyses->[0]->{'-input_ids'} = [ {
            'member_db'     => $self->o('member_db'),
        } ];

    return $pipeline_analyses;
}

1;


