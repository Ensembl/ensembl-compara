=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::PipeConfig::Example::EBIImportAltAlleGroupsAsHomologies_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Example::EBIImportAltAlleGroupsAsHomologies_conf -password <your_password>

=head1 DESCRIPTION

    Alt-allele and gene-names/descriptions update ... at the EBI !

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Example::EBIImportAltAlleGroupsAsHomologies_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ImportAltAlleGroupsAsHomologies_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        # Production database (for the biotypes)
        'production_db_url'     => 'ensro@mysql-ens-sta-1:4519/ensembl_production',

        #Software dependencies
        'mafft_home'            => '/nfs/software/ensembl/RHEL7/linuxbrew/Cellar/mafft/7.305/',

    };
}


sub resource_classes {
    my ($self) = @_;
    my $reg_requirement = '--reg_conf '.$self->o('reg_conf');
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class

        '500Mb_job'    => { 'LSF' => ['-q production-rh7 -C0 -M500 -R"select[mem>500] rusage[mem=500]"', $reg_requirement], 'LOCAL' => ['', $reg_requirement] },
        'patch_import'  => { 'LSF' => ['-q production-rh7 -C0 -M250 -R"select[mem>250] rusage[mem=250]"', $reg_requirement], 'LOCAL' => ['', $reg_requirement] },
        'patch_import_himem'  => { 'LSF' => ['-q production-rh7 -C0 -M500 -R"select[mem>500] rusage[mem=500]"', $reg_requirement], 'LOCAL' => ['', $reg_requirement] },
        'default_w_reg' => { 'LSF' => ['', $reg_requirement], 'LOCAL' => ['', $reg_requirement] },
    };
}
1;
