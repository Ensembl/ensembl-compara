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

package EnsEMBL::Web::Component::UserData::TrackHubResults;

### Display the results of the track hub registry search

use strict;
use warnings;
no warnings "uninitialized";

use POSIX qw(ceil);

use EnsEMBL::Web::REST;
use EnsEMBL::Web::Command::UserData;

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
  my $registry        = $sd->TRACKHUB_REGISTRY_URL;
  my $html;

  ## REST call
  my $rest = EnsEMBL::Web::REST->new($hub, $registry);
  return unless $rest;

  my $post_content = {};
  my @query_params = qw(assembly type query);
  foreach (@query_params) {
    $post_content->{$_} = $hub->param($_) if $hub->param($_);
  }
  ## Registry uses species names without spaces
  my $search_species = $hub->param('species') || $hub->param('search_species');
  if ($search_species) {
    (my $species = $search_species) =~ s/_/ /;
    $post_content->{'species'} = $species;
  }

  ## Filter on current assembly
  if ($post_content->{'species'} && !$post_content->{'assembly'}) {
    ## Give preference to the GCA accession id, as it is unique
    #my $assembly = $sd->get_config($hub->param('species'), 'ASSEMBLY_ACCESSION') 
    #                || $sd->get_config($hub->param('species'), 'ASSEMBLY_VERSION');
    ## FIXME: DON'T USE GCA ACCESSION, AS IT'S PATCH-SPECIFIC IN SOME SPECIES
    ## WHICH MEANS THE SEARCH MAY PRODUCE NO RESULTS 
    $post_content->{'assembly'} = $sd->get_config($hub->param('species'), 'ASSEMBLY_VERSION');
  }

  ## Pagination
  my $entries_per_page  = 5;
  my $current_page      = $hub->param('page') || 1;

  my $endpoint = 'api/search';

  my $args = {'method' => 'post', 'content' => $post_content, 
              'url_params' => {'page' => $current_page, 'entries_per_page' => $entries_per_page}};
  
  my ($result, $error) = $rest->fetch($endpoint, $args);

  if ($error) {
    $html = '<p>Sorry, we are unable to fetch data from the Track Hub Registry at the moment</p>';
  }
  else {
    my $count   = $result->{'total_entries'};
    my $plural  = $count == 1 ? '' : 's';
    my $search_url = $hub->url({
                                'type'      => 'UserData', 
                                'action'    => 'TrackHubSearch',
                                'datatype'  => $hub->param('datatype') || '',
                                'query'     => $hub->param('query') || '',
                                });
    $html .= sprintf('<p>Found %s track hub%s for this assembly - <a href="%s" class="modal_link">Search again</a></p>', $count, $plural, $search_url);
    my $registry = 

    my $link = $hub->url({'type' => 'UserData', 'action' => 'SelectFile'});
    $html .= $self->info_panel("Can't see the track hub you're interested in?", qq(<p>We only search for hubs compatible with assemblies used on this website - please <a href="$registry">search the registry directly</a> for data on other assemblies.</p><p>Alternatively, you can <a href="$link" class="modal_link">manually attach any hub</a> for which you know the URL.</p>));

    if ($count > 0) {

      my $pagination_params = {
                                'current_page'      => $current_page,
                                'total_entries'     => $count,
                                'entries_per_page'  => $entries_per_page,
                                'url_params'        => $post_content
                              };
      ## We want to pass the underscored version in the URL
      delete $pagination_params->{'url_params'}{'species'};
      $pagination_params->{'url_params'}{'search_species'} = $search_species;

      if ($count > $entries_per_page) {
        $html .= $self->_show_pagination($pagination_params);
      }

      foreach (@{$result->{'items'}}) {
        (my $species = $_->{'species'}{'scientific_name'}) =~ s/ /_/;

        ## Is this hub already attached?
        my ($ignore, $params) = EnsEMBL::Web::Command::UserData::check_attachment($self, $_->{'hub'}{'url'});
        my $button;
        if ($params->{'reattach'}) {
          my $label;
          if ($params->{'reattach'} eq 'preconfig') {
            $label = 'Hub attached by default';
          }
          else {
            $label = 'Hub already attached';
          }
          my $species       = $hub->species;
          my $location      = $hub->param('r');
          unless ($location) {
            my $sample_data = $hub->species_defs->get_config($species, 'SAMPLE_DATA');
            $location       = $sample_data->{'LOCATION_PARAM'};
          }
          my $config_url = $hub->url({'species' => $species, 
                                      'type'    => 'Location',
                                      'action'  => 'View',
                                      'r'       => $location,
                                      });
          my $anchor   = 'modal_config_viewbottom';
          if ($params->{'menu'}) {
            $anchor .= '-'.$params->{'menu'};
          }
          $button = qq(<p class="warn button float-right"><a href="$config_url#$anchor">$label</a></p>);
        }
        else {
          my $attachment_url = sprintf('/%s/UserData/AddFile?format=TRACKHUB;species=%s;text=%s;registry=1', $species, $species, $_->{'hub'}{'url'});
          $button = qq(<p class="button float-right"><a href="$attachment_url" class="modal_link">Attach this hub</a></p>);
        }

        $html .= sprintf('<div class="plain-box">
                            <h3>%s</h3>
                            %s
                            <p><b>Description</b>: %s</p>
                            <p><b>Data type</b>: %s</p>
                            <p><b>Number of tracks</b>: %s</p>
                          </div>',
                          $_->{'hub'}{'shortLabel'}, 
                          $button,
                          $_->{'hub'}{'longLabel'},
                          $_->{'type'},
                          $_->{'status'}{'tracks'}{'total'},
                        );
      }
      
      if ($count > $entries_per_page) {
        $html .= $self->_show_pagination($pagination_params);
      }

    }
  }
  return sprintf '<input type="hidden" class="subpanel_type" value="UserData" /><h2>Search Results</h2>%s', $html;

}

sub _show_pagination {
  my ($self, $args) = @_;

  my $no_of_pages = ceil($args->{'total_entries'}/$args->{'entries_per_page'});

  my $html = '<div class="list_paginate">Page: <span class="page_button_frame">';
  for (my $page = 1; $page <= $no_of_pages; $page++) {
    my ($classes, $link);
    if ($page == $args->{'current_page'}) {
      $classes = 'paginate_active';
    }
    else {
      $classes = 'paginate_button';
      $link = 1;
    }
    if ($page == 1) {
      $classes .= ' first';
    }
    elsif ($page == $no_of_pages) {
      $classes .= ' last';
    }
    if ($link) {
      $args->{'url_params'}{'page'} = $page;
      my $url = $self->hub->url($args->{'url_params'});
      $html .= sprintf '<div class="%s"><a href="%s" class="modal_link nodeco">%s</a></div>', $classes, $url, $page;
    }
    else {
      $html .= sprintf '<div class="%s">%s</div>', $classes, $page;
    }
  } 
  $html .= '</span></div><br />';

  return $html;
}

1;
