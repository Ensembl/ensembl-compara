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

package EnsEMBL::Web::ViewConfig::Gene::GeneSeq;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig::TextSequence);

sub init {
  my $self = shift;
  
  $self->SUPER::init;
  $self->title = 'Sequence';
  
  $self->set_defaults({
    flank5_display => 600,
    flank3_display => 600,
    exon_display   => 'core',
    exon_ori       => 'all',
    snp_display    => 'off',
    line_numbering => 'off',
    title_display  => 'yes',
  });
}

sub field_order {
  my $self = shift;
  my $dbs   = $self->species_defs->databases;
  my @order = qw(flank5_display flank3_display display_width exon_display exon_ori);
  push @order, $self->variation_fields if $dbs->{'DATABASE_VARIATION'};
  push @order, qw(line_numbering title_display);
  return @order;
}

sub form_fields {
  my $self            = shift;
  my $dbs             = $self->species_defs->databases;
  my $markup_options  = EnsEMBL::Web::Constants::MARKUP_OPTIONS;
  my $fields = {};

  push @{$markup_options->{'exon_display'}{'values'}}, { value => 'vega',          caption => 'Vega exons' } if $dbs->{'DATABASE_VEGA'};
  push @{$markup_options->{'exon_display'}{'values'}}, { value => 'otherfeatures', caption => 'EST gene exons' } if $dbs->{'DATABASE_OTHERFEATURES'};

  $self->add_variation_options($markup_options) if $dbs->{'DATABASE_VARIATION'};
 
  foreach ($self->field_order) {
    $fields->{$_} = $markup_options->{$_};
    $fields->{$_}{'value'} = $self->get($_);
  }
 
  return $fields; 
}

1;
