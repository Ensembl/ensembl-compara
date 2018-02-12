=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Document::HTML::GenomeList;

use strict;
use warnings;

use JSON;
use HTML::Entities qw(encode_entities);

use parent qw(EnsEMBL::Web::Document::HTML);

use constant SPECIES_DISPLAY_LIMIT => 6;

sub render {
  ## Since this component is displayed on home page, it gets cached by memcached - make sure nothing user specific is returned in this method
  return shift->_get_dom_tree->render;
}

sub render_ajax {
  ## This gets called by ajax and returns user favourite species only
  my $self      = shift;
  my $hub       = $self->hub;

  return to_json($self->_species_list);
}

sub _get_dom_tree {
  ## @private
  my $self      = shift;
  my $hub       = $self->hub;
  my $sd        = $hub->species_defs;
  my $species   = $self->_species_list({'no_user' => 1});
  my $template  = $self->_fav_template;
  my $prehtml   = '';

  for (0..$self->SPECIES_DISPLAY_LIMIT-1) {
    $prehtml .= $template =~ s/\{\{species\.(\w+)}\}/my $replacement = $species->[$_]{$1};/gre if $species->[$_] && $species->[$_]->{'favourite'};
  }

  my $sitename  = $self->hub->species_defs->ENSEMBL_SITETYPE;
  my $list_html = sprintf qq(<h3>All genomes</h3>
    <p><select class="_all_species"><option value="">-- Select a species --</option></select></p>
    <ul class="space-above">
      <li><a href="/info/about/species.html">View full list of all %s species</a></li>
      <li class="customise-species-list"><a class="_list_edit modal_link" href="%s">Edit your favourites</a></li>
    </ul>
    ), 
    $sitename, $hub->url({qw(type Account action Login)});

  my $sort_html = qq(<p>For easy access to commonly used genomes, drag from the bottom list to the top one</p>
        <p><strong>Favourites</strong></p>
          <ul class="_favourites"></ul>
        <p><strong>Other available species</strong></p>
          <ul class="_species"></ul>
        <p><a href="#Done" class="button _list_done">Done</a>
          <a href="#Reset" class="button _list_reset">Restore default list</a></p>);

  return $self->dom->create_element('div', {
    'class'       => 'column_wrapper',
    'children'    => [{
              'node_name'   => 'div',
              'class'       => 'column-forty static_all_species',
              'inner_HTML'  => $list_html,
            }, {
              'node_name'   => 'div',
              'class'       => 'column-sixty fave-genomes',
              'children'    => [{
                        'node_name'   => 'h3',
                        'inner_HTML'  => 'Favourite genomes'
                      }, {
                        'node_name'   => 'div',
                        'class'       => [qw(_species_fav_container species-list)],
                        'inner_HTML'  => $prehtml
                      }, {
                        'node_name'   => 'div',
                        'class'       => [qw(_species_sort_container reorder_species clear hidden)],
                        'inner_HTML'  => $sort_html
                      }, {
                        'node_name'   => 'inputhidden',
                        'class'       => 'js_param',
                        'name'        => 'fav_template',
                        'value'       => encode_entities($template)
                      }, {
                        'node_name'   => 'inputhidden',
                        'class'       => 'js_param',
                        'name'        => 'list_template',
                        'value'       => encode_entities($self->_list_template)
                      }, {
                        'node_name'   => 'inputhidden',
                        'class'       => 'js_param json',
                        'name'        => 'species_list',
                        'value'       => encode_entities(to_json($species))
                      }, {
                        'node_name'   => 'inputhidden',
                        'class'       => 'js_param',
                        'name'        => 'ajax_refresh_url',
                        'value'       => encode_entities($self->ajax_url)
                      }, {
                        'node_name'   => 'inputhidden',
                        'class'       => 'js_param',
                        'name'        => 'ajax_save_url',
                        'value'       => encode_entities($hub->url({qw(type Account action Favourites function Save)}))
                      }, {
                        'node_name'   => 'inputhidden',
                        'class'       => 'js_param',
                        'name'        => 'display_limit',
                        'value'       => SPECIES_DISPLAY_LIMIT
                      }, {
                        'node_name'   => 'inputhidden',
                        'class'       => 'js_param json',
                        'name'        => 'taxon_labels',
                        'value'       => encode_entities(to_json($sd->TAXON_LABEL||{}))
                      }, {
                        'node_name'   => 'inputhidden',
                        'class'       => 'js_param json',
                        'name'        => 'taxon_order',
                        'value'       => encode_entities(to_json($sd->TAXON_ORDER))
                      }]
          }]
    });
}

sub _species_list {
  ## @private
  my ($self, $params) = @_;

  $params   ||= {};
  my $hub     = $self->hub;
  my $sd      = $hub->species_defs;
  my $species = $hub->get_species_info;
  my $user    = $params->{'no_user'} ? undef : $hub->users_plugin_available && $hub->user;
  my $img_url = $sd->img_url || '';
  my @fav     = @{$hub->get_favourite_species(!$user)};
  my %fav     = map { $_ => 1 } @fav;

  my (@list, %done);

  for (@fav, sort {$species->{$a}{'common'} cmp $species->{$b}{'common'}} keys %$species) {

    next if ($done{$_} || !$species->{$_} || !$species->{$_}{'is_reference'});

    $done{$_} = 1;

    my $homepage      = $hub->url({'species' => $_, 'type' => 'Info', 'function' => 'Index', '__clear' => 1});
    my $alt_assembly  = $sd->get_config($_, 'SWITCH_ASSEMBLY');
    my $strainspage   = $species->{$_}{'has_strains'} ? $hub->url({'species' => $_, 'type' => 'Info', 'function' => 'Strains', '__clear' => 1}) : 0;

    my $extra = $_ eq 'Homo_sapiens' ? '<a href="/info/website/tutorials/grch37.html" class="species-extra">Still using GRCh37?</a>' : '';

    push @list, {
      key         => $_,
      group       => $species->{$_}{'group'},
      homepage    => $homepage,
      name        => $species->{$_}{'name'},
      img         => sprintf('%sspecies/%s.png', $img_url, $_),
      common      => $species->{$_}{'common'},
      assembly    => $species->{$_}{'assembly'},
      assembly_v  => $species->{$_}{'assembly_version'},
      favourite   => $fav{$_} ? 1 : 0,
      strainspage => $strainspage,
      has_alt     => $alt_assembly ? 1 : 0,
      extra       => $extra,
    };

  }

  return \@list;
}

sub _fav_template {
  ## @private
  return qq(
<div class="species-box-outer">
  <div class="species-box">
    <a href="{{species.homepage}}"><img src="{{species.img}}" alt="{{species.name}}" title="Browse {{species.name}}" class="badge-48"/></a>
    <a href="{{species.homepage}}" class="species-name">{{species.common}}</a>
    <div class="assembly">{{species.assembly}}</div>
  </div>
  {{species.extra}}
</div>);
}

sub _list_template {
  ## @private
  return qq|<li id="species-{{species.key}}">{{species.common}} (<em>{{species.name}}</em>)</li>|;
}

1;
