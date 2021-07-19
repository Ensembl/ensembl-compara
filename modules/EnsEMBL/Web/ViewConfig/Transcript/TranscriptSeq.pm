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

package EnsEMBL::Web::ViewConfig::Transcript::TranscriptSeq;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ViewConfig::TextSequence);

sub init_cacheable {
  ## @override
  my $self = shift;

  $self->set_default_options({
    'exons'          => 'on',
    'exons_case'     => 'off',
    'codons'         => 'on',
    'utr'            => 'on',
    'coding_seq'     => 'on',
    'translation'    => 'on',
    'rna'            => 'off',
    'snp_display'    => 'on',
    'line_numbering' => 'on',
  });

  $self->title('cDNA sequence');
  $self->SUPER::init_cacheable(@_);
}

sub field_order {
  ## Abstract method implementation
  return qw(exons exons_case codons utr coding_seq translation rna), $_[0]->variation_fields, qw(line_numbering);
}

sub form_fields {
  ## Abstract method implementation
  my $self    = shift;
  my $markup  = $self->get_markup_options({'no_snp_link' => 1});
  my $fields  = {};

  my @extra   = (
    ['codons',      'codons'],
    ['utr',         'UTR'],
    ['coding_seq',  'coding sequence'],
    ['translation', 'protein sequence'],
    ['rna',         'RNA features'],
  );

  for (@extra) {
    my ($name, $label) = @$_;
    $markup->{$name} = {
      'type'  => 'Checkbox',
      'name'  => $name,
      'value' => 'on',
      'label' => "Show $label",
    };
  }

  # Switch line-numbering to a checkbox as it doesn't have multiple options
  $markup->{'line_numbering'}{'type'}   = 'Checkbox';
  $markup->{'line_numbering'}{'value'}  = 'sequence';
  delete $markup->{'line_numbering'}{'values'};

  $fields->{$_} = $markup->{$_} for $self->field_order;

  return $fields;
}

1;
