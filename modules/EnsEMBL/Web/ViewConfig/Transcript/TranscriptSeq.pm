=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

use base qw(EnsEMBL::Web::ViewConfig::TextSequence);

sub init {
  my $self = shift;
  
  $self->set_defaults({
    exons          => 'on',
    exons_case     => 'off',
    codons         => 'on',
    utr            => 'on',
    coding_seq     => 'on',
    translation    => 'on',
    rna            => 'off',
    snp_display    => 'on',
    line_numbering => 'on',
  });
  
  $self->title = 'cDNA sequence';
  $self->SUPER::init;
}

sub field_order {
  my $self = shift;
  my @order = qw(exons exons_case codons utr coding_seq translation rna);
  push @order, $self->variation_fields if $self->species_defs->databases->{'DATABASE_VARIATION'};
  push @order, qw(line_numbering);
  return @order;
}

sub form_fields {
  my $self = shift;
  my $markup_options  = EnsEMBL::Web::Constants::MARKUP_OPTIONS;
  my $fields = {};

  my @extra = (
    ['codons',      'codons'],
    ['utr',         'UTR'],
    ['coding_seq',  'coding sequence'],
    ['translation', 'protein sequence'],
    ['rna',         'RNA features'],
  );

  foreach (@extra) {
    my ($name, $label) = @$_;
    $markup_options->{$name} = {
                                type  => 'Checkbox', 
                                name  => $name,
                                value => 'on',       
                                label => "Show $label",         
     };
  }

  ## Switch line-numbering to a checkbox as it doesn't have multiple options
  $markup_options->{'line_numbering'}{'type'} = 'Checkbox';
  $markup_options->{'line_numbering'}{'value'} = 'sequence';
  delete $markup_options->{'line_numbering'}{'values'};

  my $var_options = { populations => [ 'fetch_all_HapMap_Populations', 'fetch_all_1KG_Populations' ], snp_link => 'no' };

  $self->add_variation_options($markup_options, $var_options) if $self->species_defs->databases->{'DATABASE_VARIATION'};

  foreach ($self->field_order) {
    $fields->{$_} = $markup_options->{$_};
    $fields->{$_}{'value'} = $self->get($_);
  }

  return $fields;
}

1;
