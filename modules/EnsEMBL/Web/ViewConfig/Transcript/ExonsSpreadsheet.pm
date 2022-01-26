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

package EnsEMBL::Web::ViewConfig::Transcript::ExonsSpreadsheet;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ViewConfig::TextSequence);

sub init_cacheable {
  ## @override
  my $self = shift;

  $self->SUPER::init_cacheable;

  $self->set_default_options({
    'sscon'           => 25,
    'flanking'        => 50,
    'fullseq'         => 'off',
    'exons_only'      => 'off',
    'line_numbering'  => 'off',
    'snp_display'     => 'exon',
  });

  $self->title('Exons');
}

sub field_order {
  ## Abstract method implementation
  my @out = (qw(flanking display_width sscon fullseq exons_only line_numbering), $_[0]->variation_fields);
  unless(grep { $_ eq 'consequence_filter' } @out) {
    push @out,'consequence_filter';
  }
  return @out;
}

sub form_fields {
  ## Abstract method implementation
  my $self    = shift;
  my $markup  = $self->get_markup_options({ 'snp_display_opts' => [{ 'value' => 'exon', 'caption' => 'In exons only' }], 'no_snp_link' => 1 });
  my $fields  = {};

  $markup->{'flanking'} = {
    'type'    => 'NonNegInt',
    'default' => '0',
    'label'   => 'Flanking sequence at either end of transcript',
    'name'    => 'flanking'
  };

  $markup->{'sscon'} = {
    'type'  => 'NonNegInt',
    'label' => 'Intron base pairs to show at splice sites',
    'name'  => 'sscon'
  };

  $markup->{'fullseq'} = {
    'type'  => 'CheckBox',
    'label' => 'Show full intronic sequence',
    'name'  => 'fullseq',
    'value' => 'on',
  };

  $markup->{'line_numbering'}{'values'} = [
    { 'value' => 'gene',  'caption' => 'Relative to the gene'            },
    { 'value' => 'cdna',  'caption' => 'Relative to the cDNA'            },
    { 'value' => 'cds',   'caption' => 'Relative to the coding sequence' },
    { 'value' => 'slice', 'caption' => 'Relative to coordinate systems'  },
    { 'value' => 'off',   'caption' => 'None'                            },
  ];

  $fields->{$_} = $markup->{$_} for $self->field_order;

  return $fields;
}

1;
