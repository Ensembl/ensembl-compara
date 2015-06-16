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

package EnsEMBL::Web::ViewConfig::Transcript::ExonsSpreadsheet;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig::TextSequence);

sub init {
  my $self = shift;

  $self->set_defaults({
    sscon           => 25,
    flanking        => 50,
    fullseq         => 'off',
    exons_only      => 'off',
    line_numbering  => 'off',
    snp_display     => 'exon',
  });


  $self->title = 'Exons';
  $self->SUPER::init;
}

sub field_order {
  my $self = shift;
  return qw(flanking display_width sscon fullseq exons_only line_numbering snp_display hide_long_snps consequence_filter);
}

sub form_fields {
  my $self = shift;
   
  my $markup_options  = EnsEMBL::Web::Constants::MARKUP_OPTIONS;
  my $fields = {};

  $markup_options->{'flanking'} = {
    type  => 'NonNegInt',
    label => 'Flanking sequence at either end of transcript',
    name  => 'flanking'
  };
  
  $markup_options->{'sscon'} = {
    type  => 'NonNegInt',
    label => 'Intron base pairs to show at splice sites', 
    name  => 'sscon'
  };
  
  $markup_options->{'fullseq'} = {
    type  => 'CheckBox',
    label => 'Show full intronic sequence',
    name  => 'fullseq',
    value => 'on',
  };
  
  $markup_options->{'line_numbering'}{'values'} = [
      { value => 'gene',  caption => 'Relative to the gene'            },
      { value => 'cdna',  caption => 'Relative to the cDNA'            },
      { value => 'cds',   caption => 'Relative to the coding sequence' },
      { value => 'slice', caption => 'Relative to coordinate systems'  },
      { value => 'off',   caption => 'None'                            },
  ];
  
  $self->add_variation_options($markup_options, { populations => [ 'fetch_all_LD_Populations' ], snp_display => [{ value => 'exon', caption => 'In exons only' }], snp_link => 'no' }) if $self->species_defs->databases->{'DATABASE_VARIATION'};
 
  ## THIS DOESN'T SEEM TO HAVE ANY EFFECT! 
  #$_->set_flag($self->SELECT_ALL_FLAG) for @{$self->get_form->fieldsets};

  foreach ($self->field_order) {
    next unless $markup_options->{$_};
    $fields->{$_} = $markup_options->{$_};
    $fields->{$_}{'value'} = $self->get($_);
  }

  return $fields;
}


1;
