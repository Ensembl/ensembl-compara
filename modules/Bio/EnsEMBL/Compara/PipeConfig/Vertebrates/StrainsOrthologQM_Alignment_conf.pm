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

Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::StrainsOrthologQM_Alignment_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::StrainsOrthologQM_Alignment_conf -host mysql-ens-compara-prod-X -port XXXX \
        -member_type <protein_or_ncrna> -strain_collection <murinae_or_sus>

=head1 DESCRIPTION

This pipeline uses whole genome alignments to calculate the coverage of
homologous pairs for Vertebrates strains. See parent class for additional
information.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::StrainsOrthologQM_Alignment_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::OrthologQM_Alignment_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        'collection'  => $self->o('strain_collection'),
        
        'compara_db'  => '#expr( (#member_type# eq "protein") ? "#collection#_ptrees" : "#collection#_nctrees" )expr#',
    };
}

sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},

        'collection' => $self->o('collection'),
    }
}


1;
