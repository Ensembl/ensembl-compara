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

package EnsEMBL::Web::ZMenu::VUserData;

use strict;

use EnsEMBL::Web::File::User;
use EnsEMBL::Web::IOWrapper;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  my $hub = $self->hub;

  my $click_data = $self->click_data;

  return unless $click_data;

  my $track_config  = $click_data->{'my_config'};
  my $slice         = $click_data->{'container'};
  return unless $slice;

  ## Fetch the require features from this location
  my $format = $track_config->get('format');
  my %args = (
              'hub'     => $hub,
              'format'  => $format,
              'file'    => $track_config->get('file'),
              );

  my $file  = EnsEMBL::Web::File::User->new(%args);
  my $iow = EnsEMBL::Web::IOWrapper::open($file,
                                             'hub'         => $hub,
                                             'config_type' => $click_data->{'config'}->type,
                                             'track'       => $track_config->get('id'),
                                             );

  my $tracks  = $iow->create_tracks($slice);
  
  my @features;

  foreach (@{$tracks||[]}) {
    push @features, @{$_->{'features'}||[]};
    push @features, @{$_->{'features'}||[]};
  }

  $self->{'feature_count'} = scalar @features;

  if (scalar @features) {
    my $plural  = scalar @features > 1 ? 's' : '';

    foreach my $f (@features) {
      my $id      = $f->{'label'} || $format; 
      $self->caption("Feature: $id");

      my $r = $f->{'seq_region'}.':'.$f->{'start'}.'-'.$f->{'end'};
      $self->add_entry({
        type  => "Location", 
        label => $r,
        link  => $hub->url({
                          'type'    => 'Location',
                          'action'  => 'View',
                          'r'       => $r,
                        }),
      });
      if ($f->{'score'}) {
        $self->add_entry({
          type  => "Score", 
          label => $f->{'score'},
        });
      }
    }
  }
}

1;
