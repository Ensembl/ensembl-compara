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

package EnsEMBL::Draw::GlyphSet::Generic;

### Parent for new-style glyphsets

use strict;

use Role::Tiny;

use parent qw(EnsEMBL::Draw::GlyphSet);

sub can_json { return 1; }

sub init {
  my $self = shift;
  my @roles;
  ## Always show user tracks, regardless of overall configuration
  $self->{'my_config'}->set('show_empty_track', 1);
  my $style = $self->my_config('style') || $self->my_config('display') || '';

  if ($style eq 'wiggle' || $style =~ /signal/ || $style eq 'gradient') {
    push @roles, 'EnsEMBL::Draw::Role::Wiggle';
  }
  else {
    push @roles, 'EnsEMBL::Draw::Role::Alignment';
  }
  push @roles, 'EnsEMBL::Draw::Role::Default';

  ## Don't try to apply non-existent roles, or Role::Tiny will complain
  if (scalar @roles) {
    Role::Tiny->apply_roles_to_object($self, @roles);
  }

  $self->{'data'} = $self->get_data;
}

sub get_data {
  my $self = shift;
  warn ">>> IMPORTANT - THIS METHOD MUST BE IMPLEMENTED IN MODULE $self!";
=pod

Because user files can contain multiple datasets, this method should return data 
in the following format:

$data = [
         { #Track1
          'metadata' => {},
          'features' => {
                           '1'  => [{}],
                          '-1'  => [{}],
                        },
          },
          { #Track2
           ... etc...
          },
        ];

The keys of the feature hashref refer to the strand on which we wish to draw the data
(as distinct from the strand on which the feature is actually found, which may be different)
- this should be determined in the file parser, based on settings passed to it

=cut
}

sub my_empty_label {
  my $self = shift;
  return sprintf('No features from %s on this strand', $self->my_config('name'));
}

1;
