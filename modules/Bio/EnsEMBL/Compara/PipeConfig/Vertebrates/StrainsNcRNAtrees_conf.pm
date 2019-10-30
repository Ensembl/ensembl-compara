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

Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::StrainsNcRNAtrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::StrainsNcRNAtrees_conf -host mysql-ens-compara-prod-X -port XXXX \
        -mlss_id <curr_ncrna_mlss_id> -projection_source_species_names <list_of_species_names> \
        -multifurcation_deletes_all_subnodes <list_of_root_node_to_flatten>

=head1 DESCRIPTION

This is the Strains/Breeds PipeConfig for the Vertebrates ncRNAtrees pipeline.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::StrainsNcRNAtrees_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::ncRNAtrees_conf');

sub default_options {
    my ($self) = @_;

    return {
            %{$self->SUPER::default_options},

            'skip_epo'          => 1,

            # Where to draw the orthologues from
            'ref_ortholog_db'   => 'compara_nctrees',

            # CAFE parameters
            'initialise_cafe_pipeline'  => 0,
    };
}   

sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class

        'ref_ortholog_db'   => $self->o('ref_ortholog_db'),
    }
}

sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    $analyses_by_name->{'insert_member_projections'}->{'-parameters'}->{'source_species_names'} = $self->o('projection_source_species_names');
    $analyses_by_name->{'make_species_tree'}->{'-parameters'}->{'allow_subtaxa'} = 1;  # We have sub-species
    $analyses_by_name->{'make_species_tree'}->{'-parameters'}->{'multifurcation_deletes_all_subnodes'} = $self->o('multifurcation_deletes_all_subnodes');
    $analyses_by_name->{'orthotree_himem'}->{'-rc_name'} = '2Gb_job';
}


1;
