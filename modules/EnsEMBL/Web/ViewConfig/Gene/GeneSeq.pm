=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ViewConfig::Gene::GeneSeq;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ViewConfig::TextSequence);

sub init_cacheable {
  ## @override
  my $self = shift;

  $self->SUPER::init_cacheable;

  $self->title('Sequence');

  $self->set_default_options({
    'flank5_display'  => 600,
    'flank3_display'  => 600,
    'exon_display'    => 'core',
    'exon_ori'        => 'all',
    'snp_display'     => 'off',
    'line_numbering'  => 'off',
    'title_display'   => 'yes',
  });
}

sub field_order {
  ## Abstract method implementation
  return
    qw(flank5_display flank3_display display_width exon_display exon_ori),
    $_[0]->variation_fields,
    qw(line_numbering title_display);
}

sub form_fields {
  ## Abstract method implementation
  my ($self, $options) = @_;
  my $dbs     = $self->species_defs->databases;
  my $markup  = $self->get_markup_options({'vega_exon' => 1, 'otherfeatures_exon' => 1, %{$options||{}}});
  my $fields  = {};

  $fields->{$_} = $markup->{$_} for $self->field_order;

  return $fields;
}

1;
