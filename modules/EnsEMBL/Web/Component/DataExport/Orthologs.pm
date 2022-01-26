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

package EnsEMBL::Web::Component::DataExport::Orthologs;

use strict;
use warnings;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::Component::DataExport::Alignments);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self  = shift;
  my $hub   = $self->hub;
  my $cdb   = $hub->param('cdb') || 'compara';

  ## Note - these options aren't available on the page, so they
  ## don't belong in the view_config
  my $markup_options  = EnsEMBL::Web::Constants::MARKUP_OPTIONS;
  my %seq_element     = %{$markup_options->{'seq_type'}};
  my %align_element   = %seq_element;
  my @values          = @{$seq_element{'values'}};
  ## Removed unaligned sequence values from dropdown
  pop @values;
  pop @values;
  $align_element{'values'} = \@values;

  my $settings = {
                  'seq_type'    => \%seq_element,
                  'align_type'  => \%align_element, 
                  };

  ## Pass species selection to output
  my $species_options = [];
  foreach (grep { /^species_/ } $hub->param) {
    push @$species_options, $_;
  }

  $settings->{'Hidden'} = $species_options;

  ## Options per format
  my $fields_by_format = {'OrthoXML' => [], 'PhyloXML' => []};

  ## Add formats output by BioPerl, unless this is a pan-compara page
  unless ($cdb eq 'compara_pan_ensembl') {
    foreach ($self->alignment_formats) {
      my $field = $_ eq 'FASTA' ? 'seq_type' : 'align_type';
      $fields_by_format->{$_} = [$field];
    }
  }

  ## Create settings form (comes with some default fields - see parent)
  my $form = $self->create_form($settings, $fields_by_format, 1);

  return $form->render;
}

sub default_file_name {
  my $self = shift;
  (my $name = $self->hub->species_defs->SPECIES_DISPLAY_NAME) =~ s/ /_/g;

  $name .= '_'.$self->hub->param('gene_name').'_orthologues';
  return $name;
}

1;
