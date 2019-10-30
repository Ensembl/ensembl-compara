
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

Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::Families_conf

=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #2. Ensure that LoadMembers pipeline has been run

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:

        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::Families_conf -host mysql-ens-compara-prod-X -prod XXXX \
            -mlss_id <curr_family_mlss_id>

    #5. Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output

=head1 DESCRIPTION

The PipeConfig file for Vertebrates Families pipeline that should automate most of the tasks.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::Families_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::Families_conf');

sub default_options {

    my ($self) = @_;
    return {
        %{ $self->SUPER::default_options },

        'division' => 'vertebrates',
    };
} ## end sub default_options


1;

