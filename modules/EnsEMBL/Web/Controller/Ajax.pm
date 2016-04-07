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

package EnsEMBL::Web::Controller::Ajax;

use strict;

use HTML::Entities  qw(decode_entities);
use JSON            qw(from_json);
use URI::Escape     qw(uri_unescape);

use EnsEMBL::Web::ViewConfig::Regulation::Page;
use EnsEMBL::Web::DBSQL::WebsiteAdaptor;
use EnsEMBL::Web::File::Utils::URL;

use base qw(EnsEMBL::Web::Controller);

sub process {
  my $self  = shift;
  my $hub   = $self->hub;
  my $func  = 'ajax_'.$hub->action;

  $self->$func($hub) if $self->can($func);
}

sub ajax_autocomplete {
  my ($self, $hub) = @_;
  my $cache   = $hub->cache;
  my $species = $hub->species;
  my $query   = $hub->param('q');
  my ($key, $results);
  
  if ($cache) {
    $key     = sprintf '::AUTOCOMPLETE::GENE::%s::%s::', $hub->species, $query;
    $results = $cache->get($key);
  }
  
  if (!$results) {
    my $dbh = EnsEMBL::Web::DBSQL::WebsiteAdaptor->new($hub)->db;
    my $sth = $dbh->prepare(sprintf 'select display_label, stable_id, location, db from gene_autocomplete where species = "%s" and display_label like %s', $species, $dbh->quote("$query%"));
    
    $sth->execute;
    
    $results = { map { uc $_->[0] => { 'label' => $_->[0], 'g' => $_->[1], 'r' => $_->[2], 'db' => $_->[3] } } @{$sth->fetchall_arrayref} };
    $cache->set($key, $results, undef, 'AUTOCOMPLETE') if $cache;
  }
  
  print $self->jsonify($results);
}

sub ajax_track_order {
  my ($self, $hub)  = @_;
  my $image_config  = $hub->get_imageconfig($hub->param('image_config'));
  my $species       = $image_config->species;
  my $node          = $image_config->get_node('track_order');
  my $track_order   = $node->get($species) || [];
     $track_order   = [] unless ref $track_order eq 'ARRAY'; # ignore the old schema entry
  my $track         = $hub->param('track');
  my $prev_track    = $hub->param('prev');
  my @order         = (grep($_->[0] ne $track, @$track_order), [ $track, $prev_track || '' ]); # remove existing entry for the same track and add a new one at the end

  $node->set_user($species, \@order);
  $image_config->altered('Track order');
  $hub->session->store;
}

sub ajax_order_reset {
  my ($self, $hub)  = @_;
  my $image_config  = $hub->get_imageconfig($hub->param('image_config'));
  my $species       = $image_config->species;
  my $node          = $image_config->get_node('track_order');

  $node->set_user($species, undef);
  $image_config->altered('Track order');
  $hub->session->store;
}

sub ajax_config_reset {
  my ($self, $hub)  = @_;
  my $image_config  = $hub->get_imageconfig($hub->param('image_config'));
  my $species       = $image_config->species;
  my $node          = $image_config->tree;

  for ($node, $node->nodes) {
    my $user_data = $_->{'user_data'};

    foreach (keys %$user_data) {
      my $text = $user_data->{$_}{'name'} || $user_data->{$_}{'coption'};
      $image_config->altered($text) if $user_data->{$_}{'display'};
      delete $user_data->{$_}{'display'};
      delete $user_data->{$_} unless scalar keys %{$user_data->{$_}};
    }
  }

  $hub->session->store;
}

sub ajax_multi_species {
  my ($self, $hub) = @_;
  my %species = map { $_ => $hub->param($_) } $hub->param;
  my %args    = ( type => 'multi_species', code => 'multi_species' );
  my $session = $hub->session;
  
  if (scalar keys %species) {
    $session->set_data(%args, $hub->species => \%species);
  } else {
    my %data = %{$session->get_data(%args)};
    delete $data{$hub->species};
    
    $session->purge_data(%args);
    $session->set_data(%args, %data) if scalar grep $_ !~ /(type|code)/, keys %data;
  }
}

sub ajax_cell_type {
  my ($self,$hub) = @_;
  my $cell = $hub->param('cell');
  my $image_config_name = $hub->param('image_config') || 'regulation_view';

  my $image_config = $hub->get_imageconfig($image_config_name);

  # What changed
  my %changes;
  my %renderers = ( 'cell_on' => 'normal', 'cell_off' => 'off' );
  foreach my $key (keys %renderers) {
    my $renderer = $renderers{$key};
    foreach my $cell (split(/,/,uri_unescape($hub->param($key)))) {
      my $id = $image_config->tree->clean_id($cell);
      $changes{$image_config->tree->clean_id($cell)} = $renderer;
    }
  }

  # Which evidences have any cell-lines on at all
  my %any_on;
  foreach my $type (qw(reg_features seg_features reg_feats_core reg_feats_non_core)) {
    my $menu = $image_config->get_node($type);
    next unless $menu;
    foreach my $node (@{$menu->child_nodes}) {
      foreach my $node2 (@{$node->child_nodes}) {
        my $ev = $node2->id;
        next unless $ev =~ s/^${type}_(.*?)_//;
        my $renderer2 = $node2->get('display');
        $any_on{$ev} = 1 if $renderer2 ne 'off';
      }
    }
  }

  foreach my $type (qw(reg_features seg_features reg_feats_core reg_feats_non_core)) {
    my $menu = $image_config->get_node($type);
    next unless $menu;
    foreach my $node (@{$menu->child_nodes}) {
      my $cell = $node->id;
      unless($cell =~ s/^${type}_//) {
        $cell =~ s/^(reg_feats_|seg_)//;
      }
      next if $cell eq 'MultiCell';
      if($image_config_name ne 'regulation_view' and
          $type eq 'seg_features') {
        next;
      }
      next unless $changes{$cell};
      if($changes{$cell} ne 'off') { # Force non-partial
        foreach my $node2 (@{$node->child_nodes}) {
          my $ev = $node2->id;
          next unless $ev =~ s/^${type}_${cell}_//;
          my $renderer2 = $node2->get('display');
          next if $renderer2 ne 'off' or !$any_on{$ev};
          $image_config->update_track_renderer($node2->id,'on');
        }
      }
      $image_config->update_track_renderer($node->id,$changes{$cell});
    }
  }
  $hub->session->store;
}

