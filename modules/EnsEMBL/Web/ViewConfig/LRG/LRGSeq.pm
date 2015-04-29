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

package EnsEMBL::Web::ViewConfig::LRG::LRGSeq;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig::TextSequence);

sub init {
  my $self = shift;
  
  $self->set_defaults({
    flank5_display => 0,
    flank3_display => 0,
    exon_display   => 'core',
    exon_ori       => 'all',
    snp_display    => 'snp_link',
    line_numbering => 'sequence'
  });

  $self->title = 'Sequence';
  $self->SUPER::init;
}

sub form {
  my $self                   = shift;
  my $dbs                    = $self->species_defs->databases;
  my %gene_markup_options    = EnsEMBL::Web::Constants::GENE_MARKUP_OPTIONS;
  my %general_markup_options = EnsEMBL::Web::Constants::GENERAL_MARKUP_OPTIONS;
  my %other_markup_options   = EnsEMBL::Web::Constants::OTHER_MARKUP_OPTIONS;
  
  push @{$gene_markup_options{'exon_display'}{'values'}}, { value => 'vega', caption => 'Vega exons' } if $dbs->{'DATABASE_VEGA'};
  
  $_->{'caption'} = 'Core and LRG exons' for grep $_->{'value'} eq 'core', @{$gene_markup_options{'exon_display'}{'values'}};

  push @{$gene_markup_options{'exon_display'}{'values'}}, { value => 'otherfeatures', caption => 'EST gene exons' } if $dbs->{'DATABASE_OTHERFEATURES'};
  
  $self->add_form_element($gene_markup_options{'flank5_display'});
  $self->add_form_element($gene_markup_options{'flank3_display'});
  $self->add_form_element($other_markup_options{'display_width'});
  $self->add_form_element($gene_markup_options{'exon_display'});
  $self->add_form_element($general_markup_options{'exon_ori'});
  $self->variation_options if $dbs->{'DATABASE_VARIATION'};
  $self->add_form_element($general_markup_options{'line_numbering'});
}

1;
