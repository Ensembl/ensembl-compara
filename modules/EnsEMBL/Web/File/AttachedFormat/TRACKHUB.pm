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

package EnsEMBL::Web::File::AttachedFormat::TRACKHUB;

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::Utils::TrackHub;
use EnsEMBL::Web::File::Utils::URL qw(chase_redirects);

use base qw(EnsEMBL::Web::File::AttachedFormat);

sub new {
  my $self = shift->SUPER::new(@_);
  
  $self->{'trackhub'} = EnsEMBL::Web::Utils::TrackHub->new('hub' => $self->{'hub'},
                                                                 'url' => $self->{'url'});
  return $self;
}

sub check_data {
### Checks if this hub is a) available and b) usable
### @param assembly_lookup HashRef (optional) - passed to TrackHub
### @return Array
###               error ArrayRef
###               hub_info HashRef
  my ($self, $assembly_lookup) = @_;
  my $url = $self->{'url'};
  my $error;
 
  ## Check that we can use it with this website's species
  ## Hack to catch IHEC Epigenomes Portal issues
  my $parse_tracks = ($url =~ /epigenomesportal/) ? 1 : 0;
  my $hub_params = {'parse_tracks' => $parse_tracks};
  ## Don't check assembly if the hub came from the registry
  my $assembly_check = $self->{'registry'} ? 0 : 1;
  $hub_params->{'assembly_lookup'} = $assembly_lookup if $assembly_check;
  my $hub_info = $self->{'trackhub'}->get_hub($hub_params);
  
  if ($hub_info->{'error'}) {
    $error  = sprintf('<p>Unable to attach remote TrackHub: %s</p>', $self->url);
    if (ref $hub_info->{'error'} eq 'ARRAY') {
      $error .= "<p>$_.</p>" for @{$hub_info->{'error'}};
    }
    else {
      $error .= '<p>'.$hub_info->{'error'}.'</p>';
    }
    return ($self->url, $error, {'abort' => 1});
  }
  else {
    return ($self->url, undef, { 
                                name        => $hub_info->{'details'}{'shortLabel'}, 
                                description => $hub_info->{'details'}{'longLabel'}, 
                                assemblies  => $hub_info->{'genomes'} || {},
                              }
          );  
  }
}

sub style {
  my $self = shift;
  return $self->{'_cache'}{'style'} ||= $self->_calc_style;
}

sub _calc_style {
  my $self      = shift;
  my $tl_score  = 0;
  my $trackline = $self->{'trackline'};
  
  if ($trackline) {
    $trackline = $self->parse_trackline($trackline) || {};
    $tl_score  = $trackline->{'useScore'} || 0;
  }

  # WORK OUT HOW TO CONFIGURE FEATURES FOR RENDERING
  # Explicit: Check if mode is specified on trackline
  if ($tl_score == 2) {
    return 'score';
  } elsif ($tl_score == 1) {
    return 'colour';
  } elsif ($tl_score == 4) {
    return 'wiggle';
  } elsif ($tl_score == 0) {
    # Implicit: No help from trackline, have to work it out
    my $line_length = $self->{'datahub_adaptor'}->file_bedline_length;
    
    if ($line_length >= 8) {
      return 'colour';      
    } elsif ($line_length >= 5) {
      return 'score';
    } else {
      return 'plain';
    }
  }
}

1;
