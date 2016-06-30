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

package EnsEMBL::Web::Form::ViewConfigForm;

use strict;
use warnings;

use HTML::Entities qw(encode_entities);


use parent qw(EnsEMBL::Web::Form);

sub new {
  ## @override
  ## @param ViewConfig object
  ## @param Form id attribute
  ## @param Form action attribute
  my ($class, $view_config, $id, $action) = @_;

  my $self = $class->SUPER::new({
    'id'      => $id,
    'action'  => $action,
    'class'   => 'configuration std'
  });

  $self->{'_view_config'} = $view_config;

  return $self;
}

sub view_config {
  return shift->{'_view_config'};
}

sub add_fieldset {
  my ($self, $legend, $class, $no_tree) = @_;

  (my $div_class = $legend) =~ s/ /_/g;
  my $fieldset   = $self->SUPER::add_fieldset($legend);

  $fieldset->set_attribute('class', $class) if $class;

  unless ($no_tree) {
    my $tree = $self->view_config->tree;
    $tree->append($tree->create_node(lc $div_class, { url => '#', availability => 1, caption => $legend, class => $div_class }));
  }

  return $fieldset;
}

sub get_fieldset {
  my ($self, $i) = @_;

  my $fieldsets = $self->fieldsets;
  my $fieldset;

  if (int $i eq $i) {
    $fieldset = $fieldsets->[$i];
  } else {
    ($fieldset) = grep { $_->get_legend && $_->get_legend->inner_HTML eq $i } @$fieldsets;
  }

  return $fieldset;
}

sub add_form_element {
  my ($self, $element) = @_;

  my $view_config = $self->view_config;

  if ($element->{'type'} =~ /checkbox/i) {
    ## Allow defaults to be set to 'off', even though the checkbox value attribute
    ## needs to be set to 'on' - otherwise we get weird reverse-logic checkboxes!
    if ($element->{'value'} eq 'off') {
      $element->{'value'} = 'on';
    }
    my $value = $view_config->get($element->{'name'});
    $element->{'selected'} = ( $value eq 'off' || $value eq 'no') ? 0 : 1;
  } elsif (!exists $element->{'value'}) {
    if ($element->{'multiple'}) {
      my @value = $view_config->get($element->{'name'});
      $element->{'value'} = \@value;
    } else {
      $element->{'value'} = $view_config->get($element->{'name'});
    }
  }

  $self->add_fieldset('Display options') unless $self->has_fieldset;
  $self->add_element(%$element);

  if (!$view_config->get_label($element->{'name'})) {
    $view_config->set_label($element->{'name'}, $element->{'label'});
  }

  if (!$view_config->get_label($element->{'name'}) && $element->{'values'}) {
    $view_config->set_value_label($element->{'name'}, { map { $_->{'value'} => $_->{'caption'} } @{$element->{'values'}} });
  }
}

sub build {
  my ($self, $object, $image_config) = @_;

  my $view_config = $self->view_config;
  my $hub         = $view_config->hub;

  $self->build_imageconfig_form($image_config) if $image_config;

  $view_config->init_form($object);

  if ($image_config && $image_config->orientation eq 'horizontal') {
    my $fieldset = $self->get_fieldset('Display options') || $self->add_fieldset('Display options');

    $fieldset->add_field({
      type   => 'DropDown',
      name   => 'image_width',
      value  => $hub->get_cookie_value('DYNAMIC_WIDTH') ? 'bestfit' : $hub->image_width,
      label  => 'Width of image',
      values => [
        { value => 'bestfit', caption => 'best fit' },
        map {{ value => $_, caption => "$_ pixels" }} map $_*100, 5..20
      ]
    });
  }

  foreach my $fieldset (@{$self->fieldsets}) {
    next if $fieldset->get_flag('_has_select_all');

    my %element_types;
    my $elements = $fieldset->inputs; # returns all input, select and textarea nodes

    $element_types{$_->node_name . $_->get_attribute('type')}++ for @$elements;

    delete $element_types{$_} for qw(inputhidden inputsubmit);

    # If the fieldset is mostly checkboxes, provide a select/deselect all option
    if ($element_types{'inputcheckbox'} > 1 && [ sort { $element_types{$b} <=> $element_types{$a} } keys %element_types ]->[0] eq 'inputcheckbox') {
      my $reference_element = undef;

      foreach (@$elements) {
        $reference_element = $_;
        last if $_->get_attribute('type') eq 'checkbox';
      }

      $reference_element = $reference_element->parent_node while defined $reference_element && ref($reference_element) !~ /::Form::Field$/; # get the wrapper of the element before using it as reference

      next unless defined $reference_element;

      my $select_all = $fieldset->add_field({
        type        => 'checkbox',
        name        => 'select_all',
        label       => 'Select/deselect all',
        value       => 'select_all',
        field_class => 'select_all',
        selected    => 1
      });

      $reference_element->before($select_all);
      $fieldset->set_flag('_has_select_all'); # Add select all checkboxes
    }
  }

  foreach (@{$self->fieldsets}) {
    my $wrapper_div = $self->dom->create_element('div');
    my $legend      = $_->get_legend;

    if ($legend) {
      (my $div_class = $legend->inner_HTML) =~ s/ /_/g;
      $wrapper_div->set_attribute('class', "config $div_class view_config");
    }

    if ($_->get_attribute('class') eq 'empty') {
      $_->parent_node->replace_child($wrapper_div, $_);
    } else {
      $wrapper_div->append_child($_->parent_node->replace_child($wrapper_div, $_));
    }
  }

  if ($image_config) {
    my $extra_menus = $image_config->{'_extra_menus'}; # TODO - dont access private variable
    my $tree        = $view_config->tree;
    $_->remove for map $extra_menus->{$_} == 0 ? $tree->get_node($_) || () : (), keys %$extra_menus;
  }
}

