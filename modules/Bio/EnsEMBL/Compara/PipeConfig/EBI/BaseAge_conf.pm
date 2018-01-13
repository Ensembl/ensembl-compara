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

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::EBI::BaseAge_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::BaseAge_conf -password <your_password>

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
            'host' => 'mysql-ens-compara-prod-1',
            'port' => 4485,

            'ref_species' => 'homo_sapiens',
            #'pipeline_name' => $self->o('ref_species').'_base_age_'.$self->o('rel_with_suffix'), # name used by the beekeeper to prefix job names on the farm

            #Location url of database to get EPO GenomicAlignTree objects from
#            'compara_url' => 'mysql://anonymous@mysql-ensembl-mirror:4240/ensembl_compara_' . $self->o('ensembl_release'),
            'compara_url' => 'mysql://ensro@mysql-ens-compara-prod-1:4485/muffato_mammals_epo_91',

            # The name of the alignment
            'species_set_name'  => 'mammals',

            # There is a different colour gradient for this clade
            'clade_taxon_id' => 9443,   # this is the taxon_id of Primates

            #Location url of database to get snps from
            #'variation_url' => 'mysql://anonymous@mysql-ensembl-mirror:4240/' . $self->o('ensembl_release'),
            'variation_url' => 'mysql://ensro@mysql-ensembl-sta-1:4519/homo_sapiens_variation_91_38?group=variation',

            # executable locations:
            'big_bed_exe'   => $self->check_exe_in_cellar('kent/v335_1/bin/bedToBigBed'),

            #Locations to write output files
            'bed_dir'        => sprintf('/hps/nobackup/production/ensembl/%s/%s', $ENV{USER}, $self->o('pipeline_name')),

            #Number of workers to run base_age analysis
            'base_age_capacity'        => 100,

          };
}

sub resource_classes {
    my ($self) = @_;

    my $rc = $self->SUPER::resource_classes();
    return {
         %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
         '100Mb' => { 'LSF' => '-C0 -M100 -R"select[mem>100] rusage[mem=100]"' },
	 '1Gb' =>    { 'LSF' => '-C0 -M1000 -R"select[mem>1000] rusage[mem=1000]"' },
	 '1.8Gb' => { 'LSF' => '-C0 -M1800 -R"select[mem>1800] rusage[mem=1800]"' },
         '3.6Gb' =>  { 'LSF' => '-C0 -M3600 -R"select[mem>3600] rusage[mem=3600]"' },
    };
}

1;
