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

package EnsEMBL::Draw::GlyphSet::fg_methylation;

### Draw DNA methylation tracks on, e.g., Region in Detail
### Based on BigBED glyphset, since that is how this data
### is currently stored

use strict;

use URI::Escape qw(uri_escape);

use parent qw(EnsEMBL::Draw::GlyphSet::fg_bigbed);

sub supports_subtitles { 0; }

sub get_filename {
  my $self    = shift;
  my $slice   = $self->{'container'}; 
  my $data_id = $self->my_config('data_id');
  return unless defined $data_id;

  ## Settings that affect parsing have to go in the data-fetching step 
  $self->{'my_config'}->set('spectrum', 'on');

  my $fgh     = $slice->adaptor->db->get_db_adaptor('funcgen');
  my $dma     = $fgh->get_DNAMethylationFileAdaptor;
  my $meth    = $dma->fetch_by_name($data_id);
  return unless defined $meth;

  return $meth->file;
}

sub render_compact {
  my $self = shift;
  $self->{'legend'}{'fg_methylation_legend'} = 1; # instruct to draw legend
  $self->SUPER::render_compact;  
}

sub extra_metadata {
  my ($self, $metadata) = @_;
  $metadata->{'zmenu_caption'} = 'DNA Methylation';
}

=pod
sub bg_link {
  my ($self, $strand) = @_;

  return $self->_url({
    action   => 'Methylation',
    ftype    => 'Regulation',
    dbid     => uri_escape($self->my_config('data_id')),
    species  => $self->species,
    fdb      => 'funcgen',
    scalex   => $self->scalex,
    strand   => $strand || 0,
    width    => $self->{'container'}->length,
  });
}
=cut

1;
