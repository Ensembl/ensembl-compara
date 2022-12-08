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

package EnsEMBL::Web::Component::UserData::TrackHubResults;

### Display the results of the track hub registry search

use strict;
use warnings;
no warnings "uninitialized";

use POSIX qw(ceil);

use EnsEMBL::Web::REST;
use EnsEMBL::Web::Utils::UserData qw(check_attachment);

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

  ## Pagination
  my $entries_per_page  = 5;
  my $current_page      = $hub->param('page') || 1;
  my $url_params = {'page' => $current_page, 'entries_per_page' => $entries_per_page, '_delimiter' => '&'};
  
  my ($result, $error) = $self->object->thr_search($url_params);

  if ($error) {
    $html = '<p>Sorry, we are unable to fetch data from the Track Hub Registry at the moment</p>';
  }
  else {
    my $count   = $result->{'total_entries'};
    my $plural  = $count == 1 ? '' : 's';
    my $search_url = $hub->url({
                                'type'      => 'UserData', 
                                'action'    => 'TrackHubSearch',
                                'data_type' => $hub->param('data_type') || '',
                                'query'     => $hub->param('query') || '',
                                });

    $html .= '<div class="column-wrapper">';

    ## Sidebar box with helpful hints
    my $registry = $hub->species_defs->TRACKHUB_REGISTRY_URL; 
    my $link = $hub->url({'type' => 'UserData', 'action' => 'SelectFile'});
    $html .= $self->sidebar_panel("Can't see the track hub you're interested in?", qq(<p>We only search for hubs compatible with assemblies used on this website - please <a href="$registry" rel="external">search the registry directly</a> for data on other assemblies.</p><p>Alternatively, you can <a href="$link" class="modal_link">manually attach any hub</a> for which you know the URL.</p>));

    ## Reminder of search terms
    $html .= sprintf '<p><b>Searched %s %s', $hub->param('display_name'), $hub->param('assembly_display');
    my @search_extras;
    if ($hub->param('type')) {
      push @search_extras, '"'.ucfirst($hub->param('type')).'"';
    }
    if ($hub->param('query')) {
      push @search_extras, '"'.$hub->param('query').'"';
    }
    if (@search_extras) {
      $html .= ' for '.join(' AND ', @search_extras);
    }
    $html .= '</b></p>';
    $html .= sprintf('<p>Found %s track hub%s - <a href="%s" class="modal_link">Search again</a></p>', $count, $plural, $search_url);
    $html .= '</div>';

    if ($count > 0) {

      my $pagination;
      my $pagination_params = {
                                'current_page'      => $current_page,
                                'total_entries'     => $count,
                                'entries_per_page'  => $entries_per_page,
                              };

      ## Generate the HTML once, because we delete parameters when creating it
      if ($count > $entries_per_page) {
        $pagination = $self->_pagination($pagination_params);
        $html .= $pagination;
      }

      foreach (@{$result->{'items'}}) {
        my $species       = $hub->species;
        ## Is this hub already attached?
        my ($ignore, $params) = check_attachment($hub, $_->{'hub'}{'url'});
        my $button;

        if ($_->{'status'}{'message'} eq 'Remote Data Unavailable') {
          $button = qq(<div class="float-right"><span class="button disabled-button">Currently unavailable</span></div>);
        }
        else {
          if ($params->{'reattach'}) {
            my $label;
            if ($params->{'reattach'} eq 'preconfig') {
              $label = 'Hub attached by default';
            }
            else {
              $label = 'Hub already attached';
            }
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
        $html .= $pagination;
      }

    }
  }
  return sprintf '<input type="hidden" class="subpanel_type" value="UserData" /><h2>Search Results</h2>%s', $html;

}

sub _pagination {
  my ($self, $args) = @_;

  my $no_of_pages = ceil($args->{'total_entries'}/$args->{'entries_per_page'});
  my $current_page = $args->{'current_page'};

  ## Don't show every page - some species have hundreds of trackhubs!
  my $page_limit  = 10;
  $page_limit     = $no_of_pages if $no_of_pages < $page_limit;
  my $midpoint    = $page_limit % 2 == 0 ? $page_limit / 2 : $page_limit / 2 + 0.5;
  my $half_range  = $page_limit % 2 == 0 ? $page_limit / 2 : ($page_limit - 1) / 2; 
  my $start_page  = $current_page - $half_range;
  $start_page = 1 if $start_page < 1;
  $start_page = $no_of_pages - $page_limit + 1 if ($current_page + $half_range) > $no_of_pages; 

  my $html = '<div class="list_paginate">Page: <span class="page_button_frame">';
  
  ## Set parameters that don't change 
  foreach (qw(assembly_key assembly_id assembly_display data_type thr_species display_name)) {
    $args->{'url_params'}{$_} = $self->hub->param($_);
  }

  ## Back arrows
  if ($no_of_pages > $page_limit) {
    my $text = '&lt;';
    my ($class, $content, $url);

    ## Double arrow
    if ($current_page > 1) {
      $args->{'url_params'}{'page'} = 1;
      $url = $self->hub->url($args->{'url_params'});
      $content = sprintf '<a href="%s" class="modal_link nodeco">%s%s</a>', $url, $text, $text;
    }
    else {
      $content = $text.$text;
      $class = ' paginate_button_disabled';
    }
    $html .= sprintf '<div class="paginate_button%s">%s</div>', $class, $content;

    ## Single arrow
    if ($current_page > $midpoint) {
      $args->{'url_params'}{'page'} = $current_page - 1;
      $url = $self->hub->url($args->{'url_params'});
      $content = sprintf '<a href="%s" class="modal_link nodeco">%s</a>', $url, $text;
    }
    else {
      $content = $text;
      $class = ' paginate_button_disabled';
    }
    $html .= sprintf '<div class="paginate_button%s">%s</div>', $class, $content;
  }

  for (my $page = $start_page; $page < ($start_page + $page_limit); $page++) {
    my ($classes, $link);

    if ($page == $current_page) {
      $classes = 'paginate_active';
    }
    else {
      $classes = 'paginate_button';
      $link = 1;
    }
    if ($page == $start_page) {
      $classes .= ' first';
    }
    elsif ($page == $page_limit) {
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

  ## Forward arrow
  if ($no_of_pages > $page_limit) {
    my $text = '&gt;';
    my ($class, $content, $url);

    ## Single arrow
    if ($current_page < ($no_of_pages - $half_range)) {
      $args->{'url_params'}{'page'} = $current_page + 1;
      $url = $self->hub->url($args->{'url_params'});
      $content = sprintf '<a href="%s" class="modal_link nodeco">%s</a>', $url, $text;
    }
    else {
      $content = $text;
      $class = ' paginate_button_disabled';
    }
    $html .= sprintf '<div class="paginate_button%s">%s</div>', $class, $content;

    ## Double arrow
    if ($current_page < $no_of_pages) {
      $args->{'url_params'}{'page'} = $no_of_pages;
      $url = $self->hub->url($args->{'url_params'});
      $content = sprintf '<a href="%s" class="modal_link nodeco">%s%s</a>', $url, $text, $text;
    }
    else {
      $content = $text.$text;
      $class = ' paginate_button_disabled';
    }
    $html .= sprintf '<div class="paginate_button%s">%s</div>', $class, $content;

  }

  $html .= '</span></div><br />';

  return $html;
}

1;
