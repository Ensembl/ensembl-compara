# $Id$

package EnsEMBL::Web::ViewConfig;

use strict;

use CGI::Cookie;
use Digest::MD5 qw(md5_hex);
use HTML::Entities qw(encode_entities);
use JSON qw(from_json);
use URI::Escape qw(uri_unescape);

use EnsEMBL::Web::Form;
use EnsEMBL::Web::Tree;

use base qw(EnsEMBL::Web::Root);

use constant {
  SELECT_ALL_FLAG => '_has_select_all',
};

sub new {
  my ($class, $type, $component, $hub) = @_;
  
  my $self = {
    hub              => $hub,
    species          => $hub->species,
    species_defs     => $hub->species_defs,
    type             => $type,
    component        => $component,
    code             => "${type}::$component",
    options          => {},
    has_images       => 0,
    image_config     => undef,
    image_config_das => undef,
    title            => undef,
    form             => undef,
    form_id          => sprintf('%s_%s_configuration', lc $type, lc $component),
    custom           => $ENV{'ENSEMBL_CUSTOM_PAGE'} ? $hub->session->custom_page_config($type) : [],
    tree             => new EnsEMBL::Web::Tree,
  };
  
  bless $self, $class;
  
  $self->init;
  $self->modify;
  
  return $self;
}

sub hub              :lvalue { $_[0]->{'hub'};              }
sub title            :lvalue { $_[0]->{'title'};            }
sub image_config     :lvalue { $_[0]->{'image_config'};     }
sub image_config_das :lvalue { $_[0]->{'image_config_das'}; }
sub has_images       :lvalue { $_[0]->{'has_images'};       }
sub altered          :lvalue { $_[0]->{'altered'};          } # Set to one if the configuration has been updated
sub custom           :lvalue { $_[0]->{'custom'};           }
sub code             :lvalue { $_[0]->{'code'};             }
sub species          { return $_[0]->{'species'};           }
sub species_defs     { return $_[0]->{'species_defs'};      }
sub type             { return $_[0]->{'type'};              }
sub component        { return $_[0]->{'component'};         }
sub tree             { return $_[0]->{'tree'};              }
sub storable         { return 1;                            }
sub extra_tabs       { return ();                           } # Used to add tabs for related configuration. Return value should be ([ caption, url ] ... )

sub init   {}
sub modify {} # For plugins
sub form   {}

sub options { 
  my $self = shift;
  return keys %{$self->{'options'}};
}

sub set_defaults {
  my ($self, $defaults) = @_;
  $self->{'options'}{$_}{'default'} = $defaults->{$_} for keys %$defaults;
}

sub set {
  my ($self, $key, $value, $force) = @_; 	 
  
  return unless $force || exists $self->{'options'}{$key}; 	 
  return if $self->{'options'}{$key}{'user'} eq $value;
  $self->altered = 1;
  $self->{'options'}{$key}{'user'} = $value;
}

sub get {
  my ($self, $key) = @_;
  
  return undef unless exists $self->{'options'}{$key};
  
  my $type = exists $self->{'options'}{$key}{'user'} ? 'user' : 'default';
  
  return ref $self->{'options'}{$key}{$type} eq 'ARRAY' ? @{$self->{'options'}{$key}{$type}} : $self->{'options'}{$key}{$type};
}

sub set_user_settings {
  my ($self, $diffs) = @_;
  
  if ($diffs) {
    $self->{'options'}{$_}{'user'} = $diffs->{$_} for keys %$diffs;
  }
}

sub get_user_settings {
  my $self = shift;
  my $diffs = {};
  
  foreach my $key ($self->options) {
    $diffs->{$key} = $self->{'options'}{$key}{'user'} if exists $self->{'options'}{$key}{'user'} && $self->{'options'}{$key}{'user'} ne $self->{'options'}{$key}{'default'};
  }
  
  return $diffs;
}

sub reset {
  my ($self, $image_config) = @_;
  
  $image_config->reset if $image_config;
  
  foreach my $key ($self->options) {
    next unless exists $self->{'options'}{$key}{'user'};
    $self->altered = 1;
    delete $self->{'options'}{$key}{'user'};
  }
}

# Value indidates that the track can be configured for DAS (das) or not (nodas)
sub add_image_config {
  my ($self, $image_config, $das) = @_;  
  $self->image_config     = $image_config;
  $self->image_config_das = $das || 'das';
  $self->has_images       = 1 unless $image_config =~ /^V/;
}

