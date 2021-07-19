=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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
use Scalar::Util qw(looks_like_number);

use parent qw(EnsEMBL::Draw::GlyphSet::UserData);


sub get_data {
### Method to parse a data file and return information to be displayed
### @return Arrayref - see parent
  my $self         = shift;
  my $data         = [];
  
  my ($skip, $strand_to_omit) = $self->get_strand_filters;
  return $data if $skip == $self->strand;

  my $container    = $self->{'container'};
  my $hub          = $self->{'config'}->hub;
  my $species_defs = $self->species_defs;
  my $type         = $self->my_config('type') || $self->my_config('sub_type');
  my $format       = $self->my_config('format');
  my $legend       = {};

  ## Get the file contents
  my %args = (
              'hub'     => $hub,
              'format'  => $format,
              );

  if ($type && $type eq 'url') {
    $args{'file'} = $self->my_config('url');
    $args{'input_drivers'} = ['URL'];
  }
  else {
    $args{'file'} = $self->my_config('file');
  }

  my $file  = EnsEMBL::Web::File::User->new(%args);
  return [] unless $file->exists;
  
  ## Set style for VCF here, as other formats define it in different ways
  my $adaptor;
  if ($format =~ /vcf/i) {
    $self->{'my_config'}->set('drawing_style', ['Feature::Variant']);
    $self->{'my_config'}->set('height', 12);
    $self->{'my_config'}->set('show_overlay', 1);
    ## Also create adaptor, so we can look up consequence in db
    $adaptor = $self->{'config'}->hub->database('variation') ? $self->{'config'}->hub->database('variation')->get_VariationFeatureAdaptor : undef; 
  }

  ## Get settings from user interface
  my ($colour, $y_min, $y_max);
  if ($self->{'my_config'}{'data'}) {
    $colour = $self->{'my_config'}{'data'}{'colour'};
    $y_min  = $self->{'my_config'}{'data'}{'y_min'} if looks_like_number($self->{'my_config'}{'data'}{'y_min'});
    $y_max  = $self->{'my_config'}{'data'}{'y_max'} if looks_like_number($self->{'my_config'}{'data'}{'y_max'});
  }

  my $iow     = EnsEMBL::Web::IOWrapper::open($file, 
                                              'hub'         => $hub, 
                                              'adaptor'     => $adaptor,
                                              'config_type' => $self->{'config'}{'type'},
                                              'track'       => $self->{'my_config'}{'id'},
                                              );
  if ($iow) {
    ## Override colourset based on format here, because we only want to have to do this in one place
    my $colourset   = $iow->colourset || 'userdata';
    my $colours     = $hub->species_defs->colour($colourset);
    $self->{'my_config'}->set('colours', $colours);

    $colour       ||= $self->my_colour('default');
    $self->{'my_config'}->set('colour', $colour);

    my $extra_config = {
                        'strand_to_omit'  => $strand_to_omit,
                        'display'         => $self->{'display'},
                        'use_synonyms'    => $hub->species_defs->USE_SEQREGION_SYNONYMS,
                        'colour'          => $colour,
                        'colours'         => $colours,
                        'y_min'           => $y_min, 
                        'y_max'           => $y_max, 
                        };

    ## Parse the file, filtering on the current slice
    $data = $iow->create_tracks($container, $extra_config);
    #use Data::Dumper; warn '>>> TRACKS '.Dumper($data);
  } else {
    $self->{'data'} = [];
    return $self->errorTrack(sprintf 'Could not read file %s', $self->my_config('caption'));
  }
  #$self->{'config'}->add_to_legend($legend);
  return $data;
}

1;