sub ajax_evidence {
  my ($self,$hub) = @_;

  my %changed;
  foreach my $key (qw(evidence_on evidence_off)) {
    foreach my $ev (split(/,/,uri_unescape($hub->param($key)))) {
      $changed{$key}->{$ev} = 1;
    }
  }

  foreach my $image_config_name (qw(regulation_view reg_summary_page)) {
    my $image_config = $hub->get_imageconfig($image_config_name);
    foreach my $type (qw(reg_feats_core reg_feats_non_core)) {
      my $menu = $image_config->get_node($type);
      next unless $menu;
      foreach my $node (@{$menu->child_nodes}) {
        my $ev = $node->id;
        my $cell = $node->id;
        $cell =~ s/^${type}_//;
        foreach my $node2 (@{$node->child_nodes}) {
          my $ev = $node2->id;
          $ev =~ s/^${type}_${cell}_//;
          my $renderer;
          $renderer = 'on' if $changed{'evidence_on'}->{$ev};
          $renderer = 'off' if $changed{'evidence_off'}->{$ev};
          next unless $renderer;
          $image_config->update_track_renderer($node2->id,$renderer);
        }
      }
    }
  }
  $hub->session->store;
}

sub ajax_reg_renderer {
  my ($self,$hub) = @_;

  my $renderer = $hub->input->url_param('renderer');
  my $state = $hub->param('state');
  EnsEMBL::Web::ViewConfig::Regulation::Page->reg_renderer(
    $hub,'regulation_view',$renderer,$state);

  $hub->session->store;

  print $self->jsonify({
    reload_panels => ['FeaturesByCellLine'],
  });
}

sub ajax_nav_config {
  my ($self, $hub) = @_;
  my $session = $hub->session;
  my %args    = ( type => 'nav', code => $hub->param('code') );
  my %data    = %{$session->get_data(%args) || {}};
  my $menu    = $hub->param('menu');
  
  if ($hub->param('state')) {
    $data{$menu} = 1;
  } else {
    delete $data{$menu};
  }
  
  $session->purge_data(%args);
  $session->set_data(%args, %data) if scalar grep $_ !~ /(type|code)/, keys %data;
}

sub ajax_data_table_config {
  my ($self, $hub) = @_;
  my $session = $hub->session;
  my $sorting = $hub->param('sorting');
  my $hidden  = $hub->param('hidden_columns');
  my %args    = ( type => 'data_table', code => $hub->param('id') );
  my %data;
  
  $data{'sorting'}        = "[$sorting]" if length $sorting;
  $data{'hidden_columns'} = "[$hidden]";
  
  $session->purge_data(%args);
  $session->set_data(%args, %data) if scalar keys %data;
}

sub ajax_table_export {
  my ($self, $hub) = @_;
  my $r     = $hub->apache_handle;
  my $data  = from_json($hub->param('data'));
  my $clean = sub {
    my ($str,$opts) = @_;
    # Remove summaries, ugh.
    $str =~ s!<span class="toggle_summary[^"]*">.*?</span>!!g;
    # Remove hidden spans
    $str =~ s!<span class="hidden">[^\<]*</span>!!g;
    # split multiline columns
    for (2..$opts->{'split_newline'}) {
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
  my ($self, $hub) = @_;

  my $url     = $hub->param('url');
  my $content = {};

  if ($url) {
     $content = EnsEMBL::Web::File::Utils::URL::read_file($url, {'hub' => $hub, 'nice' => 1});
  }

  $content  = $content->{'content'} || '';
  $content  =~ s/^.*<\s*body[^\>]*>\s*|\s*<\s*\/\s*body\s*>.+$//gis; # just keep the contents of body tag
  $content  =~ s/<\s*(script|style)/<!-- /gis; # comment out script and style tags
  $content  =~ s/<\s*\/\s*(script|style)[^>]*>/ -->/gis;
  $content  =~ s/\s*((style|on[a-z]+)\s*\=\s*(\"|\'))/ x$1/gis; # disable any inline styles and JavaScript events

  print $content;
}

sub ajax_autocomplete_geneid {
  my ($self, $hub) = @_;
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

  print $self->jsonify($results);
}

1;
