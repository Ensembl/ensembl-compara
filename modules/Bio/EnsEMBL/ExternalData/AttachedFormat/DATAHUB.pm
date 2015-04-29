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

package Bio::EnsEMBL::ExternalData::AttachedFormat::DATAHUB;

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::File::Utils::TrackHub;

use base qw(Bio::EnsEMBL::ExternalData::AttachedFormat);
use EnsEMBL::Web::File::Utils::URL qw(chase_redirects);

sub new {
  my $self = shift->SUPER::new(@_);
  
  $self->{'trackhub'} = EnsEMBL::Web::File::Utils::TrackHub->new('hub' => $self->{'hub'},
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
  my $error;
  
  my $hub_info = $self->{'trackhub'}->get_hub({'assembly_lookup' => $assembly_lookup,
                                               'parse_tracks' => 0});
  
  if ($hub_info->{'error'}) {
    $error  = sprintf('<p>Unable to attach remote TrackHub: %s</p>', $self->url);
    $error .= "<p>$_.</p>" for ref $hub_info->{'error'} eq 'ARRAY' 
                ? @{$hub_info->{'error'}} : $hub_info->{'error'};
  }
  my @assemblies = keys %{$hub_info->{'genomes'}||{}};
  return ($error, { name => $hub_info->{'details'}{'shortLabel'}, assemblies => \@assemblies});  
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
