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

  ## Needed for autocomplete
  my $strains = [];
  foreach my $sp (@$species) {
    if ($sp->{'strainspage'}) {
      push @$strains, {
                      'homepage'  => $sp->{'strainspage'},
                      'name'      => $sp->{'name'},
                      'common'    => (sprintf '%s %s', $sp->{'common'}, $sp->{'strain_type'}),
                      };
    }
  }

  my @ok_species = $sd->valid_species;
  my $sitename  = $self->hub->species_defs->ENSEMBL_SITETYPE;
  my $fave_text = $self->hub->species_defs->FAVOURITES_SYNONYM || 'Favourite';

  if (scalar @ok_species > 1) {
    my $list_html = $self->get_list_html();
    my $fave_plural = $self->hub->species_defs->FAVOURITES_SYNONYM || 'Favourites';

    my $sort_html = qq(<p>For easy access to commonly used genomes, drag from the bottom list to the top one</p>
        <p><strong>$fave_plural</strong></p>
          <ul class="_favourites"></ul>
        <p><a href="#Done" class="button _list_done">Done</a>
          <a href="#Reset" class="button _list_reset">Restore default list</a></p>
        <p><strong>Other available species</strong></p>
          <ul class="_species"></ul>
          );

    my $edit_icon = $self->get_edit_icon_markup();

  
    my %taxon_labels = $sd->multiX('TAXON_LABEL'); 
    unless (keys %taxon_labels) {
      %taxon_labels = %{$sd->TAXON_LABEL||{}};
    }

    return $self->dom->create_element('div', {
      'class'       => 'column_wrapper',
      'children'    => [{
              'node_name'   => 'div',
              'class'       => 'column-two static_all_species',
              'inner_HTML'  => $list_html,
            }, {
              'node_name'   => 'div',
              'class'       => 'column-two fave-genomes',
              'children'    => [{
                        'node_name'   => 'h3',
                        'inner_HTML'  => "$fave_text genomes $edit_icon",
                      }, {
                        'node_name'   => 'div',
                        'class'       => [qw(_species_sort_container reorder_species clear hidden)],
                        'inner_HTML'  => $sort_html
                      }, {
                        'node_name'   => 'div',
                        'class'       => [qw(_species_fav_container species-list)],
                        'inner_HTML'  => $prehtml
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
                        'class'       => 'js_param json',
                        'name'        => 'strains_list',
                        'value'       => encode_entities(to_json($strains))
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
                        'class'       => 'js_param',
                        'name'        => 'fave_text',
                        'value'       => $fave_text
                      }, {
                        'node_name'   => 'inputhidden',
                        'class'       => 'js_param json',
                        'name'        => 'taxon_labels',
                        'value'       => encode_entities(to_json(\%taxon_labels))
                      }, {
                        'node_name'   => 'inputhidden',
                        'class'       => 'js_param json',
                        'name'        => 'taxon_order',
                        'value'       => encode_entities(to_json($sd->TAXON_ORDER))
                      }]
          }]
    });
  }
  else {
    my $species       = $ok_species[0];
    my $info          = $hub->get_species_info($species);
    my $homepage      = $hub->url({'species' => $species, 'type' => 'Info', 'function' => 'Index', '__clear' => 1});
    my $img_url       = $sd->img_url || '';
    my $sp_info = {
      homepage    => $homepage,
      name        => $info->{'name'},
      img         => sprintf('%sspecies/%s.png', $img_url, $info->{'image'}),
      common      => $info->{'common'},
      assembly    => $info->{'assembly'},
    };
    my $species_html = $template =~ s/\{\{species\.(\w+)}\}/my $replacement = $sp_info->{$1};/gre;
    return $self->dom->create_element('div', {
      'class'       => 'column_wrapper',
      'children'    => [{
                        'node_name'   => 'div',
                        'class'       => 'column-two fave-genomes',
                        'children'    => [{
                                          'node_name'   => 'h3',
                                          'inner_HTML'  => 'Available genomes'
                                          }, {
                                          'node_name'   => 'div',
                                          'inner_HTML'  => $species_html
                                        }]
                        }]
    });
  }
}


sub get_edit_icon_markup {

  my ($self) = @_;
  my $hub     = $self->hub;

  return sprintf qq(<a href="%s" class="_list_edit modal_link"><img src="/i/16/pencil.png" class="left-half-margin" title="Edit your favourites"></a>), $hub->url({qw(type Account action Login)});

}


