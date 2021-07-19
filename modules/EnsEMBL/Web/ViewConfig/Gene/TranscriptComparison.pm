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

package EnsEMBL::Web::ViewConfig::Gene::TranscriptComparison;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ViewConfig::TextSequence);

sub init_cacheable {
  ## @override
  my $self = shift;

  $self->SUPER::init_cacheable;

  $self->set_default_options({
    'display_width'   => 120,
    'exons_only'      => 'off',
    'snp_display'     => 'on',
    'line_numbering'  => 'sequence',
    'flank3_display'  => 0,
    'flank5_display'  => 0,
  });

  $self->title('Transcript comparison');
}

sub field_order {
  ## Abstract method implementation
  return
    qw(flank5_display flank3_display display_width exons_only),
    $_[0]->variation_fields,
    qw(line_numbering title_display);
}

sub form_fields {
  ## Abstract method implementation
  my $self    = shift;
  my $markup  = $self->get_markup_options({'no_snp_link' => 1});
  my $fields  = {};

  $fields->{$_} = $markup->{$_} for $self->field_order;

  return $fields;
}

sub extra_tabs {
  ## @override
  my $self = shift;
  my $hub  = $self->hub;

  return [
    'Select transcripts',
    $hub->url('MultiSelector', {
      'action'    => 'TranscriptComparisonSelector',
      %{$hub->multi_params}
    })
  ];
}

1;
