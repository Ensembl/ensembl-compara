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

Bio::EnsEMBL::Compara::PipeConfig::EBI::Plants::Synteny_conf

=head1 DESCRIPTION

This is the EG Plants specific version of the general Bio::EnsEMBL::Compara::PipeConfig::Synteny_conf

Example: init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::Plants::Synteny_conf  -pipeline_name <> -ptree_db/alignment_db <> -registry <>

#init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::Plants::Synteny_conf -pipeline_name synteny_plants_42_95 -alignment_db mysql://ensro@mysql-ens-compara-prod-5:4615/ensembl_compara_plants_42_95 -compara_curr mysql://ensro@mysql-ens-compara-prod-5:4615/ensembl_compara_plants_42_95 -host mysql-ens-compara-prod-5 -port 4615

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::Plants::Synteny_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

use base ('Bio::EnsEMBL::Compara::PipeConfig::EBI::Synteny_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones
        'division'     => 'plants',
        'alignment_db' => 'compara_curr',
    };
}

1;
