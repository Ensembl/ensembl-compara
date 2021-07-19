=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ViewConfig::LRG::LRGSeq;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ViewConfig::TextSequence);

sub init_cacheable {
  ## @override
  my $self = shift;

  $self->SUPER::init_cacheable;

  $self->set_default_options({
    'flank5_display' => 0,
    'flank3_display' => 0,
    'exon_display'   => 'core',
    'exon_ori'       => 'all',
    'snp_display'    => 'snp_link',
    'line_numbering' => 'sequence'
  });

  $self->title('Sequence');
}

sub field_order {
  ## Abstract method implementation
  return qw(flank5_display flank3_display display_width exon_display exon_ori), $_[0]->variation_fields, qw(line_numbering);
}

sub form_fields {
  ## Abstract method implementation
  my $self    = shift;
  my $markup  = $self->get_markup_options({'vega_exons' => 1, 'otherfeatures_exons' => 1});
  my $fields  = {};

  $_->{'caption'} = 'Core and LRG exons' for grep $_->{'value'} eq 'core', @{$markup->{'exon_display'}{'values'}};

  $fields->{$_} = $markup->{$_} for $self->field_order;

  return $fields;
}

1;