# Loop through the parameters and update the config based on the parameters passed
sub update_from_input {
  my $self         = shift;
  my $hub          = $self->hub;
  my $input        = $hub->input;
  my $image_config = $hub->get_imageconfig($self->image_config) if $self->image_config;
  
  return $self->reset($image_config) if $input->param('reset');
  
  my $diff = $input->param('view_config');
  my $flag = 0;
  my $altered;
  
  if ($diff) {
    $diff = from_json($diff);
    
    foreach my $key (grep exists $self->{'options'}{$_}, keys %$diff) {
      my @values = ref $diff->{$key} eq 'ARRAY' ? @{$diff->{$key}} : ($diff->{$key});
      
      if ($values[0] ne $self->{'options'}{$key}{'user'}) {
        $flag = 1;
        
        if (scalar @values > 1) {
          $self->set($key, \@values);
        } else {
          $self->set($key, $values[0]);
        }
        
        $altered ||= $key if $values[0] !~ /^(off|no)$/;
      }
    }
  }
  
  $self->altered = $image_config->update_from_input if $image_config;
  $self->altered = $altered || 1 if $flag;
  
  return $self->altered;
}

# Loop through the parameters and update the config based on the parameters passed
sub update_from_url {
  my ($self, $r) = @_;
  my $hub     = $self->hub;
  my $session = $hub->session;
  my $input   = $hub->input;
  my $species = $hub->species;
  my $config  = $input->param('config');
  my @das     = $input->param('das');
  my $params_removed;
  
  if ($config) {
    foreach my $v (split /,/, $config) {
      my ($k, $t) = split /=/, $v, 2;
      
      if ($k =~ /^(cookie|image)_width$/) {
        my $cookie_host  = $self->species_defs->ENSEMBL_COOKIEHOST;
        
        # Set width
        if ($t != $ENV{'ENSEMBL_IMAGE_WIDTH'}) {
          my $cookie = new CGI::Cookie(
            -name    => 'ENSEMBL_WIDTH',
            -value   => $t,
            -domain  => $cookie_host,
            -path    => '/',
            -expires => $t =~ /\d+/ ? 'Monday, 31-Dec-2037 23:59:59 GMT' : 'Monday, 31-Dec-1970 00:00:01 GMT'
          );
          
          $r->headers_out->add('Set-cookie' => $cookie);
          $r->err_headers_out->add('Set-cookie' => $cookie);
          $self->altered = 1;
        }
      }
      
      $self->set($k, $t);
    }

    if ($self->altered) {
      $session->add_data(
        type     => 'message',
        function => '_info',
        code     => 'configuration',
        message  => 'Your configuration has changed for this page',
      );
    }
    
    $params_removed = 1;
    $input->delete('config');
  }
  
  if (scalar @das) {
    my $action = $hub->action;
    
    $hub->action = 'ExternalData'; # Change action so that the source will be added to the ExternalData view config
    
    foreach (@das) {
      my $source     = uri_unescape($_);
      my $logic_name = $session->add_das_from_string($source);
      
      if ($logic_name) {
        $session->add_data(
          type     => 'message',
          function => '_info',
          code     => 'das:' . md5_hex($source),
          message  => sprintf('You have attached a DAS source with DSN: %s%s.', encode_entities($source), $self->get($logic_name) ? ', and it has been added to the External Data menu' : '')
        );
      }
    }
    
    $hub->action = $action; # Reset the action
    
    $input->delete('das');
    $params_removed = 1;
  }
  
  my $image_config = $self->image_config;
  my @values       = split /,/, $input->param($image_config);
  
  if (@values) {
    $input->delete($image_config); 
    $params_removed = 1;
  }
  
  $hub->get_imageconfig($image_config)->update_from_url(@values) if @values;
  
  $session->store;

  return $params_removed;
}

sub get_form {
  my $self = shift;
  return $self->{'form'} ||= new EnsEMBL::Web::Form({ id => $self->{'form_id'}, action => $self->hub->url('Config', undef, 1)->[0], class => 'configuration std' });
}

sub add_fieldset {
  my ($self, $legend, $class) = @_;
  
  (my $div_class = $legend) =~ s/ /_/g;
  my $fieldset   = $self->get_form->add_fieldset($legend);
  my $tree       = $self->tree;
  
  $fieldset->set_attribute('class', $class) if $class;
  
  $tree->append($tree->create_node(lc $div_class, { url => '#', availability => 1, caption => $legend, class => $div_class }));
  
  return $fieldset;
}

