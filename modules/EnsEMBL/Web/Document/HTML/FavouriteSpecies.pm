=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Document::HTML::FavouriteSpecies;

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

  my $sort_html = qq(<p>For easy access to commonly used genomes, drag from the bottom list to the top one</p>
        <p><strong>Favourites</strong></p>
          <ul class="_favourites"></ul>
        <p><strong>Other available species</strong></p>
          <ul class="_species"></ul>
        <p><a href="#Done" class="button _list_done">Done</a>
          <a href="#Reset" class="button _list_reset">Restore default list</a></p>);

  return $self->dom->create_element('div', {
    'class'       => 'static_favourite_species',
    'children'    => [{
      'node_name'   => 'h3',
      'inner_HTML'  => 'Favourite genomes'
    }, {
      'node_name'   => 'div',
      'class'       => [qw(_species_fav_container species-list faded)],
      'inner_HTML'  => $prehtml
    }, {
      'node_name'   => 'div',
      'class'       => [qw(_species_sort_container reorder_species clear hidden)],
      'inner_HTML'  => $sort_html
    }, {
      'node_name'   => 'p',
      'class'       => 'customise-species-list',
      'inner_HTML'  => sprintf('<a class="_list_edit small modal_link" href="%s">Edit favourites</a>', $hub->url({qw(type Account action Login)}))
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

    next if $done{$_} || ($species->{$_}{'strain_collection'} && $species->{$_}{'strain'} !~ /reference/i);

    $done{$_} = 1;

    my $homepage      = $hub->url({'species' => $_, 'type' => 'Info', 'function' => 'Index', '__clear' => 1});
    my $alt_assembly  = $sd->get_config($_, 'SWITCH_ASSEMBLY');

    push @list, {
      key         => $_,
      group       => $species->{$_}{'group'},
      homepage    => $homepage,
      name        => $species->{$_}{'name'},
      img         => sprintf('%sspecies/48/%s.png', $img_url, $_),
      common      => $species->{$_}{'common'},
      assembly    => $species->{$_}{'assembly'},
      assembly_v  => $species->{$_}{'assembly_version'},
      favourite   => $fav{$_} ? 1 : 0,
      strainspage => $species->{$_}{'strain_collection'} ? $hub->url({'species' => $_, 'type' => 'Info', 'function' => 'Strains', '__clear' => 1}) : 0,
      has_alt     => $alt_assembly ? 1 : 0
    };

    if ($alt_assembly) {
      push @list, {
        key         => $_,
        group       => $species->{$_}{'group'},
        homepage    => sprintf('http://%s%s', $sd->get_config($_, 'SWITCH_ARCHIVE_URL'), $homepage),
        name        => $species->{$_}{'name'},
        img         => sprintf('%sspecies/48/%s_%s.png', $img_url, $_, $alt_assembly),
        common      => $species->{$_}{'common'},
        assembly    => $alt_assembly,
        favourite   => $fav{$_} ? 1 : 0,
        external    => 1,
        has_alt     => 1,
      };
    }
  }

  return \@list;
}

sub _fav_template {
  ## @private
  return qq(<div class="species-box"><a href="{{species.homepage}}"><span class="sp-img"><img
    src="{{species.img}}" alt="{{species.name}}" title="Browse {{species.name}}" height="48"
    width="48"></span></a><a href="{{species.homepage}}"><span>{{species.common}}</span></a><span>{{species.assembly}}</span></div>);
}

sub _list_template {
  ## @private
  return qq|<li id="species-{{species.key}}">{{species.common}} (<em>{{species.name}}</em>)</li>|;
}

1;
