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
  my @query_params = qw(species assembly datatype query);
  foreach (@query_params) {
    $post_content->{$_} = $hub->param($_) if $hub->param($_);
  }
  ## Filter on current assembly
  if ($post_content->{'species'} && !$post_content->{'assembly'}) {
    (my $species = $post_content->{'species'}) =~ s/ /_/;
    $post_content->{'assembly'} = $sd->get_config($species, 'ASSEMBLY_VERSION');
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
      foreach (@{$result->{'items'}}) {
        (my $species = $_->{'species'}{'scientific_name'}) =~ s/ /_/;
        my $attachment_url = sprintf('/%s/UserData/AddFile?format=TRACKHUB;species=%s;text=%s', 
                                      $species, $species, $_->{'hub'}{'url'});
        $html .= sprintf('<div class="plain-box">
                            <h3>%s</h3>
                            <p class="button float-right"><a href="%s" class="modal_link">Attach this hub</a></p>
                            <p><b>Description</b>: %s</p>
                            <p><b>Data type</b>: %s</p>
                            <p><b>Number of tracks</b>: %s</p>
                          </div>',
                          $_->{'hub'}{'shortLabel'}, 
                          $attachment_url,
                          $_->{'hub'}{'longLabel'},
                          $_->{'type'},
                          $_->{'status'}{'tracks'}{'total'},
                        );
      }
    }
  }
  return sprintf '<input type="hidden" class="subpanel_type" value="UserData" /><h2>Search Results</h2>%s', $html;

}

1;
