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

package EnsEMBL::Draw::GlyphSet::pairwise;

### Module for drawing data in WashU's tabix-indexed pairwise format

use strict;
use warnings;
no warnings 'uninitialized';

use List::Util qw(min max);

use EnsEMBL::Web::IOWrapper::Indexed;

use parent qw(EnsEMBL::Draw::GlyphSet::UserData);

sub can_json { return 1; }

sub get_data {
  my $self      = shift;
  my $hub       = $self->{'config'}->hub;
  my $url       = $self->my_config('url');
  my $container = $self->{'container'};
  my $args      = {'options' => {'hub' => $hub}};

  my $iow = EnsEMBL::Web::IOWrapper::Indexed::open($url, 'PairwiseTabix', $args);
  my $data;

  if ($iow) {
    ## We need to pass 'faux' metadata to the ensembl-io wrapper, because
    ## most files won't have explicit colour settings
    my $colour = $self->my_config('colour');
    my $metadata = {
                    'colour'          => $colour,
                    'join_colour'     => $colour,
                    'default_strand'  => 1,
                  };

    ## No colour defined in ImageConfig, so fall back to defaults
    unless ($colour) {
      my $colourset_key = $self->{'my_config'}->get('colourset') || 'userdata';
      my $colourset     = $hub->species_defs->colour($colourset_key);
      my $colours       = $colourset->{'url'} || $colourset->{'default'};
      $metadata->{'colour'}       = $colours->{'default'};
      $metadata->{'join_colour'}  = $colours->{'join'} || $colours->{'default'};
    }


    ## Parse the file, filtering on the current slice
    $data = $iow->create_tracks($container, $metadata);
    $self->{'data'} = $data;
  } else {
    $self->{'data'} = [];
    return $self->errorTrack(sprintf 'Could not read file %s', $self->my_config('caption'));
  }
  #$self->{'config'}->add_to_legend($legend);

  return $self->{'data'};
}
             



1;