sub build_imageconfig_form {
  my $self          = shift;
  my $image_config  = shift;
  my $view_config   = $self->view_config;
  my $img_url       = $view_config->species_defs->img_url;
  my $extra_menus   = $image_config->{'_extra_menus'};
  my $tree          = $view_config->tree;
  my %node_options  = ( availability => 1, url => '#', rel => 'multi' );
  my $track_order;

  $tree->append($tree->create_node('active_tracks',    { caption => 'Active tracks',    class => 'active_tracks',    %node_options })) if $extra_menus->{'active_tracks'};
  $tree->append($tree->create_node('favourite_tracks', { caption => 'Favourite tracks', class => 'favourite_tracks', %node_options })) if $extra_menus->{'favourite_tracks'};

  if ($extra_menus->{'track_order'}) {
    $tree->append($tree->create_node('track_order', { caption => 'Track order', class => 'track_order', %node_options, rel => undef }));
    $self->{'json'}{'order'} = { map { join('.', grep $_, $_->id, $_->data->{'drawing_strand'}) => $_->data->{'order'} } $image_config->get_parameter('sortable_tracks') ? $image_config->get_sortable_tracks : () };
  }

  $tree->append($tree->create_node('search_results', { caption => 'Search results', class => 'search_results disabled', %node_options })) if $extra_menus->{'search_results'};

  # Delete all tracks where menu = no, and parent nodes if they are now empty
  # Do this after creating track order, so that unconfigurable but displayed tracks are still considered in the ordering process
  $image_config->remove_disabled_menus;

  # In the scenario where the tree structure is menu -> sub menu -> sub menu, and the 3rd level contains only one non-external menu,
  # move all the tracks in that 3rd level menu up to the 2nd level, and delete the 3rd level.
  # This avoids a bug where the 2nd level menu has an h3 header, and no enable/disable all, and the enable/disable all for the 3rd level is printed in the wrong place.
  # An example of this would be in a species with one type of variation set subset
  foreach my $node (grep $_->data->{'node_type'} eq 'menu', $image_config->tree->nodes) {
    my @child_menus = grep $_->data->{'node_type'} eq 'menu', @{$node->child_nodes};

    if (scalar @child_menus == 1 && scalar @{$node->child_nodes} == 1 && scalar(grep !$_->data->{'external'}, @child_menus) == 1) {
      $child_menus[0]->before($_) for @{$child_menus[0]->child_nodes};
      $child_menus[0]->remove;
    }
  }

  $self->{'favourite_tracks'} = $image_config->get_favourite_tracks;

  foreach my $node (@{$image_config->tree->child_nodes}) {
    my $section = $node->id;

    $section =~ s|-|_|g;
    next if $section eq 'track_order';

    my $data    = $node->data;
    my $caption = $data->{'caption'};
    my $class   = $data->{'trackhub_menu'} || $section eq 'user_data' ? 'move_to_top' : ''; # add a class to user data and data hubs to get javascript to move them to the top of the navigation
    my $div     = $self->append_child('div', { class => "config $section $class" });

    $div->append_child('h2', { class => 'config_header', inner_HTML => $caption});

    if($data->{'description'}){
      $div->append_child('div', { class => 'long_label',   inner_HTML => $data->{'description'} });
    }

    my $parent_menu = $tree->append($tree->create_node($section, {
      caption  => $caption,
      class    => $section,
      li_class => $class,
      url      => '#',
    }));

    if ($node->has_child_nodes) {
      my @child_nodes = @{$node->child_nodes};

      # If all children are menus
      if (scalar @child_nodes && !grep $_->data->{'node_type'} ne 'menu', @child_nodes) {
        my $first = 'first ';

        foreach (@child_nodes) {
          my $id = $_->id;

          $self->build_imageconfig_menus($_, $div->append_child('div', { class => "subset $first$id" }), $section, $id);

          $first = '';

          next if scalar @child_nodes == 1 && !$data->{'trackhub_menu'};

          my $url = $_->data->{'url'};
          my ($total, $on);

          my @child_ids = map $_->id, grep { $_->data->{'node_type'} eq 'track' && $_->data->{'menu'} ne 'hidden' && $_->data->{'matrix'} ne 'column' } $_->nodes;
             $total     = scalar @child_ids;
             $on        = 0;
             $on       += $self->{'enabled_tracks'}{$_} for @child_ids;

          # Add submenu entries to the navigation tree
          $parent_menu->append($tree->get_node($id) || $tree->create_node($id, {
            caption      => $_->data->{'caption'},
            class        => $url ? $id : $parent_menu->id . "-$id",
            url          => $url || '#',
            count        => $total ? qq{(<span class="on">$on</span>/$total)} : '',
            availability => $url ? 1 : $total > 0,
          }));

          $self->add_fieldset($id, 'empty', 1) if $url;
        }
      } else {
        my $parent = $div->append_child('div', { class => 'subset' . (scalar @child_nodes > 1 ? ' first' : '') })->append_child('ul', { class => "config_menu $section" }); # Add a subset div to keep the HTML consistent

        $self->build_imageconfig_menus($_, $parent, $section) for @child_nodes;
        $self->add_select_all($node, $parent, $section);
      }
    }

    my $on    = $self->{'enabled_tracks'}{$section} || 0;
    my $total = $self->{'total_tracks'}{$section}   || 0;

    $parent_menu->set('count', qq{(<span class="on">$on</span>/$total)}) if $total;
    $parent_menu->set('availability', $total > 0);
  }

  # When creating HTML for the form, we want only the tracks which are turned on, and their parent nodes - remove all other track nodes before rendering.
  # Also remove any empty UL tags. These can occur when a menu which is not explicitly external contains only external tracks.
  $_->remove for grep { ($_->node_name eq 'li' && !$_->get_flag('display')) || ($_->node_name eq 'ul' && !$_->has_child_nodes) } @{$self->get_all_nodes};

  if ($extra_menus->{'favourite_tracks'}) {
    $self->prepend_child('h1', { class => 'favourite_tracks',        inner_HTML => 'Favourite tracks' });
    $self->append_child('div', { class => 'config favourite_tracks', inner_HTML => qq(You have no favourite tracks. Use the <img src="${img_url}grey_star.png" alt="star" /> icon to add tracks to your favourites) });
  }

  $self->append_child('div', { class => 'config track_order', inner_HTML => '<h1 class="track_order">Track order</h1><ul class="config_menu"></ul>' }) if $self->{'json'}{'order'};
  $self->append_child('div', { class => 'config no_search',   inner_HTML => 'Sorry, your search did not find any tracks' });
  $self->prepend_child('h1', { class => 'search_results',     inner_HTML => 'Search results' });
  $self->prepend_child('h1', { class => 'active_tracks',      inner_HTML => 'Active tracks'  });

  return $self;
}

