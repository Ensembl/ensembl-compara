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

package EnsEMBL::Web::Controller::Ajax;

use strict;
use warnings;

use HTML::Entities qw(decode_entities);
use URI::Escape qw(uri_unescape);
use JSON;

use EnsEMBL::Web::Utils::DynamicLoader qw(dynamic_require);
use EnsEMBL::Web::DBSQL::GeneStableIDAdaptor;
use EnsEMBL::Web::File::Utils::URL;

use parent qw(EnsEMBL::Web::Controller);

sub parse_path_segments {
  ## @override
  my $self = shift;

  $self->{'function'} = sprintf 'ajax_%s', $self->path_segments->[0];
}

sub process {
  ## @override
  my $self  = shift;
  my $func  = $self->function;

  # call the require endpoint ajax method
  $self->$func($self->hub) if $self->can($func);

  # Save any user or session records if required
  $self->hub->store_records_if_needed;
}

sub ajax_html_doc {
  ## /Ajax/html_doc endpoint
  ## Prints content returned by render_ajax from the required Document::HTML module
  my $self    = shift;
  my $hub     = $self->hub;

  print dynamic_require(sprintf 'EnsEMBL::Web::Document::HTML::%s', $hub->param('module'))->new($hub)->render_ajax;
}

sub ajax_autocomplete {
  ## /Ajax/autocomplete endpoint
  ## Returns autocomplete JSON for gene box on nav bar
  my $self    = shift;
  my $hub     = $self->hub;
  my $cache   = $hub->cache;
  my $species = $hub->species_defs->get_config($hub->param('species') || $hub->species, 'SPECIES_PRODUCTION_NAME');
  my $query   = $hub->param('q');
  my ($key, $results);

  if ($query && $cache) {
    $key     = sprintf '::AUTOCOMPLETE::GENE::%s::%s::', $hub->species, $query;
    $results = $cache->get($key);
  }

  if ($query && !$results) {
    my $dbh = EnsEMBL::Web::DBSQL::GeneStableIDAdaptor->new($hub)->db;
    my $sth = $dbh->prepare(sprintf 'select display_label, stable_id, location, db from gene_autocomplete where species = "%s" and display_label like %s', $species, $dbh->quote("$query%"));

    $sth->execute;

    $results = { map { uc $_->[0] => { 'label' => $_->[0], 'g' => $_->[1], 'r' => $_->[2], 'db' => $_->[3] } } @{$sth->fetchall_arrayref} };
    $cache->set($key, $results, undef, 'AUTOCOMPLETE') if $cache;
  }

  print $self->jsonify($results || {});
}

sub ajax_autocomplete_geneid {
  ## /Ajax/autocomplete_geneid endpoint
  ## Returns autocomplete JSON for gene box on nav bar in case a gene id is provided
  my $self    = shift;
  my $hub     = $self->hub;
  my $gene_id = $hub->param('q');
  my @dbs     = map lc(substr $_, 9), @{$hub->species_defs->core_like_databases || []};
  my $results = {};

  foreach my $db (@dbs) {
    my $gene_adaptor = $hub->get_adaptor('get_GeneAdaptor', $db);

    if (my $gene = $gene_adaptor->fetch_by_stable_id($gene_id)) {

      $gene = $gene->transform('toplevel');

      $results = {
        uc $gene_id => {
          'label' => $gene->display_xref && $gene->display_xref->display_id || '',
          'r'     => sprintf('%s:%d-%d', $gene->seq_region_name, $gene->start, $gene->end),
          'db'    => $db,
          'g'     => $gene_id
        }
      };
      last;
    }
  }

  print to_json($results);
}

sub ajax_track_order {
  ## /Ajax/track_order endpoint
  ## Adds a new state-change to image config's track order
  my $self          = shift;
  my $hub           = $self->hub;
  my $image_config  = $hub->param('image_config');
     $image_config  = $hub->get_imageconfig($image_config) if $image_config;
  my $track         = $hub->param('track');
  my $prev_track    = $hub->param('prev');

  if ($image_config && $track && $image_config->update_track_order([$track, $prev_track])) {
    $image_config->save_user_settings;
  }
}

sub ajax_order_reset {
  ## /Ajax/order_reset endpoint
  ## Resets track order for the selected image
  my $self          = shift;
  my $hub           = $self->hub;
  my $image_config  = $hub->param('image_config');
     $image_config  = $hub->get_imageconfig($image_config) if $image_config;

  if ($image_config && $image_config->reset_user_settings('track_order')) {
    $image_config->save_user_settings;
  }
}

sub ajax_config_reset {
  ## /Ajax/config_reset endpoint
  ## Resets image config for the selected image
  my $self          = shift;
  my $hub           = $self->hub;
  my $view_config   = $hub->param('view_config');
     $view_config   = [ split '::', $view_config ] if $view_config;
     $view_config   = $hub->get_viewconfig({type => $view_config->[0], component => $view_config->[1]}) if $view_config;

  if ($view_config) {
    $view_config->reset_user_settings; # does not return positive value if only 'saved' key was present
    $view_config->save_user_settings;
  }

  my $image_config  = $hub->param('image_config');
     $image_config  = $hub->get_imageconfig($image_config) if $image_config;

  if ($image_config && $image_config->reset_user_settings) {
    $image_config->save_user_settings;
  }
}

