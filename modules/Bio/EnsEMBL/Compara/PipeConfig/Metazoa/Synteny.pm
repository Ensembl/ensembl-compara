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

Bio::EnsEMBL::Compara::PipeConfig::Metazoa::Synteny_conf

=head1 DESCRIPTION

This is the EG Metazoa specific version of the general Bio::EnsEMBL::Compara::PipeConfig::Synteny_conf

=head1 SYNOPSIS

init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Metazoa::Synteny_conf \
  -host mysql-ens-compara-prod-X -port XXXX \
  -ptree_db/alignment_db <db_alias_or_url>

=head1 EXAMPLE

init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Metazoa::Synteny_conf  \
  -host mysql-ens-compara-prod-X -port XXX ... \
  -pipeline_name "synteny_${RELEASE_VERSION}" \
  -hive_force_init 1 \
  -reg_conf $REG_FILE \
  -division metazoa

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Metazoa::Synteny_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

use base ('Bio::EnsEMBL::Compara::PipeConfig::Synteny_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones
        'division'     => 'metazoa',
        
        'alignment_db'    => 'compara_curr',
        'curr_release_db' => 'compara_curr',
    };
}

1;
