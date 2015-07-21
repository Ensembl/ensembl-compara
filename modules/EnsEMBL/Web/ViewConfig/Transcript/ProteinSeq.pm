=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ViewConfig::Transcript::ProteinSeq;

use strict;

use base qw(EnsEMBL::Web::ViewConfig::TextSequence);

sub init {
  my $self = shift;
  
  $self->set_defaults({
    exons       => 'on',
    exons_case  => 'off',
    snp_display => 'off',
    number      => 'off'
  });

  $self->title = 'Protein Sequence';
  $self->SUPER::init;
}

sub field_order {
  my $self = shift;
  my @order = qw(display_width exons exons_case);
  push @order, $self->variation_fields if $self->species_defs->databases->{'DATABASE_VARIATION'};
  push @order, 'number';
  return @order;
}

sub form_fields {
  my $self = shift;
  my $markup_options  = EnsEMBL::Web::Constants::MARKUP_OPTIONS;
  my $fields = {};

  $markup_options->{'display_width'}{'label'} = 'Number of amino acids per row';
  $markup_options->{'display_width'}{'values'} = [
            map {{ value => $_, caption => "$_ aa" }} map 10*$_, 3..20
  ];
  
  $markup_options->{'number'} = {
                                  'type'  => 'Checkbox',
                                  'name'  => 'number',
                                  'label' => 'Number residues', 
                                  'value' => 'on',
  };

  $self->add_variation_options($markup_options, { populations => [ 'fetch_all_HapMap_Populations', 'fetch_all_1KG_Populations' ], snp_link => 'no' }) if $self->species_defs->databases->{'DATABASE_VARIATION'};

  foreach ($self->field_order) {
    $fields->{$_} = $markup_options->{$_};
    $fields->{$_}{'value'} = $self->get($_);
  }

  return $fields;
}

1;