sub get_fieldset {
  my ($self, $i) = @_;

  my $fieldsets = $self->get_form->fieldsets;
  my $fieldset;
  
  if (int $i eq $i) {
    $fieldset = $fieldsets->[$i];
  } else {
    for (@$fieldsets) {
      $fieldset = $_;
      last if $_->get_legend && $_->get_legend->inner_HTML eq $i;
    }
  }
  
  return $fieldset;
}

sub add_form_element {
  my ($self, $element) = @_;

  if ($element->{'type'} eq 'CheckBox' || $element->{'type'} eq 'DASCheckBox') {
    $element->{'selected'} = $self->get($element->{'name'}) eq $element->{'value'} ? 1 : 0 ;
  } elsif (!exists $element->{'value'}) {
    $element->{'value'} = $self->get($element->{'name'});
  }
  
  $self->add_fieldset('Display options') unless $self->get_form->has_fieldset;
  $self->get_form->add_element(%$element); ## TODO- modify it for the newer version of Form once all child classes are modified
}

sub build_form {
  my ($self, $object, $image_config) = @_;
  
  $self->build_imageconfig_form($image_config) if $image_config;
  
  if ($self->has_images) {
    my $fieldset = $self->get_fieldset('Display options') || $self->add_fieldset('Display options');
    
    $fieldset->add_field({
      type   => 'DropDown',
      name   => 'image_width',
      value  => $ENV{'ENSEMBL_DYNAMIC_WIDTH'} ? 'bestfit' : $ENV{'ENSEMBL_IMAGE_WIDTH'},
      label  => 'Width of image',
      values => [
        { value => 'bestfit', caption => 'best fit' },
        map {{ value => $_, caption => "$_ pixels" }} map $_*100, 5..20
      ]
    });
  }
  
  $self->form($object);
  
  foreach my $fieldset (@{$self->get_form->fieldsets}) {
    next if $fieldset->get_flag($self->SELECT_ALL_FLAG); 
    
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
      $fieldset->set_flag($self->SELECT_ALL_FLAG); # Add select all checkboxes
    }
  }
  
  foreach (@{$self->get_form->fieldsets}) {
    my $wrapper_div = $_->dom->create_element('div');
    my $legend      = $_->get_legend;
    
    if ($legend) {
      (my $div_class = $legend->inner_HTML) =~ s/ /_/g;
      $wrapper_div->set_attribute('class', "config $div_class view_config");
    }
    
    $wrapper_div->append_child($_->parent_node->replace_child($wrapper_div, $_));
  }
}

