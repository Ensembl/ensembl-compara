=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

use base qw(EnsEMBL::Draw::GlyphSet::bigbed);

sub supports_subtitles { 0; }

sub get_data {
  my $self    = shift;
  my $slice   = $self->{'container'}; 
  my $config  = $self->{'config'};
  my $type    = $self->type;
  my $data_id = $self->my_config('data_id');
  
  return unless defined $data_id;

  if ($slice->length > 200000) {
    if ($config->{'_sent_ch3_error_track'}) {
      return undef;
    } else {
      $config->{'_sent_ch3_error_track'} = 1;
      $self->{'no_empty_track_message'}  = 1;
      return $self->errorTrack('Methylation data is only viewable on images less than 200kb in size');
    }
  }
 
  ## Use the score to create a colour gradient
  $self->{'my_config'}->set('spectrum', 'on');
 
  my $fgh = $slice->adaptor->db->get_db_adaptor('funcgen');
  
  return if $slice->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice'); # XXX Seems not to have adaptors?
  
  my $rsa = $fgh->get_ResultSetAdaptor;
  my $rs  = $rsa->fetch_by_dbID($data_id);
  
  return unless defined $rs;

  my $bigbed_file = $rs->dbfile_path;
  
  # Substitute path, if necessary. TODO: use DataFileAdaptor  

  my $file_path = join '/', $self->species_defs->DATAFILE_BASE_PATH, lc $self->species, $self->species_defs->ASSEMBLY_VERSION;
  $bigbed_file = "$file_path/$bigbed_file" unless $bigbed_file =~ /^$file_path/;
  ## Clean up any whitespace
  $bigbed_file =~ s/\s//g;
  
  return $self->SUPER::get_data($bigbed_file);
}

sub render_compact {
  my $self = shift;
  $self->{'legend'}{'fg_methylation_legend'} = 1; # instruct to draw legend
  $self->{'my_config'}->set('link_on_bgd', 1);
  $self->SUPER::render_compact;  
}

sub href           { return undef; } # tie to background

sub bg_link {
  my ($self, $strand) = @_;
  
  return $self->_url({
    action   => 'Methylation',
    ftype    => 'Regulation',
    dbid     => $self->my_config('data_id'),
    species  => $self->species,
    fdb      => 'funcgen',
    scalex   => $self->scalex,
    strand   => $strand,
    width    => $self->{'container'}->length,
  });
}

1;
