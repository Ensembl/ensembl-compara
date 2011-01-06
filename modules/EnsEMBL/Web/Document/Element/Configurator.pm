# $Id$

package EnsEMBL::Web::Document::Element::Configurator;

# Generates the modal context navigation menu, used in dynamic pages

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Document::Element::Content);

sub tree    :lvalue { $_[0]->{'tree'};    }
sub active  :lvalue { $_[0]->{'active'};  }
sub caption :lvalue { $_[0]->{'caption'}; }

sub content {
  my $self = shift;
  
  my $content = $self->{'form'};
  $content   .= $_->component_content for @{$self->{'panels'}};
  $content   .= '</form>' if $self->{'form'};
  
  return $content;
}

sub get_json {
  my $self    = shift;
  my $single  = scalar @{$self->{'panels'}} == 1;
  my $wrapper = 'modal_wrapper' . ($single ? ' panel' : '');
  
  return {
    content   => $self->content,
    wrapper   => qq{<div class="$wrapper"></div>},
    panelType => 'Configurator'
  };
}

sub init {  
  my $self          = shift;
  my $controller    = shift;
  my $hub           = $controller->hub;
  my $page          = $controller->page;
  my $configuration = $controller->configuration;
  my $view_config   = $controller->view_config;
  my $config_key    = $hub->param('config');
  my $image_config  = $config_key ? $hub->get_imageconfig($config_key, $config_key, 'merged') : undef;
  my $action        = join '/', map $hub->$_ || (), qw(type action function);
  my $url           = $hub->url({ type => 'Config', action => $action }, 1);
  
  $configuration->tree->_flush_tree;
  
  if ($image_config) {
    $self->init_imageconfig($controller, $image_config, $url);
  } else {
    $self->init_viewconfig($controller, $view_config, $url);
  }
  
  $self->add_reset_panel($controller, $image_config ? $image_config->get_parameter('title') : $view_config->title, $action, $config_key);
  
  $page->navigation->tree($self->tree);
  $page->navigation->active($self->active);
  $page->navigation->caption($self->caption);
  $page->navigation->configuration(1);
}

sub init_viewconfig {
  my $self        = shift;
  my $controller  = shift;
  my $view_config = shift;
  my $url         = shift;
  my $hub         = $controller->hub;
  
  if ($view_config && $view_config->has_form) {
    $view_config->build_form($controller->object);
    $view_config->get_form->set_attribute('action', $url->[0]);
    $view_config->add_form_element({ type => 'Hidden', name => $_, value => $url->[1]->{$_} }) for keys %{$url->[1]};
    
    # hack to display help message for Cell line configuration on region in detail
    if ($view_config->action eq 'Cell_line') {
      my $info_panel = $self->new_panel('Configurator', $controller, code => 'configurator_info');
      my $function = $view_config->type eq 'Location' ? 'View' : 'Cell_line';
      my $conf = $view_config->type eq 'Location' ? 'contigviewbottom' : 'reg_detail_by_cell_line';
      my $label = $view_config->type eq 'Location' ? 'Main Panel' : 'Cell line tracks';

      my $configuration_link = $hub->url({
        type     => 'Config',
        action   => $view_config->type,
        function => $function,
        config   => $conf
       });
       
      $info_panel->set_content(qq{
        <div class="info">
          <h3>Note:</h3>
          <div class ="error-pad">
          <p> These are data intensive tracks. For best performance it is advised that you limit the 
              number of feature types you try to display at any one time.
          </p>
          <p>
            Any cell lines that you configure here must also be turned on in the 
            <a href="$configuration_link#functional" class="modal_link" rel="modal_config_$conf" title="Configure this page">functional genomics</a> 
            section of the "$label" tab before any data will be displayed.
          </p>
          </div>
        </div>
      });

      $self->add_panel($info_panel);
    }
    
    my $panel   = $self->new_panel('Configurator', $controller, code => 'configurator');
    my $content = '';
    $content   .= sprintf '<h2>Configuration for %s</h2>', encode_entities($view_config->title) if $view_config->title;
    $content   .= $view_config->get_form->render;
    
    $panel->set_content($content);
    $self->add_panel($panel);
    
    $self->tree    = $view_config->tree;
    $self->active  = 'form_conf';
    $self->caption = 'Configure view';
  }
}

