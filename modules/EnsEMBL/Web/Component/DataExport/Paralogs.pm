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

package EnsEMBL::Web::Component::DataExport::Paralogs;

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
  ### N.B. There currently are no additional options for alignment export
  my $self  = shift;
  my $hub   = $self->hub;

  ## Note - these options aren't available on the page, so they
  ## don't belong in the viewconfig
  my $markup_options  = EnsEMBL::Web::Constants::MARKUP_OPTIONS;
  my $settings = {'seq_type' => $markup_options->{'seq_type'}};

  ## Pass species selection to output
  my $species_options = [];
  foreach (grep { /^species_/ } $hub->param) {
    push @$species_options, $_;
  }

  $settings->{'Hidden'} = $species_options;

  ## Options per format
  my $fields_by_format = {'OrthoXML' => []};

  ## Add formats output by BioPerl
  foreach ($self->alignment_formats) {
    my $field = $_ eq 'FASTA' ? 'seq_type' : undef;
    $fields_by_format->{$_} = [$field];
  }

  ## Create settings form (comes with some default fields - see parent)
  my $form = $self->create_form($settings, $fields_by_format, 1);

  return $form->render;
}

sub default_file_name {
  my $self = shift;
  my $name = $self->hub->species_defs->SPECIES_COMMON_NAME;

  $name .= '_'.$self->hub->param('gene_name').'_paralogues';
  return $name;
}

1;