sub get_list_html {

  my ($self) = @_;
  
  sprintf qq(<h3>All genomes</h3>
      %s
      <h3 class="space-above"></h3>
      %s
      <p><a href="%s">View full list of all species</a></p>
      ), 
      $self->add_species_dropdown,
      $self->add_genome_groups, 
      $self->species_list_url; 

}

sub add_species_selector {
  my $self = shift;
  my $finder_prompt = 'Start typing the name of a species...';

  my $html = qq(
    <div class="taxon_tree_master hidden"></div>
    <div class="species_select_container">
      <div class="species_homepage_selector">
        <div class="content">
          <div class="finder">
            <input type="text" autofocus class="ui-autocomplete-input inactive" title="$finder_prompt" placeholder="$finder_prompt" />
          </div>
        </div>
      </div>
    </div>
  );
  return $html;
}

sub add_genome_groups {
  my $self = shift;
  
  my $html = '';
  my @featured = $self->get_featured_genomes; 

  foreach my $item (@featured) {
    $html .= sprintf qq(
<div class="species-box-outer">
  <div class="species-box">
    <a href="%s"><img src="/i/species/%s" alt="%s" title="Browse %s" class="badge-48"/></a>
    ), $item->{'url'}, $item->{'img'}, $item->{'name'}, $item->{'name'};

    if ($item->{'link_title'}) {
      $html .= sprintf '<a href="%s" class="species-name">%s</a>', $item->{'url'}, $item->{'name'};
    }
    else {
      $html .= sprintf '<span class="species-name">%s</span>', $item->{'name'};
    }

    if ($item->{'more'}) {
      $html .= sprintf '<div class="assembly">%s</div>', $item->{'more'};
    }

    $html .= qq(
  </div>
</div>
    );
  } 

  return $html;
}

sub get_featured_genomes {
  return (
           {
            'url'   => 'Sus_scrofa/Info/Strains/',
            'img'   => 'Sus_scrofa.png',
            'name'  => 'Pig breeds',
            'more'  => qq(<a href="/Sus_scrofa/" class="nodeco">Pig reference genome</a> and <a href="Sus_scrofa/Info/Strains/" class="nodeco">12 additional breeds</a>),
           },
          );
}


sub add_species_dropdown { '<p><select class="fselect _all_species"><option value="">-- Select a species --</option></select></p>' }

sub species_list_url { return '/info/about/species.html'; }

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

  for (@fav, sort {$species->{$a}{'display_name'} cmp $species->{$b}{'display_name'}} keys %$species) {

    next if ($done{$_} || !$species->{$_} || !$species->{$_}{'is_reference'});

    $done{$_} = 1;

    my $homepage      = $hub->url({'species' => $_, 'type' => 'Info', 'function' => 'Index', '__clear' => 1});
    my $alt_assembly  = $sd->get_config($_, 'SWITCH_ASSEMBLY');
    my $strainspage   = '';
    my $strain_type   = '';
    if ($species->{$_}{'strain_group'}) {
      $strainspage = $hub->url({'species' => $_, 'type' => 'Info', 'function' => 'Strains', '__clear' => 1});
      $strain_type = $sd->get_config($_, 'STRAIN_TYPE'); 
      if ($strain_type =~ /(y)$/) {
        $strain_type =~ s/$1/ies/;
      }
      else {
        $strain_type .= 's';
      }   
    }

    my $extra = $_ eq 'Homo_sapiens' ? '<a href="/info/website/tutorials/grch37.html" class="species-extra">Still using GRCh37?</a>' : '';

    ## This data is a bit repetitive because it has to be easy for the JavaScript to process
    push @list, {
      key         => $_,
      group       => $species->{$_}{'group'},
      homepage    => $homepage,
      name        => $species->{$_}{'name'},
      img         => sprintf('%sspecies/%s.png', $img_url, $species->{$_}{'image'}),
      common      => $species->{$_}{'display_name'},
      assembly    => $species->{$_}{'assembly'},
      assembly_v  => $species->{$_}{'assembly_version'},
      favourite   => $fav{$_} ? 1 : 0,
      strainspage => $strainspage,
      straintitle => $sd->USE_COMMON_NAMES ? $species->{$_}{'display_name'} : $species->{$_}{'scientific'},
      strain_type => $strain_type,
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