sub init_imageconfig {
  my $self          = shift;
  my $controller    = shift;
  my $image_config  = shift;
  my $url           = shift;
  my $img_url       = $controller->img_url;
  my $configuration = $controller->configuration;
  my $search_panel  = $self->new_panel('Configurator', $controller, code => 'configurator_search');
  my $panel         = $self->new_panel('Configurator', $controller, code => 'configurator');
  
  $image_config->remove_disabled_menus; # Delete all tracks where menu = no, and parent nodes if they are now empty
  
  $configuration->create_node('active_tracks',  'Active tracks',  [], { availability => 1, url => '#', class => 'active_tracks'           });
  $configuration->create_node('search_results', 'Search Results', [], { availability => 1, url => '#', class => 'search_results disabled' });
  
  my @nodes = @{$image_config->tree->child_nodes};
  
  for my $n (grep $_->has_child_nodes, @nodes) {
    my @children = grep !$_->has_child_nodes, @{$n->child_nodes};
    
    if (scalar @children) {
      my $internal = $image_config->tree->create_node($n->id . '_internal');
      $internal->append($_) for @children;
      $n->prepend($internal);
    }
  }
  
  $self->imageconfig_content($image_config, $img_url, $_, $_->id, 0) for @nodes;
  
  foreach my $node (grep $_->has_child_nodes, @nodes) {
    my $id      = $node->id;
    my $caption = $node->get('caption');
    my $first   = ' first';
    
    $node->data->{'content'} .= qq{
      <div class="config $id">
        <h2 class="config_header">$caption</h2>
    };
    
    foreach my $n (@{$node->child_nodes}) {
      my $children = 0;
      my $content; 
      
      foreach (map { $_->render || () } @{$n->child_nodes}) {
        $content .= $_;
        $children++;
      }
      
      next unless $content;
      
      my $class = 'config_menu';
      
      if ($children > 1) {
        my $menu   = $self->{'select_all_menu'}->{$n->id};
        my $header = $children ? $n->get('caption') : '';
      
        if ($menu) {
          $header ||= 'tracks';
          $class   .= ' selectable';
          
          my %counts = reverse %{$self->{'track_renderers'}->{$n->id}};
          
          if (scalar keys %counts != 1) {
            $menu  = '';
            $menu .= qq{<li class="$_->[2]"><img title="$_->[1]" alt="$_->[1]" src="${img_url}render/$_->[0].gif" class="$id" />$_->[1]</li>} for [ 'off', 'Off', 'off' ], [ 'normal', 'On', 'all_on' ];
          }
          
          $node->data->{'content'} .= qq{
            <div class="select_all$first">
              <ul class="popup_menu">$menu</ul>
              <img title="Enable/disable all" alt="Enable/disable all" src="${img_url}render/off.gif" class="menu_option select_all" /><strong class="menu_option">Enable/disable all $header</strong>
            </div>
          };
        } elsif ($header) {
          $node->data->{'content'} .= "<h4>$header</h4>";
        }
      }
      
      $node->data->{'content'} .= qq{<ul class="$class">$content</ul>};
      
      $first = '';
    }
    
    $node->data->{'content'} .= '</div>';
    
    my $on    = $self->{'enabled_tracks'}->{$id} || 0;
    my $count = $self->{'total_tracks'}->{$id}   || 0;
    
    $configuration->create_node($id, ($count ? "($on/$count) " : '') . $caption, [], { url => '#', availability => ($count > 0), class => $id });
  }
  
  $search_panel->set_content('<div class="configuration_search">Find a track: <input class="configuration_search_text" /></div>');
  
  $panel->set_content(sprintf(qq{
    <form class="configuration" action="$url->[0]" method="post">
      <div>
        %s
        <input type="hidden" name="config" value="%s" />
      </div>
      %s
    </form>},
    join('', map { sprintf '<input type="hidden" name="%s" value="%s" />', $_, encode_entities($url->[1]->{$_}) } keys %{$url->[1]}),
    $controller->hub->param('config'),
    join('', map $_->data->{'content'}, @nodes)
  ));
  
  $self->add_panel($search_panel);
  $self->add_panel($panel);
  
  $self->tree    = $configuration->tree;
  $self->active  = 'active_tracks';
  $self->caption = $image_config->get_parameter('title');
}

