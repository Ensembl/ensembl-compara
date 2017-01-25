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

package EnsEMBL::Web::ViewConfig::Transcript::ProteinSeq;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ViewConfig::TextSequence);

sub init_cacheable {
  ## @override
  my $self = shift;

  $self->SUPER::init_cacheable;

  $self->set_default_options({
    'exons'       => 'on',
    'exons_case'  => 'off',
    'snp_display' => 'off',
    'number'      => 'off'
  });

  $self->title('Protein Sequence');
}

sub field_order {
  ## Abstract method implementation
  return qw(display_width exons exons_case), $_[0]->variation_fields, qw(number);
}

sub form_fields {
  ## Abstract method implementation
  my $self    = shift;
  my $markup  = $self->get_markup_options({'no_snp_link' => 1});
  my $fields  = {};

  $markup->{'display_width'}{'label'}   = 'Number of amino acids per row';
  $markup->{'display_width'}{'values'}  = [ map {{ 'value' => $_, 'caption' => "$_ aa" }} map 10*$_, 3..20 ];
  $markup->{'number'}                   = { 'type'  => 'Checkbox', 'name'  => 'number', 'label' => 'Number residues', 'value' => 'on' };

  $fields->{$_} = $markup->{$_} for $self->field_order;

  return $fields;
}

1;
