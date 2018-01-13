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

Bio::EnsEMBL::Compara::PipeConfig::ImportAltAlleGroupsAsHomologies_conf

=head1 DESCRIPTION  

The PipeConfig file for the pipeline that imports alternative alleles as homologies.

=cut


package Bio::EnsEMBL::Compara::PipeConfig::ImportAltAlleGroupsAsHomologies_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::PipeConfig::Parts::ImportAltAlleGroupsAsHomologies;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        'host'            => 'mysql-ens-compara-prod-1',    # where the pipeline database will be created
        'port'            => 4485,

        'pipeline_name'   => 'alt_allele_import_'.$self->o('rel_with_suffix'),   # also used to differentiate submitted processes

        # Only needed if the member_db doesn't have genome_db.locator
        'reg_conf'        => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/production_reg_conf.pl",

        # Source of MLSSs
        'master_db'       => 'mysql://ensro@mysql-ens-compara-prod-1.ebi.ac.uk:4485/ensembl_compara_master',
        # Source of GenomeDBs and members
        'member_db'       => 'mysql://ensro@mysql-ens-compara-prod-2.ebi.ac.uk:4522/mateus_load_members_91',

        #Pipeline capacities:
        'import_altalleles_as_homologies_capacity'  => '300',

        #Software dependencies
        'mafft_home'            => $self->check_dir_in_cellar('mafft/7.305'),

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

        'mafft_home'    => $self->o('mafft_home'),
        'master_db'     => $self->o('master_db'),
    }
}

sub resource_classes {
    my ($self) = @_;
    my $reg_requirement = '--reg_conf '.$self->o('reg_conf');
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class

        'patch_import'  => { 'LSF' => ['-C0 -M250 -R"select[mem>250] rusage[mem=250]"', $reg_requirement], 'LOCAL' => ['', $reg_requirement] },
        'patch_import_himem'  => { 'LSF' => ['-C0 -M500 -R"select[mem>500] rusage[mem=500]"', $reg_requirement], 'LOCAL' => ['', $reg_requirement] },
        'default_w_reg' => { 'LSF' => ['', $reg_requirement], 'LOCAL' => ['', $reg_requirement] },
    };
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


