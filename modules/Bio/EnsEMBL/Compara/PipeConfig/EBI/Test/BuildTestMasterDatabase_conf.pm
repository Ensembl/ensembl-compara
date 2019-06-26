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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::EBI::Test::BuildTestMasterDatabase_conf

=head1 DESCRIPTION

    Create a new master database from scratch


=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::Test::BuildTestMasterDatabase_conf -dst_host <host> -dst_port <port>

    #1. Clone data regions from JSON files
    #2. Create a new master_db

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::Test::BuildTestMasterDatabase_conf;

use strict;
use warnings;
use File::Spec;

use Bio::EnsEMBL::Hive::Version 2.4;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use base ('Bio::EnsEMBL::Compara::PipeConfig::BuildNewMasterDatabase_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        'division'      => 'test',
        'input'         => $self->check_dir_in_ensembl('ensembl-compara/modules/t/test_division'),
        'pre_reg_conf'  => $self->check_file_in_ensembl('ensembl-compara/modules/t/test_division/production_reg_pre_test_conf.pl'),
        'reg_conf_tmpl' => $self->check_file_in_ensembl('ensembl-compara/scripts/pipeline/production_reg_test_conf_tmpl.pl'),

        # PrepareMasterDatabaseForRelease pipeline configuration:
        'assembly_patch_species' => [],
    };
}

1;
