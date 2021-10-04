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
no warnings "uninitialized";

use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::Attributes;

use parent qw(EnsEMBL::Web::Form);

sub view_config :Accessor;

sub new {
  ## @override
  ## @param ViewConfig object
  ## @param Form id attribute
  ## @param Form action attribute
  my ($class, $view_config, $id, $action) = @_;

  my $self = $class->SUPER::new({
    'id'      => $id,
    'action'  => $action,
    'class'   => 'configuration std bgcolour'
  });

  $self->{'view_config'} = $view_config;

  return $self;
}

sub js_panel {
  ## Panel used by JS
  return 'Configurator';
}

sub add_fieldset {
  my ($self, $legend, $no_tree) = @_;

  $legend ||= '';

  my $div_class = $legend =~ s/ /_/gr;
  my $fieldset  = $self->SUPER::add_fieldset($legend);

  unless ($no_tree) {
    my $tree = $self->view_config->tree;
    $tree->append_node(lc $div_class, { url => '#', availability => 1, caption => $legend, class => $div_class });
  }

  return $fieldset;
}

sub get_fieldset {
  my ($self, $i) = @_;

  my $fieldsets = $self->fieldsets;
  my $fieldset;

  if ($i =~ /^[0-9]+$/) {
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

  my $fieldset;
  if ($element->{'fieldset'}) {
    ($fieldset) = grep { my $legend = $_->get_legend; $legend && $legend->inner_HTML eq $element->{'fieldset'} } @{$self->fieldsets};
    $self->add_fieldset($element->{'fieldset'}) unless $fieldset;
    delete $element->{'fieldset'};
  } else {
    $self->add_fieldset('Display options') unless $self->has_fieldset;
  }

  $self->add_element(%$element);

  if (!$view_config->get_label($element->{'name'})) {
    $view_config->set_label($element->{'name'}, $element->{'label'});
  }

  if (!$view_config->get_label($element->{'name'}) && $element->{'values'}) {
    $view_config->set_value_label($element->{'name'}, { map { $_->{'value'} => $_->{'caption'} } @{$element->{'values'}} });
  }
}

sub build {
  ## Build the html form for both image config and view config
  my ($self, $object, $image_config) = @_;

  my $view_config = $self->view_config;
  my $hub         = $view_config->hub;

  $self->_build_imageconfig_form($image_config) if $image_config;

  $view_config->init_form($object);
  $view_config->init_form_non_cacheable; # ViewConfig form level caching is not implemented yet, so calling both methods

  ## Add image width field to horizintal images
  if ($image_config && $image_config->orientation eq 'horizontal') {
    my $fieldset = $self->get_fieldset('Display options') || $self->add_fieldset('Display options');

    $fieldset->add_field({
      'type'   => 'dropdown',
      'name'   => 'image_width',
      'value'  => $hub->get_cookie_value('DYNAMIC_WIDTH') ? 'bestfit' : $hub->image_width,
      'label'  => 'Width of image',
      'values' => [ { 'value' => 'bestfit', 'caption' => 'best fit' }, map {{ 'value' => $_, 'caption' => "$_ pixels" }} map $_*100, 5..20 ]
    });
  }

  # Wrap non-empty fieldsets and replace empty fieldsets with divs to allow JS to show/hide these when LHS link is clicked
  foreach my $fieldset (@{$self->fieldsets}) {
    my $wrapper_div = $self->dom->create_element('div');

    if (my $legend = $fieldset->get_legend) {
      $wrapper_div->set_attribute('class', ['config', 'view_config', $legend->inner_HTML =~ s/ /_/gr]);
    }

    $fieldset->parent_node->replace_child($wrapper_div, $fieldset);
    $wrapper_div->append_child($fieldset) unless $fieldset->has_flag('empty');
  }
}

sub _build_imageconfig_form {
  ## @private
  ## Generates HTML and JSON requiured for the image config panel
  my $self          = shift;
  my $image_config  = shift;
  my $ic_root_node  = $image_config->tree->root;
  my $view_config   = $self->view_config;
  my $img_url       = $view_config->species_defs->img_url;
  my $tree          = $view_config->tree;
  my $track_order;

  $self->{'json'}   = {};

  $self->{favourite_tracks} = $image_config->_favourite_tracks;

  # Search results menu
  if ($image_config->has_extra_menu('search_results')) {
    $self->append_child('div', { class => 'config no_search', inner_HTML => 'Sorry, your search did not find any tracks' });
    $self->prepend_child('h1', { class => 'search_results', inner_HTML => 'Search results' });
    $tree->prepend_node('search_results', { caption => 'Search results', class => 'search_results disabled', availability => 1, url => '#', rel => 'multi' });
  }

  # Track order menu
  if ($image_config->has_extra_menu('track_order')) {
    $self->append_child('div', { class => 'config track_order', inner_HTML => '<h1 class="track_order">Track order</h1><ul class="config_menu"></ul>' });
    $tree->prepend_node('track_order', { caption => 'Track order', class => 'track_order', availability => 1, url => '#' });
    $self->{'json'}{'order'} = { map { join('.', grep $_, $_->id, $_->get_data('drawing_strand')) => $_->get_data('order') } $image_config->get_parameter('sortable_tracks') ? $image_config->get_sortable_tracks : () };
  }

  # Favourite tracks menu
  if ($image_config->has_extra_menu('favourite_tracks')) {
    $self->append_child('div', { class => 'config favourite_tracks', inner_HTML => qq(You have no favourite tracks. Use the <img src="${img_url}grey_star.png" alt="star" /> icon to add tracks to your favourites) });
    $self->prepend_child('h1', { class => 'favourite_tracks', inner_HTML => 'Favourite tracks' });
    $tree->prepend_node('favourite_tracks', { caption => 'Favourite tracks', class => 'favourite_tracks', availability => 1, url => '#', rel => 'multi' });
  }

  # Active tracks menu
  if ($image_config->has_extra_menu('active_tracks')) {
    $self->prepend_child('h1', { class => 'active_tracks', inner_HTML => 'Active tracks' });
    $tree->prepend_node('active_tracks', { caption => 'Active tracks', class => 'active_tracks', availability => 1, url => '#', rel => 'multi' });
  }

  # Move user data/external data to top
  _prioritize_userdata_menus($ic_root_node);

  # Delete empty menus nodes
  _remove_disabled_menus($ic_root_node);

  # Remove unnecessay deep nesting of menus
  _clean_nested_menus($ic_root_node);

  # Add all first level menu nodes to the LHS menu column
  $self->_add_imageconfig_menu($_) for @{$ic_root_node->child_nodes};

  # When creating HTML for the form, we want only the tracks which are turned on, and their parent nodes - remove all other track nodes before rendering.
  # Also remove any empty UL tags. These can occur when a menu which is not explicitly external contains only external tracks.
  $_->remove for grep { ($_->node_name eq 'li' && !$_->get_flag('display')) || ($_->node_name eq 'ul' && !$_->has_child_nodes) } @{$self->get_all_nodes};

  return $self;
}

sub _add_imageconfig_menu {
  ## @private
  ## Adds main sections to the image config panel on the RHS and corresponding main heading to the LHS menu
  my ($self, $node) = @_;

  my $section = $node->id =~ s/\-/_/gr;

  return if $section eq 'track_order'; # FIXME - avoid hard coding

  my $tree        = $self->view_config->tree;
  my $caption     = $node->get_data('caption');
  my $desc        = $node->get_data('description');
  my $parent_menu = $tree->append_node($section, { 'caption' => $caption, 'class' => $section, 'url' => '#' }); # LHS menu
  my $div_classes = ['config', $section];
  push @$div_classes, 'trackhub' if $node->get_data('trackhub_menu');
  push @$div_classes, 'has_matrix' if $node->get_data('has_matrix');
  my $div         = $self->append_child('div', { 'class' => $div_classes }); # RHS section

  # Add the main menu
  $div->append_child('h2', {'class' => 'config_header', 'inner_HTML' => $caption});
  $div->append_child('div', {'class' => 'long_label', 'inner_HTML' => $desc }) if $desc;

  # Add sub menus and sub sections
  my $grand_total = 0;
  if ($node->has_child_nodes) {
    my @child_nodes = grep !$_->get_data('cloned'), @{$node->child_nodes};

    # If all children are menus
    if (scalar @child_nodes && !grep $_->get_data('node_type') ne 'menu', @child_nodes) {
      my $first = 'first ';
      my $multi = scalar(@child_nodes) > 1 ? 'multiple ' : '';

      foreach my $child (@child_nodes) {
        my $id      = $child->id;
        ## Matrices by definition have multiple tracks under a subheader
        $multi = 'multiple ' if $child->get_data('menu') eq 'matrix';
        my $parent  = $div->append_child('div', { 'class' => "subset $multi$first$id" });

        $self->_build_imageconfig_menus($child, $parent, $section, $id);
        $first = '';

        my $url = $child->get_data('url');

        # Count the required tracks for the LHS menu
        my @track_ids = map $_->id, grep { !$_->get_data('cloned') && $_->get_data('node_type') eq 'track' && $_->get_data('menu') ne 'hidden' && $_->get_data('matrix') ne 'column' } @{$child->get_all_nodes};
        my $total = scalar @track_ids;
        my $on    = scalar grep $self->{'enabled_tracks'}{$_}, @track_ids;

        $grand_total += $total;

        # Add submenu entries to the LHS menu
        $parent_menu->append_child($tree->create_node($id, {
          'caption'       => $child->get_data('caption'),
          'class'         => $url ? $id : $parent_menu->id . "-$id",
          'url'           => $url || '#',
          'count'         => $total ? qq{(<span class="on">$on</span>/$total)} : '',
          'availability'  => $url ? 1 : $total > 0,
        }));

        # Add an empty fieldset corresponding to the menu entry in the form
        $self->add_fieldset($id, 1)->set_flag('empty') if $url;
      }
    } else {

      my $parent = $div->append_child('div', {'class' => 'subset' . (scalar @child_nodes > 1 ? ' first' : '') })->append_child('ul', { 'class' => "config_menu $section" }); # Add a subset div to keep the HTML consistent

      $self->_build_imageconfig_menus($_, $parent, $section) for @child_nodes;
      $self->_add_select_all($node, $parent, $section);
    }
  }

  my $on    = $self->{'enabled_tracks'}{$section} || 0;
  my $total = $grand_total || $self->{'total_tracks'}{$section}   || 0;

  $parent_menu->set_data('count', qq{(<span class="on">$on</span>/$total)}) if $total;
  $parent_menu->set_data('availability', $total > 0);
}

sub _build_imageconfig_menus {
  my ($self, $node, $parent, $menu_class, $submenu_class) = @_;
  my $menu_type = $node->get_data('menu');
  my $id        = $node->id;

  return if $menu_type eq 'no';

  if ($menu_type eq 'matrix_subtrack') {
    my $display = $node->get('display');
    if ($display ne 'off' && $display ne 'default'

#    if ($node->get_node($node->get_data('option_key')) &&
#      $node->get_node($node->get_data('option_key'))->get('display') eq 'on' &&  # The cell option is turned on AND
#      $display ne 'off' &&                                                       # The track is not turned off AND
#      !($display eq 'default' && $node->get_node($node->get_data('column_key'))->get('display') eq 'off') 
                                                # The track renderer is not default while the column renderer is off
    ) {
      $self->{'enabled_tracks'}{$menu_class}++;
      $self->{'enabled_tracks'}{$id} = 1;

      $self->{'json'}{'subTracks'}{$node->get_data('column_key')}++ if $display eq 'default'; # use an array of tracks rather than a hash so that gzip can compress the json mmore effectively.
    } else {
      $self->{'json'}{'subTracks'}{$node->get_data('column_key')} ||= 0; # Force subTracks entries to exist
    }

    $self->{'total_tracks'}{$menu_class}++;

    return;
  }

  my $external = $node->get_data('external');

  if ($node->get_data('node_type') eq 'menu') {
    my $caption = $node->get_data('caption');
    my $element;

    if ($parent->node_name eq 'ul') {
      if ($external) {
        $parent = $parent->parent_node;                                # Move external tracks to a separate ul, after other tracks
      } else {
        $parent = $parent->append_child('li', { 'flags' => 'display' }); # Children within a subset (eg variation sets)
      }
    }

    # If the children are all non external menus, add another wrapping div so there can be distinct groups in a submenu, with unlinked enable/disable all controls
    if (!scalar(grep $_->get_data('node_type') ne 'menu', @{$node->child_nodes}) && scalar(grep !$_->get_data('external'), @{$node->child_nodes})) {
      $element = $parent->append_child('div', { class => $menu_type eq 'hidden' ? ' hidden' : '' });
    } else {
      $element = $parent->append_child('ul', { class => "config_menu $menu_class" . ($menu_type eq 'hidden' ? ' hidden' : '') });
    }

    $self->_build_imageconfig_menus($_, $element, $menu_class, $submenu_class) for grep !$_->get_data('cloned'), @{$node->child_nodes};
    $self->_add_select_all($node, $element, $id) if $element->node_name eq 'ul';
  } else {
    my $img_url     = $self->view_config->species_defs->img_url;
    my @states      = @{$node->get_data('renderers') || [ 'off', 'Off', 'normal', 'On' ]};
    my %valid       = @states;
    my $display     = $node->get('display') || 'off';
       $display     = $valid{'normal'} ? 'normal' : $states[2] unless $valid{$display};
    my $controls    = $node->get_data('controls');
    my $subset      = $node->get_data('subset');
    my $name        = $node->get_data('name');
    my $caption     = encode_entities($node->get_data('caption'));
    $name           .= $name ne $caption ? "<span class='hidden-caption'> ($caption)</span>" : '';
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

    if ($node->get_data('matrix') ne 'column') {
      if ($display ne 'off') {
        #warn "@@@ $id DISPLAY $display" if $node->get_data('glyphset') =~ /^fg_/;
        $self->{'enabled_tracks'}{$menu_class}++;
        $self->{'enabled_tracks'}{$id} = 1;
      }

      $self->{'total_tracks'}{$menu_class}++;
    }

    my $desc      = '';
    my $node_desc = $node->get_data('description');
    my $desc_url  = $node->get_data('desc_url') ? $self->view_config->hub->url('Ajax', {'type' => 'fetch_html', 'url' => $node->get_data('desc_url')}) : '';

    if ($node->get_data('subtrack_list')) { # it's a composite track
      $desc .= '<h1>Track list</h1>';
      $desc .= sprintf '<ul>%s</ul>', join '', map $_->[1], sort { $a->[0] cmp $b->[0] } map [ lc $_->[0], $_->[1] ? "<li><p><b>$_->[0]</b></p><p>$_->[1]</p></li>" : "<li>$_->[0]</li>" ], @{$node->get_data('subtrack_list')};
      $desc .= "<h1>Trackhub description: $node_desc</h1>" if $node_desc && $desc_url;
      $desc .= qq(<div class="_dyna_load"><a class="hidden" href="$desc_url">No description found for this composite track.</a>Loading&#133;</div>) if $desc_url;
    } else {
      $desc .= $desc_url ? sprintf(q(<div class="_dyna_load"><a class="hidden" href="%s">%s</a>Loading&#133;</div>), $desc_url, encode_entities($node_desc)) : $node_desc;
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
      desc     => lc($desc =~ s/<[^>]+>//gr),
      html     => $child->render,
      popup    => qq{<ul class="popup_menu">$menu_header$menu</ul>},
    };
  }
}

sub _add_select_all {
  my ($self, $node, $menu, $id) = @_;

  return if $node->get_data('menu') eq 'hidden';

  my $parent            = $node->parent_node;
  my $single_menu       = !$parent->get_data('node_type') || scalar @{$parent->child_nodes} == 1; # If there are 0 or 1 submenus
  my @child_nodes       = @{$node->child_nodes};
  my $external_children = scalar grep $_->get_data('external'), @child_nodes;
  my $external          = $node->get_data('external');
  my $caption           = $node->get_data('caption');
  my $matrix            = $node->get_data('menu') eq 'matrix';

  # Don't add a select all if there is only one child
  # - but tracks that appear on both strands will manifest as two nodes, so be careful!
  my $single_track = 0;
  if (scalar @child_nodes == 1) {
    $single_track = 1;
  }
  elsif (scalar @child_nodes == 2 && $child_nodes[0]{'data'}{'caption'} eq $child_nodes[1]{'data'}{'caption'}
        && $child_nodes[0]{'data'}{'drawing_strand'} ne $child_nodes[1]{'data'}{'drawing_strand'}) {
    $single_track = 1;
  }

  if ($single_track) {
    # Add an h3 caption if there isn't going to be a select all for this menu (submenus will have select all)
    $menu->before('h3', { inner_HTML => $caption }) if $caption && !$single_menu && (($external_children == 1 && $external) || $external_children != 1);

    return;
  }

  my $child_tracks = scalar grep $_->get_data('node_type') ne 'menu', @child_nodes;

  # Add a select all if there is more than one non menu child (node_type can be track or option), or if there is one child track and some non external menus
  if ($child_tracks > 1 || $child_tracks == 1 && scalar(@child_nodes) - $external_children > 1) {
    my $img_url = $self->view_config->species_defs->img_url;
    my %counts  = reverse %{$self->{'track_renderers'}{$id} || {}};

    $caption = $external ? $parent->get_data('caption') : 'tracks' if $single_menu;
    my $description = $node->get_data('description');
       $description = $description ? sprintf('<br /><i>%s</i>', $description) : '';
    my $inner_html;

    if ($matrix) {
      $caption = "Configure $caption";
      $inner_html = qq(
          <h3 class="matrix_link subset subset_$id" href="#">$caption</h3>
          $description
      );
    }
    else {
      $caption = "Enable/disable all $caption";

      my $popup;
      if (scalar keys %counts != 1) {
        $popup .= qq{<li class="$_->[0]">$_->[1]</li>} for [ 'off', 'Off' ], [ 'all_on', 'On' ];
        #$popup .= qq{<li class="setting subset subset_$id"><a href="#">Configure track options</a></li>} if $matrix;
      } else {
        $popup = $self->{'select_all_menu'}{$id};
      }
      $inner_html = qq(
          <ul class="popup_menu">
            <li class="header">Change track style<img class="close" src="${img_url}close.png" title="Close" alt="Close" /></li>
            $popup
          </ul>
          <strong>$caption</strong>
          $description
      );
    }

    $menu->before('div', {
      class      => 'select_all config_menu',
      inner_HTML => $inner_html,
      });

  } elsif ($caption && !$external) {
    $menu->before('h3', { inner_HTML => $caption });
  }
}

sub add_species_fieldset {
  my $self          = shift;
  my $hub           = $self->view_config->hub;
  my $species_defs  = $self->view_config->species_defs;
  my %species       = map { $species_defs->species_label($_) => $_ } $species_defs->valid_species;

  foreach (sort { ($a =~ /^<.*?>(.+)/ ? $1 : $a) cmp ($b =~ /^<.*?>(.+)/ ? $1 : $b) } keys %species) { 
    # complicated if statement which shows/hides strains or main species depending on the view you are on (i.e. when you are on a main species, do not show strain species, and when you are on a strain species or strain view from main species, show only strain species)
    next if (
              (!$hub->param('strain') && $hub->is_strain($species{$_})) 
              || (($hub->param('strain') || $hub->is_strain) && !$self->view_config->species_defs->get_config($species{$_}, 'RELATED_TAXON'))
            ); 
    
    $self->add_form_element({
      'fieldset'  => 'Selected species',
      'type'      => 'CheckBox',
      'label'     => $_,
      'name'      => 'species_' . lc $species{$_},
      'value'     => 'yes',
    });
  }
}

sub _prioritize_userdata_menus {
  ## @private
  ## Moves the user data menus and externally added tracks to top
  my $node = shift;

  $node->prepend_child($node->remove_child($_)) for sort {lc $a->get_data('caption') cmp lc $b->get_data('caption')} grep $_->get_data('external'), @{$node->child_nodes};
  $node->prepend_child($node->remove_child($_)) for grep $_->id eq 'user_data', @{$node->child_nodes};
}

sub _remove_disabled_menus {
  ## @private
  ## Removes, from the image config tree, all nodes that have menu=no and the menus that have no nodes in them
  my $node = shift;

  if ($node->has_child_nodes) {
    _remove_disabled_menus($_) for @{$node->child_nodes};
  }

  $node->remove if !$node->has_child_nodes && $node->get_data('node_type') eq 'menu' || $node->get_data('menu') eq 'no';
}

sub _clean_nested_menus {
  ## @private
  ## In the scenario where the tree structure is menu -> sub menu -> sub menu, and the 3rd level contains only one non-external menu,
  ## move all the tracks in that 3rd level menu up to the 2nd level, and delete the 3rd level.
  my $node      = shift;
  my @subnodes  = @{$node->child_nodes};
  my @submenus  = grep $_->get_data('node_type') eq 'menu' && !$_->get_data('external'), @subnodes;

  _clean_nested_menus($_) for @submenus;

  if ($node->parent_node && scalar @submenus == 1 && scalar @subnodes == 1) {
    $node->append_child($_) for @{$submenus[0]->child_nodes};
    $node->remove_child($submenus[0]);
  }
}

1;
