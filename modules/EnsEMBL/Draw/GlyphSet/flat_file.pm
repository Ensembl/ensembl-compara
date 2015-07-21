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

package EnsEMBL::Draw::GlyphSet::flat_file;

### Module for drawing features parsed from a non-indexed text file (such as 
### user-uploaded data)

use strict;

use EnsEMBL::Web::File::User;
use EnsEMBL::Web::IOWrapper;

use EnsEMBL::Draw::Style::Blocks;

use base qw(EnsEMBL::Draw::GlyphSet);

sub features {
  my $self         = shift;
  my $container    = $self->{'container'};
  my $species_defs = $self->species_defs;
  my $sub_type     = $self->my_config('sub_type');
  my $features     = [];

  ## Get the file contents
  my %args = ('hub' => $self->{'config'}->hub);

  if ($sub_type eq 'url') {
    $args{'file'} = $self->my_config('url');
    $args{'input_drivers'} = ['URL'];
  }
  else {
    $args{'file'} = $self->my_config('file');
    if ($args{'file'} !~ /\//) { ## TmpFile upload
      $args{'prefix'} = 'user_upload';
    }
  }

  my $file  = EnsEMBL::Web::File::User->new(%args);
  my $iow   = EnsEMBL::Web::IOWrapper->new($file);

  ## Loop through parser
  if ($iow) {
    while ($iow->next) {
      my ($seqname, $start, $end) = $iow->coords;
      ## Skip features that lie outside the current slice
      next unless ($seq_name eq $container->seq_region_name 
                    && (
                         ($start >= $container->start && $end <= $container->end)
                      || ($start <= $container->start && $end <= $container->end)
                      || ($start <= $container->end && $end >= $container->start) 
                    ));


      push @$features, $iow->create_hash;
    }

  } else {
    return $self->errorTrack(sprintf 'Could not read file %s', $self->my_config('caption'));
    warn "!!! ERROR READING FILE: ".$response->{'error'}[0];
  }
}

sub href {
}

1;
