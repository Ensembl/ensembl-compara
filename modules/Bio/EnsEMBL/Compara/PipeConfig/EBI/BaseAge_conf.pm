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

Bio::EnsEMBL::Compara::PipeConfig::EBI::BaseAge_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::BaseAge_conf -password <your_password>

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::BaseAge_conf $(mysql-ens-compara-prod-2-ensadmin details hive) \
                     -compara_url $(mysql-ens-compara-prod-4 details url mateus_mammals_epo_94) \

=head1 DESCRIPTION

    Calculate the age of a base ... at the EBI !

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::BaseAge_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;

use base ('Bio::EnsEMBL::Compara::PipeConfig::BaseAge_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

            # Connection parameters for production database (the rest is defined in the base class)
            'host' => 'mysql-ens-compara-prod-2',
            'port' => 4522,

            'ref_species' => 'homo_sapiens',
            #'pipeline_name' => $self->o('ref_species').'_base_age_'.$self->o('rel_with_suffix'), # name used by the beekeeper to prefix job names on the farm

            'division' => 'ensembl',
            'reg_conf' => $self->o('ensembl_cvs_root_dir').'/ensembl-compara-release/scripts/pipeline/production_reg_'.$self->o('division').'_conf.pl',
            
            #Location url/alias of database to get EPO GenomicAlignTree objects from
            'compara_db' => 'compara_curr',

            # The name of the alignment
            'species_set_name'  => 'mammals',

            # There is a different colour gradient for this clade
            'clade_taxon_id' => 9443,   # this is the taxon_id of Primates

            #Location url of database to get snps from
            #'variation_url' => 'mysql://anonymous@mysql-ensembl-mirror:4240/' . $self->o('ensembl_release'),
            'variation_url' => 'mysql://ensro@mysql-ensembl-sta-1:4519/homo_sapiens_variation_'.$self->o('ensembl_release').'_38?group=variation',

            # executable locations:
            'big_bed_exe'   => $self->check_exe_in_cellar('kent/v335_1/bin/bedToBigBed'),

            #Locations to write output files
            'bed_dir'        => sprintf('/hps/nobackup2/production/ensembl/%s/%s', $ENV{USER}, $self->o('pipeline_name')),

            #Number of workers to run base_age analysis
            'base_age_capacity'        => 100,

          };
}

sub resource_classes {
    my ($self) = @_;
    my $reg_requirement = '--reg_conf '.$self->o('reg_conf');

    my $rc = $self->SUPER::resource_classes();
    return {
         %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
         'default' => { 'LSF' => ['', $reg_requirement] },
         '100Mb' => { 'LSF' => ['-C0 -M100 -R"select[mem>100] rusage[mem=100]"', $reg_requirement] },
	 '1Gb' =>    { 'LSF' => ['-C0 -M1000 -R"select[mem>1000] rusage[mem=1000]"', $reg_requirement] },
         '2Gb_job' => {'LSF' => ['-C0 -M2000  -R"select[mem>2000]  rusage[mem=2000]"', $reg_requirement] },
         '4Gb_job' => {'LSF' => ['-C0 -M4000  -R"select[mem>4000]  rusage[mem=4000]"', $reg_requirement] },
    };
}

1;