sub ajax_multi_species {
  ## /Ajax/multi_species endpoint
  my $self          = shift;
  my $hub           = $self->hub;
  my $session_data  = $hub->session->get_record_data({'type' => 'multi_species', 'code' => 'multi_species'});
  my %species       = map { $_ => $hub->param($_) } $hub->param;

  if (keys %species) {
    $session_data->{$hub->species} = \%species;
  } else {
    delete $session_data->{$hub->species};
  }

  $session_data->{'type'} = 'multi_species';
  $session_data->{'code'} = 'multi_species';

  $hub->session->set_record_data($session_data);
}

sub ajax_cell_type {
  ## /Ajax/cell_type endpoint
  ## Turns the cell types on-off for regulation views via the cloud selector
  my $self  = shift;
  my $hub   = $self->hub;

  # What changed
  my %changes;
  my %renderers = ( 'cell_on' => 'normal', 'cell_off' => 'off' );
  foreach my $key (grep $hub->param($_), keys %renderers) {
    foreach my $cell (split(/,/,uri_unescape($hub->param($key)))) {
      $changes{$cell} = $renderers{$key};
    }
  }

  # Which evidences have any cell-lines on at all
  my $image_config_name = $hub->param('image_config') || 'regulation_view';
  my $image_config      = $hub->get_imageconfig($image_config_name);

  $image_config->update_cell_type(\%changes);
}

sub ajax_data_table_config {
  ## /Ajax/data_table_config endpoint
  ## Saves configs for changes in any data table
  my $self    = shift;
  my $hub     = $self->hub;
  my $sorting = $hub->param('sorting');
  my $hidden  = $hub->param('hidden_columns');
  my $id      = $hub->param('id');

  return unless $id;

  my $data = {'type' => 'data_table', 'code' => $id};

  $data->{'sorting'}        = "[$sorting]" if length $sorting;
  $data->{'hidden_columns'} = $hidden ? "[$hidden]" : "[]";

  $hub->session->set_record_data($data);
}

sub ajax_table_export {
  ## /Ajax/table_export endpoint
  ## Converts an HTML table into CSV by stripping out HTML tags
  my $self    = shift;
  my $hub     = $self->hub;
  my $r       = $hub->r;
  my $data    = from_json($hub->param('data'));
  my $clean   = sub {
    my ($str,$opts) = @_;
    # Remove summaries, ugh.
    $str =~ s!<span class="toggle_summary[^"]*">.*?</span>!!g;
    # Remove hidden spans
    $str =~ s!<span class="hidden">[^\<]*</span>!!g;
    # split multiline columns
    for (2..($opts->{'split_newline'} || 0)) {
      unless($str =~ s/<br.*?>/\0/) {
        $str =~ s/$/\0/;
      }
    }
    #
    $str =~ s/<br.*?>/ /g;
    $str =~ s/\xC2\xAD//g;     # Layout codepoint (shy hyphen)
    $str =~ s/\xE2\x80\x8B//g; # Layout codepoint (zero-width space)
    $str =~ s/\R//g;
    $str =~ s/^\s+//;
    $str =~ s/\s+$//g;
    $str = $self->strip_HTML(decode_entities($str));
    $str =~ s/\xA0/ /g;        # Replace non-breakable spaces
    $str =~ s/"/""/g;
    $str =~ s/\0/","/g;
    return $str;
  };

  $r->content_type('application/octet-string');
  $r->headers_out->add('Content-Disposition' => sprintf 'attachment; filename=%s.csv', $hub->param('filename'));

  my $options = from_json($hub->param('expopts')) || ();
  foreach my $row (@$data) {
    my @row_out;
    my @row_opts = @$options;
    foreach my $col (@$row) {
      my $opt = shift @row_opts;
      push @row_out,sprintf('"%s"',$clean->($col,$opt || {}));
    }
    print join(',',@row_out)."\n";
  }
}

sub ajax_fetch_html {
  ## /Ajax/table_export endpoint
  ## Fetches HTML from a remote url
  my $self    = shift;
  my $hub     = $self->hub;
  my $url     = $hub->param('url');
  my $content = $url ? EnsEMBL::Web::File::Utils::URL::read_file($url, {'proxy' => $hub->web_proxy, 'nice' => 1}) : {};
     $content = $content->{'content'} || '';
     $content =~ s/^.*<\s*body[^\>]*>\s*|\s*<\s*\/\s*body\s*>.+$//gis; # just keep the contents of body tag
     $content =~ s/<\s*(script|style)/<!-- /gis; # comment out script and style tags
     $content =~ s/<\s*\/\s*(script|style)[^>]*>/ -->/gis;
     $content =~ s/\s*((style|on[a-z]+)\s*\=\s*(\"|\'))/ x$1/gis; # disable any inline styles and JavaScript events

  print $content;
}

sub ajax_nav_config {
  ## /Ajax/nav_config
  ## Saves the state of LHS menu nodes (open or close)
  my $self    = shift;
  my $hub     = $self->hub;
  my $session = $hub->session;
  my $menu    = $hub->param('menu') or return;
  my $code    = $hub->param('code') or return;
  my $state   = $hub->param('state');
  my $args    = {'type' => 'nav', 'code' => $code};
  my $data    = $session->get_record_data($args);
     $data    = $args unless keys %$data;

  if ($hub->param('state')) {
    $data->{$menu} = 1;
  } else {
    delete $data->{$menu};
  }

  $session->set_record_data($data);
}

1;
