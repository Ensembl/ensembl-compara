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

package EnsEMBL::Draw::GlyphSet::fg_bigbed;

### Draw a Regulation track from a bigBed file 

use strict;

use EnsEMBL::Web::File::Utils::IO qw(file_exists);

use parent qw(EnsEMBL::Draw::GlyphSet::bigbed);

sub supports_subtitles { 0; }

sub get_data {
  my $self    = shift;
  my $slice   = $self->{'container'}; 
  return if $slice->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice'); # XXX Seems not to have adaptors?

  my $config  = $self->{'config'};

  if ($slice->length > 200000) {
    if ($config->{'_sent_bigbed_error_track'}) {
      return undef;
    } else {
      $config->{'_sent_bigbed_error_track'} = 1;
      $self->{'no_empty_track_message'}  = 1;
      return $self->errorTrack('BigBed tracks are only viewable on images less than 200kb in size');
    }
  }
 
  my $bigbed_file = $self->get_filename;
  return unless $bigbed_file;
  
  my $file_path = join '/', $self->species_defs->DATAFILE_BASE_PATH, lc $self->species, $self->species_defs->ASSEMBLY_VERSION;
  $bigbed_file = "$file_path/$bigbed_file" unless $bigbed_file =~ /^$file_path/;
  ## Clean up any whitespace
  $bigbed_file =~ s/\s//g;
 
=pod 
  my $check = file_exists($bigbed_file, {'nice' => 1});
  if ($check->{'error'}) {
    $self->no_file('555');
    return [];
  }
=cut

  return $self->SUPER::get_data($bigbed_file);
}

1;