sub build_imageconfig_form {
  my $self              = shift;
  my $image_config      = shift;
  my $img_url           = $self->img_url;
  my $hub               = $self->hub;
  my $extra_menus       = $image_config->{'extra_menus'};
  my $tree              = $self->tree;
  my $image_config_tree = $image_config->tree;
  my $track_order;
  
  my $menu = $tree->append($tree->create_node('image_config', { caption => 'Image options' }));
  
  $menu->append($tree->create_node('active_tracks',    { caption => 'Active tracks',    availability => 1, url => '#', class => 'active_tracks',    rel => 'multi' })) if $extra_menus->{'active_tracks'};
  $menu->append($tree->create_node('favourite_tracks', { caption => 'Favourite tracks', availability => 1, url => '#', class => 'favourite_tracks', rel => 'multi' })) if $extra_menus->{'favourite_tracks'};
  
  if ($extra_menus->{'track_order'}) {
    $menu->append($tree->create_node('track_order', { caption => 'Track order', availability => 1, url => '#', class => 'track_order' }));
    $self->{'track_order'} = { map { join('.', grep $_, $_->id, $_->get('drawing_strand')) => $_->get('order') } $image_config->get_parameter('sortable_tracks') ? $image_config->get_sortable_tracks : () };
  }
  
  $menu->append($tree->create_node('search_results', { caption => 'Search results', availability => 1, url => '#', class => 'search_results disabled', rel => 'multi' })) if $extra_menus->{'search_results'};
  
  # Delete all tracks where menu = no, and parent nodes if they are now empty
  # Do this after creating track order, so that unconfigurable but displayed tracks are still considered in the ordering process
  $image_config->remove_disabled_menus;
  
  $self->{'favourite_tracks'} = $image_config->get_favourite_tracks;
  
  my @nodes = @{$image_config_tree->child_nodes};
  
  foreach my $n (grep $_->has_child_nodes, @nodes) {
    my @children = grep !$_->has_child_nodes, @{$n->child_nodes};
    
    if (scalar @children) {
      my $internal = $image_config_tree->create_node($n->id . '_internal');
      $internal->append($_) for @children;
      $n->prepend($internal);
    }
  }
  
  $self->build_imageconfig_menus($image_config, $img_url, $_, $_->id, 0) for @nodes;
  
  foreach my $node (grep $_->has_child_nodes, @nodes) {
    my $id      = $node->id;
    my $caption = $node->get('caption');
    my $first   = ' first';
    my $i       = 0;
    
    $node->data->{'class'}    = "config $id";
    $node->data->{'content'} .= qq{<h2 class="config_header">$caption</h2>};
    
    foreach my $n (@{$node->child_nodes}) {
      my $children = 0;
      my $content;
      
      # When creating HTML for the form, we want only the tracks which are turned on, and their parent nodes.
      # Set a flag to turn everything else off. This flag is checked by the render function in EnsEMBL::Web::Tree.
      foreach ($n->nodes) {
        my $display = $_->can('get') ? $_->get('display') : '';
        
        if ($display && $display ne 'off') {
          my $p = $_;
          $p->{'display'} = 'on' while $p = $p->parent_node;
        } else {
          $_->{'display'} = 'off';
        }
      }
      
      $content .= $_->render for @{$n->child_nodes}; # Add nodes which are turned on to the HTML returned
      $_->{'display'} = 'on' for $n, $n->nodes;      # Turn all nodes back on
      
      # Render again with all nodes turned on to add content to the tracks array
      foreach (@{$n->child_nodes}) {
        my $html = $_->render;
        
        next unless $html;
        
        push @{$node->data->{'tracks'}[$i]}, [ $_->id, $html, $self->{'favourite_tracks'}->{$_->id}, $_->get('display') ];
        $children++;
      }
      
      next unless $children;
      
      my $class = 'config_menu';
      
      if ($children) {
        my $popup  = $self->{'select_all_menu'}->{$n->id};
        my $header = $n->get('caption');
      
        if ($popup && $children > 1) {
          $header ||= 'tracks';
          $class   .= ' selectable';
          
          my %counts = reverse %{$self->{'track_renderers'}->{$n->id}};
          
          if (scalar keys %counts != 1) {
            $popup  = '';
            $popup .= qq{<li class="$_->[2]"><img title="$_->[1]" alt="$_->[1]" src="${img_url}render/$_->[0].gif" class="$id" />$_->[1]</li>} for [ 'off', 'Off', 'off' ], [ 'normal', 'On', 'all_on' ];
          }
          
          $node->data->{'content'} .= qq{
            <div class="select_all$first">
              <ul class="popup_menu">$popup</ul>
              <img title="Enable/disable all" alt="Enable/disable all" src="${img_url}render/off.gif" class="menu_option select_all" /><strong class="menu_option">Enable/disable all $header</strong>
            </div>
          };
        } elsif ($header) {
          $node->data->{'content'} .= "<h4>$header</h4>";
        }
      }
      
      $node->data->{'content'} .= qq{<ul class="$class">$content</ul>};
      
      $i++;
      
      $first = '';
    }
    
    my $on    = $self->{'enabled_tracks'}->{$id} || 0;
    my $count = $self->{'total_tracks'}->{$id}   || 0;
    
    $menu->append($tree->create_node($id, {
      caption      => $caption,
      url          => '#',
      availability => ($count > 0),
      class        => $id,
      count        => $count ? "($on/$count)" : ''
    }));
  }
  
  my $form    = $self->get_form;
  my $no_favs = qq{You have no favourite tracks. Use the <img src="${img_url}grey_star.png" alt="star" /> icon to add tracks to your favourites};
  
  $form->append_child('div', { inner_HTML => $_->data->{'content'},           class => $_->data->{'class'}       }) for @nodes;
  $form->append_child('div', { inner_HTML => $no_favs,                        class => 'config favourite_tracks' }) if $extra_menus->{'favourite_tracks'};
  $form->append_child('div', { inner_HTML => '<ul class="config_menu"></ul>', class => 'config track_order'      }) if $self->{'track_order'};
  
  my %tracks = map @{$_->data->{'tracks'} || []} ? ( $_->id => $_->data->{'tracks'} ) : (), @nodes;
  $self->{'tracks'} = \%tracks;
}

