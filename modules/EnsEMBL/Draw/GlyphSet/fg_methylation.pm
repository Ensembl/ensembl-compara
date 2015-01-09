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

package EnsEMBL::Draw::GlyphSet::fg_methylation;

### Draw DNA methylation tracks on, e.g., Region in Detail
### Based on BigBED glyphset, since that is how this data
### is currently stored

use strict;

use base qw(EnsEMBL::Draw::GlyphSet::bigbed);

sub features {
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
      return $self->errorTrack('Methylation data is only viewable on images  200kb in size');
    }
  }
  
  my $fgh = $slice->adaptor->db->get_db_adaptor('funcgen');
  
  return if $slice->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice'); # XXX Seems not to have adaptors?
  
  my $rsa = $fgh->get_ResultSetAdaptor;
  my $rs  = $rsa->fetch_by_dbID($data_id);
  
  return unless defined $rs;

  my $bigbed_file = $rs->dbfile_data_dir;
  
  # Substitute path, if necessary. TODO: use DataFileAdaptor  
  my @parts = split m!/!, $bigbed_file;
  
  $bigbed_file = join '/', $config->hub->species_defs->DATAFILE_BASE_PATH, @parts[-5..-1];
  
  return $self->SUPER::features({
    style   => 'colouredscore',
    adaptor => $slice->{'_cache'}{'bigbed_adaptor'}{$bigbed_file} ||= $self->bigbed_adaptor(Bio::EnsEMBL::ExternalData::BigFile::BigBedAdaptor->new($bigbed_file)),
  });
}

sub render_normal {
  my $self = shift;
  $self->{'renderer_no_join'}                = 1;
  $self->{'legend'}{'fg_methylation_legend'} = 1; # instruct to draw legend
  $self->SUPER::render_normal(8, 0);  
}

sub render_compact { shift->render_normal(@_); }
sub href           { return undef; } # tie to background

sub href_bgd {
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