sub build_imageconfig_menus {
  my ($self, $node, $parent, $menu_class, $submenu_class) = @_;
  my $data      = $node->data;
  my $menu_type = $data->{'menu'};
  my $id        = $node->id;

  if ($menu_type eq 'matrix_subtrack') {
    my $display = $node->get('display');

    if ($node->get_node($data->{'option_key'}) &&
      $node->get_node($data->{'option_key'})->get('display') eq 'on' &&                           # The cell option is turned on AND
      $display ne 'off' &&                                                                        # The track is not turned off AND
      !($display eq 'default' && $node->get_node($data->{'column_key'})->get('display') eq 'off') # The track renderer is not default while the column renderer is off
    ) {
      $self->{'enabled_tracks'}{$menu_class}++;
      $self->{'enabled_tracks'}{$id} = 1;

      $self->{'json'}{'subTracks'}{$data->{'column_key'}}++ if $display eq 'default'; # use an array of tracks rather than a hash so that gzip can compress the json mmore effectively.
    } else {
      $self->{'json'}{'subTracks'}{$data->{'column_key'}} ||= 0; # Force subTracks entries to exist
    }

    $self->{'total_tracks'}{$menu_class}++;

    return;
  }

  return if $menu_type eq 'no';

  my $external = $data->{'external'};

  if ($data->{'node_type'} eq 'menu') {
    my $caption = $data->{'caption'};
    my $element;

    if ($parent->node_name eq 'ul') {
      if ($external) {
        $parent = $parent->parent_node;                                # Move external tracks to a separate ul, after other tracks
      } else {
        $parent = $parent->append_child('li', { flags => 'display' }); # Children within a subset (eg variation sets)
      }
    }

    # If the children are all non external menus, add another wrapping div so there can be distinct groups in a submenu, with unlinked enable/disable all controls
    if (!scalar(grep $_->data->{'node_type'} ne 'menu', @{$node->child_nodes}) && scalar(grep !$_->data->{'external'}, @{$node->child_nodes})) {
      $element = $parent->append_child('div', { class => $menu_type eq 'hidden' ? ' hidden' : '' });
    } else {
      $element = $parent->append_child('ul', { class => "config_menu $menu_class" . ($menu_type eq 'hidden' ? ' hidden' : '') });
    }

    $self->build_imageconfig_menus($_, $element, $menu_class, $submenu_class) for @{$node->child_nodes};
    $self->add_select_all($node, $element, $id) if $element->node_name eq 'ul';
  } else {
    my $img_url     = $self->img_url;
    my @states      = @{$data->{'renderers'} || [ 'off', 'Off', 'normal', 'On' ]};
    my %valid       = @states;
    my $display     = $node->get('display') || 'off';
       $display     = $valid{'normal'} ? 'normal' : $states[2] unless $valid{$display};
    my $controls    = $data->{'controls'};
    my $subset      = $data->{'subset'};
    my $name        = encode_entities($data->{'name'});
    my @classes     = ('track', $external ? 'external' : '', lc $external);
    my $menu_header = scalar @states > 4 ? qq(<li class="header">Change track style<img class="close" src="${img_url}close.png" title="Close" alt="Close" /></li>) : '';
    my ($selected, $menu, $help);

    while (my ($renderer, $label) = splice @states, 0, 2) {
      $label = encode_entities($label);
      $menu .= qq{<li class="$renderer">$label</li>};

      push @classes, $renderer if $renderer eq $display;

      my $p = $node;

      while ($p = $p->parent_node) {
        $self->{'track_renderers'}{$p->id}{$renderer}++;
        last if $external;
      }
    }

    $menu .= qq{<li class="setting subset subset_$subset"><a href="#">Configure track options</a></li>} if $subset;

    if ($data->{'matrix'} ne 'column') {
      if ($display ne 'off') {
        $self->{'enabled_tracks'}{$menu_class}++;
        $self->{'enabled_tracks'}{$id} = 1;
      }

      $self->{'total_tracks'}{$menu_class}++;
    }

    my $desc      = '';
    my $desc_url  = $data->{'desc_url'} ? $self->hub->url('Ajax', {'type' => 'fetch_html', 'url' => $data->{'desc_url'}}) : '';

    if ($data->{'subtrack_list'}) { # it's a composite track
      $desc .= '<h1>Track list</h1>';
      $desc .= sprintf '<ul>%s</ul>', join '', map $_->[1], sort { $a->[0] cmp $b->[0] } map [ lc $_->[0], $_->[1] ? "<li><p><b>$_->[0]</b></p><p>$_->[1]</p></li>" : "<li>$_->[0]</li>" ], @{$data->{'subtrack_list'}};
      $desc .= "<h1>Trackhub description: $data->{'description'}</h1>" if $data->{'description'} && $desc_url;
      $desc .= qq(<div class="_dyna_load"><a class="hidden" href="$desc_url">No description found for this composite track.</a>Loading&#133;</div>) if $desc_url;
    } else {
      $desc .= $desc_url ? sprintf(q(<div class="_dyna_load"><a class="hidden" href="%s">%s</a>Loading&#133;</div>), $desc_url, encode_entities($data->{'description'})) : $data->{'description'};
    }

    if ($desc) {
      $desc = qq{<div class="desc">$desc</div>};
      $help = qq{<div class="sprite info_icon menu_help _ht" title="Click for more information"></div>};
    } else {
      $help = qq{<div class="empty info_icon sprite"></div>};
    }

    push @classes, 'on'             if $display ne 'off';
    push @classes, 'fav'            if $self->{'favourite_tracks'}{$id};
    push @classes, 'hidden'         if $menu_type eq 'hidden';
    push @classes, "subset_$subset" if $subset;

    my $child = $parent->append_child('li', {
      id         => $id,
      class      => \@classes,
      inner_HTML => qq{
        <div class="controls">
          $controls
          <div class="favourite sprite fave_icon _ht" title="Favorite this track"></div>
          $help
        </div>
        <div class="track_name">$name</div>
        $desc
      }
    });

    if ($display ne 'off') {
      my $p = $child;
      do { $p->set_flag('display') } while $p = $p->parent_node; # Set a flag to indicate that this node and all its parents should be printed in the HTML
    }

    $self->{'select_all_menu'}{$node->parent_node->id} = $menu;

    $self->{'menu_count'}{$menu_class} ||= 0;
    $self->{'menu_order'}{$parent}       = $self->{'menu_count'}{$menu_class}++ unless defined $self->{'menu_order'}{$parent};

    push @{$self->{'json'}{'tracksByType'}{$menu_class}[$self->{'menu_order'}{$parent}]}, $id;
    push @{$self->{'json'}{'trackIds'}}, $id; # use an array of tracks rather than a hash so that gzip can compress the json mmore effectively.
    push @{$self->{'json'}{'tracks'}}, {  # trackIds are used to convert tracks into a hash in javascript.
      id       => $id,
      type     => $menu_class,
      name     => lc $name,
      links    => "a.$menu_class" . ($subset || $submenu_class ? ', a.' . ($subset || "$menu_class-$submenu_class") : ''),
      renderer => $display,
      fav      => $self->{'favourite_tracks'}{$id},
      desc     => lc $self->strip_HTML($desc),
      html     => $child->render,
      popup    => qq{<ul class="popup_menu">$menu_header$menu</ul>},
    };
  }
}

sub add_select_all {
  my ($self, $node, $menu, $id) = @_;
  my $data = $node->data;

  return if $data->{'menu'} eq 'hidden';

  my $parent            = $node->parent_node;
  my $single_menu       = !$parent->data->{'node_type'} || scalar @{$parent->child_nodes} == 1; # If there are 0 or 1 submenus
  my @child_nodes       = @{$node->child_nodes};
  my $external_children = scalar grep $_->data->{'external'}, @child_nodes;
  my $external          = $data->{'external'};
  my $caption           = $data->{'caption'};
  my $matrix            = $data->{'menu'} eq 'matrix';

  # Don't add a select all if there is only one child
  if (scalar @child_nodes == 1) {
    # Add an h3 caption if there isn't going to be a select all for this menu (submenus will have select all)
    $menu->before('h3', { inner_HTML => $caption }) if $caption && !$single_menu && (($external_children == 1 && $external) || $external_children != 1);

    return;
  }

  my $child_tracks = scalar grep $_->data->{'node_type'} ne 'menu', @child_nodes;

  # Add a select all if there is more than one non menu child (node_type can be track or option), or if there is one child track and some non external menus
  if ($child_tracks > 1 || $child_tracks == 1 && scalar(@child_nodes) - $external_children > 1) {
    my $img_url = $self->view_config->species_defs->img_url;
    my %counts  = reverse %{$self->{'track_renderers'}{$id}};
    my $popup;

    $caption = $external ? $parent->data->{'caption'} : 'tracks' if $single_menu;
    $caption = $matrix ? "Configure matrix columns for $caption" : "Enable/disable all $caption";

    if (scalar keys %counts != 1) {
      $popup .= qq{<li class="$_->[0]">$_->[1]</li>} for [ 'off', 'Off' ], [ 'all_on', 'On' ];
      $popup .= qq{<li class="setting subset subset_$id"><a href="#">Configure track options</a></li>} if $matrix;
    } else {
      $popup = $self->{'select_all_menu'}{$id};
    }

    my $description = $data->{'description'} ? sprintf('<br /><i>%s</i>', $data->{'description'})
                                                : '';

    $menu->before('div', {
      class      => 'select_all config_menu',
      inner_HTML => qq(
        <ul class="popup_menu">
          <li class="header">Change track style<img class="close" src="${img_url}close.png" title="Close" alt="Close" /></li>
          $popup
        </ul>
        <strong>$caption</strong>
        $description
      )
    });
  } elsif ($caption && !$external) {
    $menu->before('h3', { inner_HTML => $caption });
  }
}

1;
