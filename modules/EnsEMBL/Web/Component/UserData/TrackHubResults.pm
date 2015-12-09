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

package EnsEMBL::Web::Component::UserData::TrackHubResults;

### Display the results of the track hub registry search

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::REST;

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return 'Choose a Track Hub';
}

sub content {
  my $self            = shift;
  my $hub             = $self->hub;
  my $sd              = $hub->species_defs;
  my $html;

  ## REST call
  my $rest = EnsEMBL::Web::REST->new($hub, $sd->TRACKHUB_REGISTRY_URL);
  return unless $rest;

  my $endpoint = 'api/search';

  my $post_content = {};
  my @query_params = qw(species assembly query);
  foreach (@query_params) {
    $post_content->{$_} = $hub->param($_) if $hub->param($_);
  }

  my $args = {'method' => 'post', 'content' => $post_content};
  
  my ($result, $error) = $rest->fetch($endpoint, $args);
  use Data::Dumper; warn Dumper($result);

  if ($error) {
    $html = '<p>Sorry, we are unable to fetch data from the Track Hub Registry at the moment</p>';
  }
  else {
    my $count   = $result->{'total_entries'};
    my $plural  = $count == 1 ? '' : 's';
    $html .= sprintf('<p>Found %s track hub%s</p>', $count, $plural);
    if ($count > 0) {
      my $base_url = sprintf('/UserData/AddFile');
      foreach (@{$result->{'items'}}) {
        my $attachment_url = $base_url.'?'.$_->{'hub'}{'url'};
        $html .= sprintf('<h3>%s<h3><h4>%s</h4>
                          <p><a href="%s">Attach this hub</a>',
                          $_->{'hub'}{'shortLabel'}, $_->{'hub'}{'longLabel'},
                          $attachment_url,
);
      }
    }
  }
  return sprintf '<input type="hidden" class="subpanel_type" value="UserData" /><h2>Search Results</h2>%s', $html;

}

1;