sub imageconfig_content {
  my ($self, $image_config, $img_url, $node, $menu_class, $i) = @_;
  my $id       = $node->id;
  my $children = $node->child_nodes;
  
  $node->node_name = 'li';
  
  if (scalar @$children) {
    my $ul = $i > 1 && scalar @$children > 1 ? $node->dom->create_element('ul', { class => 'config_menu' }) : undef;
    my ($j, $menu);
    
    foreach (@$children) {
      my $m = $self->imageconfig_content($image_config, $img_url, $_, $menu_class, $i + 1);
      $menu = $m if $m && ++$j;
      $ul->append_child($_) if $ul;
    }
    
    if ($ul) {
      $node->append_child($ul);
      
      if ($menu) {
        my $caption   = $node->get('caption');
        my %renderers = reverse %{$self->{'track_renderers'}->{$id}};
        
        if (scalar keys %renderers != 1) {
          $menu  = '';
          $menu .= qq{<li class="$_->[2]"><img title="$_->[1]" alt="$_->[1]" src="${img_url}render/$_->[0].gif" class="$menu_class" />$_->[1]</li>} for [ 'off', 'Off', 'off' ], [ 'normal', 'On', 'all_on' ];
        }
        
        $ul->before($node->dom->create_element('div', {
          class      => 'select_all',
          inner_HTML => qq{
            <ul class="popup_menu">$menu</ul>
            <img title="Enable/disable all" alt="Enable/disable all" src="${img_url}render/off.gif" class="menu_option select_all" /><strong class="menu_option">Enable/disable all $caption</strong>
          }
        }));
      }
    }
  } elsif ($node->get('menu') ne 'no') {
    my @states    = @{$node->get('renderers') || [ 'off', 'Off', 'normal', 'Normal' ]};
    my $display   = $node->get('display')     || 'off';
    my $external  = $node->get('_class');
    my $desc      = $node->get('description');
    my $name      = encode_entities($node->get('name'));
    my $icons     = $external ? sprintf '<img src="%strack-%s.gif" style="width:40px;height:16px" title="%s" alt="[%s]" />', $img_url, lc $external, $external, $external : ''; # DAS icons, etc
    my $fg_link   = $name && $node->get('glyphset') eq 'fg_multi_wiggle' ? $self->multiwiggle_multi_link($image_config) : ''; # FIXME: HACKHACKHACKHACKHACKHACKHACKHACKHACKHACKHACKHACKHACKHACKHACKHACKHACKHACKHACKHACK
    my ($selected, $menu, $help);
    
    while (my ($val, $text) = splice @states, 0, 2) {
      $text     = encode_entities($text);
      $selected = sprintf '<input type="hidden" name="%s" value="%s" /><img title="%s" alt="%s" src="%srender/%s.gif" class="menu_option" />', $id, $val, $text, $text, $img_url, $val if $val eq $display;
      $text     = qq{<li class="$val"><img title="$text" alt="$text" src="${img_url}render/$val.gif" class="$menu_class" />$text</li>};
      
      $menu .= $text;
      
      if (!$external) {
        my $n = $node;
        
        while ($n = $n->parent_node) {
          $self->{'track_renderers'}->{$n->id}->{$val}++;
        }
      }
    }
    
    $self->{'enabled_tracks'}->{$menu_class}++ if $display ne 'off';
    $self->{'total_tracks'}->{$menu_class}++;
    
    if ($desc) {
      $desc =~ s/&(?!\w+;)/&amp;/g;
      $desc =~ s/href="?([^"]+?)"?([ >])/href="$1"$2/g;
      $desc =~ s/<a>/<\/a>/g;
      $desc =~ s/"[ "]*>/">/g;
      $desc = qq{<div class="desc">$desc</div>};
      
      $help = qq{<span class="menu_help"></span>};
    }
    
    $node->set_attribute('class', "leaf $external");
    $node->inner_HTML(qq{
      <ul class="popup_menu">$menu</ul>
      $selected<span class="menu_option">$icons$name</span>
      $fg_link
      $help
      $desc
    });
    
    $self->{'select_all_menu'}->{$node->parent_node->id} = $menu unless $external;
    
    return $menu unless $external;
  }
  
  return undef;
}

