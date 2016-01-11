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

package EnsEMBL::Draw::GlyphSet::bigwig;

### Module for drawing data in BigWIG format (either user-attached, or
### internally configured via an ini file or database record

use strict;

use EnsEMBL::Web::IOWrapper::Indexed;

use parent qw(EnsEMBL::Draw::GlyphSet::UserData);

sub can_json { return 1; }

sub features {
  my $self      = shift;
  my $hub       = $self->{'config'}->hub;
  my $url       = $self->my_config('url');
  my $container = $self->{'container'};
  my $args      = { 'options' => {
                                  'hub'         => $hub,
                                  'config_type' => $self->{'config'}{'type'},
                                  'track'       => $self->{'my_config'}{'id'},
                                  },
                    'default_strand' => 1,
                    'drawn_strand' => $self->strand};

  my $iow = EnsEMBL::Web::IOWrapper::Indexed::open($url, 'BigWig', $args);
  my $data;

  if ($iow) {
    ## We need to pass 'faux' metadata to the ensembl-io wrapper, because
    ## most files won't have explicit colour settings
    my $colour = $self->my_config('colour');
    my $metadata = {
                    'name'            => $self->{'my_config'}->get('name'),
                    'colour'          => $colour,
                    'join_colour'     => $colour,
                    'label_colour'    => $colour,
                    'display'         => $self->{'display'},
                    'default_strand'  => 1,
                    };
    ## No colour defined in ImageConfig, so fall back to defaults
    unless ($colour) {
      my $colourset_key           = $self->{'my_config'}->get('colourset') || 'userdata';
      my $colourset               = $hub->species_defs->colour($colourset_key);
      my $colours                 = $colourset->{'url'} || $colourset->{'default'};
      $metadata->{'colour'}       = $colours->{'default'};
      $metadata->{'join_colour'}  = $colours->{'join'} || $colours->{'default'};
      $metadata->{'label_colour'} = $colours->{'text'} || $colours->{'default'};
    }

    ## Tell the parser to get aggregate data if necessary
    $metadata->{'aggregate'} = 1 if $self->{'my_config'}->get('display') eq 'compact';

    ## Parse the file, filtering on the current slice
    $data = $iow->create_tracks($container, $metadata);

  } else {
    #return $self->errorTrack(sprintf 'Could not read file %s', $self->my_config('caption'));
    warn "!!! ERROR CREATING PARSER FOR BIGBED FORMAT";
  }
  #$self->{'config'}->add_to_legend($legend);

  return $data;
}

sub render_text {
  my ($self, $wiggle) = @_;
  warn 'No text render implemented for bigwig';
  return '';
}

1;