sub build_imageconfig_menus {
  my ($self, $image_config, $img_url, $node, $menu_class, $i) = @_;
  my $id       = $node->id;
  my $children = $node->child_nodes;
  
  $node->node_name = 'li';
  
  if (scalar @$children) {
    my $ul = $i > 1 && scalar @$children > 1 ? $node->dom->create_element('ul', { class => 'config_menu' }) : undef;
    my ($j, $menu);
    
    foreach (@$children) {
      my $m = $self->build_imageconfig_menus($image_config, $img_url, $_, $menu_class, $i + 1);
      $menu = $m if $m && ++$j;
      $ul->append_child($_) if $ul;
    }
    
    if ($ul) {
      $node->append_child($ul);
      
      if ($node->get('menu') eq 'hidden') {
        $ul->set_attribute('class', 'hidden') 
      } elsif ($menu) {
        my $caption   = $node->get('caption');
        my %renderers = reverse %{$self->{'track_renderers'}->{$id}};
        
        if (scalar keys %renderers != 1) {
          $menu  = '';
          $menu .= qq{<li class="$_->[2]"><img title="$_->[1]" alt="$_->[1]" src="${img_url}render/$_->[0].gif" class="$menu_class" />$_->[1]</li>} for [ 'off', 'Off', 'off' ], [ 'normal', 'On', 'all_on' ];
        }
        
        $ul->before('div', {
          class      => 'select_all',
          inner_HTML => qq{
            <ul class="popup_menu">$menu</ul>
            <img title="Enable/disable all" alt="Enable/disable all" src="${img_url}render/off.gif" class="menu_option select_all" /><strong class="menu_option">Enable/disable all $caption</strong>
          }
        });
      }
    }
  } elsif ($node->get('menu') ne 'no') {
    my @states   = @{$node->get('renderers') || [ 'off', 'Off', 'normal', 'Normal' ]};
    my $display  = $node->get('display')     || 'off';
    my $external = $node->get('_class');
    my $desc     = $node->get('description');
    my $controls = $node->get('controls');
    my $name     = encode_entities($node->get('name'));
    my $icon     = $external ? sprintf '<img src="%strack-%s.gif" style="width:40px;height:16px" title="%s" alt="[%s]" />', $img_url, lc $external, $external, $external : ''; # DAS icons, etc
    my ($selected, $menu, $help);
    
    while (my ($val, $text) = splice @states, 0, 2) {
      $text     = encode_entities($text);
      $selected = sprintf '<input type="hidden" class="track_name" name="%s" value="%s" /><img title="%s" alt="%s" src="%srender/%s.gif" class="menu_option" />', $id, $val, $text, $text, $img_url, $val if $val eq $display;
      $text     = qq{<li class="$val"><img title="$text" alt="$text" src="${img_url}render/$val.gif" class="$menu_class" />$text</li>};
      
      $menu .= $text;
      
      if (!$external) {
        my $n = $node;
        
        while ($n = $n->parent_node) {
          $self->{'track_renderers'}->{$n->id}->{$val}++;
        }
      }
    }
    
    if ($node->get('menu') ne 'hidden') {
      $self->{'enabled_tracks'}->{$menu_class}++ if $display ne 'off';
      $self->{'total_tracks'}->{$menu_class}++;
    }
    
    if ($desc) {
      $desc =~ s/&(?!\w+;)/&amp;/g;
      $desc =~ s/href="?([^"]+?)"?([ >])/href="$1"$2/g;
      $desc =~ s/<a>/<\/a>/g;
      $desc =~ s/"[ "]*>/">/g;
      $desc = qq{<div class="desc">$desc</div>};
      
      $help = qq{<div class="menu_help"></div>};
    } else {
      $help = qq{<div class="empty"></div>};
    }
    
    $node->set_attribute('class', "$id track $external" . ($display eq 'off' ? '' : ' on') . ($self->{'favourite_tracks'}->{$id} ? ' fav' : '') . ($node->get('menu') eq 'hidden' ? ' hidden' : ''));
    $node->inner_HTML(qq{
      <ul class="popup_menu">$menu</ul>
      $selected<span class="menu_option">$icon$name</span>
      <div class="controls">
        $controls
        <div class="favourite" title="Favorite this track"></div>
        $help
      </div>
      $desc
    });
    
    $self->{'select_all_menu'}->{$node->parent_node->id} = $menu unless $external;
    
    return $menu unless $external;
  }
  
  return undef;
}

1;