# FIXME: HACKHACKHACKHACKHACKHACKHACKHACKHACKHACKHACKHACKHACKHACKHACKHACKHACKHACKHACKHACK
sub multiwiggle_multi_link {
  my ($self, $image_config) = @_;
  
  my $action = $image_config->{'type'} eq 'reg_detail_by_cell_line' ? 'Regulation' : 'Location';
  my $config = $action eq 'Location' ? 'cell_page' : '_page';
  
  my $config_link = $image_config->hub->url({
    type     => 'Config',
    action   => $action,
    function => 'Cell_line',
    config   => $config
  });

  $config = 'page' if $config eq '_page'; # FIXME: make it config=page normally!
  
  return qq{<a href="$config_link" class="modal_link" rel="modal_config_$config" title="Configure this page">Configure Cell/Tissue</a>};
}

sub add_reset_panel {
  my ($self, $controller, $title, $action, $config) = @_;
  
  my $panel = $self->new_panel('Configurator', $controller, code => 'x');
  
  my $url = $controller->hub->url({ 
    type   => 'Config',
    action => $action,
    config => $config =~ /(cell)?_page/ ? '' : $config,
    reset  => 1
  });
  
  $config = 'page' if $config eq '_page'; # FIXME: make it config=page normally!
  
  my $html = sprintf('
    <p>
      To update this configuration, select your tracks and other options in the box above and close
      this popup window. Your view will then be updated automatically.
    </p>
    <p>
      <a class="modal_link" href="%s" rel="modal_config_%s">Reset configuration for %s to default settings</a>.
    </p>', 
    $url, lc $config, encode_entities($title) || 'this page'
  );

  if ($title) {
    my $img_url = $controller->img_url;
    
    $html .= qq{
    <p>
      Notes:
    </p>
    <ul>
      <li>
        To change whether a track is drawn OR how it is drawn, click on the icon by the track name and
        then select the way the track is to be rendered.
      </li>
      <li>
        On the left hand side of the page the number of tracks in a menu, and the number of tracks
        currently turned on from that menu are shown by the two numbers in parentheses <span style="white-space:nowrap">(tracks on/total tracks)</span>.
      </li>
      <li>
        <p>
        Certain tracks displayed come from user-supplied or external data sources, these are clearly marked as 
        <img src="${img_url}track-das.gif" alt="DAS" style="vertical-align:top; width:40px;height:16px" title="DAS" /> (Distributed Annotation Sources), 
        <img src="${img_url}track-url.gif" alt="URL" style="vertical-align:top; width:40px;height:16px" title="URL" /> (UCSC style web resources) or 
        <img src="${img_url}track-bam.gif" alt="URL" style="vertical-align:top; width:40px;height:16px" title="URL" /> (Binary Alignment/Map) or 
        <img src="${img_url}track-user.gif" alt="User" style="vertical-align:top; width:40px;height:16px" title="User" /> data uploaded by yourself or another user.
        </p>
        <p>
        Please note that the content of these tracks is not the responsibility of the Ensembl project.
        </p>
        <p>In the case of URL based or DAS tracks may either slow down your ensembl browsing experience OR may be unavailable as these are served and stored from other servers elsewhere on the Internet.
        </p>
      </li>
    </ul>};
  }
  
  $panel->set_content($html);
  $self->add_panel($panel);
}

1;
