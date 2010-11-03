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
  my $image_config;
  
  if ($view_config && $view_config->has_form) {
    $view_config->form($controller->object);
    $view_config->get_form->{'_attributes'}{'action'} = $url->[0];
    $view_config->add_form_element({ type => 'Hidden', name => $_, value => $url->[1]->{$_} }) for keys %{$url->[1]};
    
    # hack to display help message for Cell line configuration on region in detail
    if ($view_config->type eq 'Location' && $view_config->action eq 'Cell_line') {
      my $info_panel = $self->new_panel('Configurator', $controller, code => 'configurator_info');
      
      my $configuration_link = $hub->url({
        type     => 'Config',
        action   => 'Location',
        function => 'View',
        config   => 'contigviewbottom'
       });
       
      $info_panel->set_content(qq{
        <div class="info">
          <h3>Note:</h3>
          <div class ="error-pad">
          <p>
            Any cell lines that you configure here must also be turned on in the 
            <a href="$configuration_link#functional" class="modal_link" rel="modal_config_contigviewbottom" title="Configure this page">functional genomics</a> 
            section of the "Main Panel" tab before any data will be displayed.
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
  } else {
    ($image_config) = sort keys %{$view_config->image_configs || {}};
  }
  
  return $image_config ? $hub->get_imageconfig($image_config) : undef;
}

sub init_imageconfig {
  my $self          = shift;
  my $controller    = shift;
  my $image_config  = shift;
  my $url           = shift;
  my $configuration = $controller->configuration;
  
  $configuration->create_node('active_tracks',  'Active tracks',  [], { availability => 1, url => '#', class => 'active_tracks'           });
  $configuration->create_node('search_results', 'Search Results', [], { availability => 1, url => '#', class => 'search_results disabled' });
    
  my $search_panel = $self->new_panel('Configurator', $controller, code => 'configurator_search');
  my $panel        = $self->new_panel('Configurator', $controller, code => 'configurator');
  
  $search_panel->set_content('<div class="configuration_search">Search display: <input class="configuration_search_text" /></div>');
  
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
    $self->imageconfig_content($controller, $image_config)
  ));
  
  $self->add_panel($search_panel);
  $self->add_panel($panel);
  
  $self->tree    = $configuration->tree;
  $self->active  = 'active_tracks';
  $self->caption = $image_config->get_parameter('title');
}

sub imageconfig_content {
  my $self          = shift;
  my $controller    = shift;
  my $image_config  = shift;
  my $hub           = $controller->hub;
  my $configuration = $controller->configuration;
  my $content;
  
  foreach my $node ($image_config->tree->top_level) {
    next unless $node->get('caption');
    next if $node->is_leaf;
    
    my $count     = 0;
    my $ext_count = 0;
    my $available = 0;
    my $on        = 0;
    my $key       = $node->key;
    my (%renderers, $select_all_menu, $config_group, $submenu);
    
    foreach my $track_node ($node->descendants) {
      next if $track_node->get('menu') eq 'no';
      
      my $display = $track_node->get('display') || 'off';
      my @states  = @{$track_node->get('renderers') || [ qw(off Off normal Normal) ]};
      my $desc    = $track_node->get('description');
      my $class   = $track_node->get('_class');
      my $name    = encode_entities($track_node->get('name')); 
      my ($dd, $selected, $menu, $external_menu, $pre_config_group);
      
      if ($track_node->get('submenu')) {
        $submenu          = $track_node->get('caption');
        $pre_config_group = '</dl><dl class="config_menu submenu">' if $config_group;
      } else {
        $name = sprintf '<img src="/i/track-%s.gif" style="width:40px;height:16px" title="%s" alt="[%s]" /> %s', lc $class, $class, $class, $name if $class;   
        
        while (my ($val, $text) = splice @states, 0, 2) {
          $text     = encode_entities($text);
          $selected = sprintf '<input type="hidden" name="%s" value="%s" /><img title="%s" alt="%s" src="/i/render/%s.gif" class="menu_option" />', $track_node->key, $val, $text, $text, $val if $val eq $display;
          $text     = qq{<li class="$val"><img title="$text" alt="$text" src="/i/render/$val.gif" class="$key" />$text</li>};
          
          if ($class) {
            $external_menu .= $text;
          } else {
            $menu .= $text;
            $renderers{$val}++;
          }
        }
        
        $count++;
        $on++ if $display ne 'off';
        $ext_count++ if $class;
        $select_all_menu ||= $menu;
        $class = (lc $class || 'internal') .' '. $track_node->get('class');
        $pre_config_group = '</dl><dl class="config_menu submenu"><dt class="external">External data sources</dt>' if $ext_count == 1;


        
        if ($desc) {
          $desc =~ s/&(?!\w+;)/&amp;/g;
          $desc =~ s/href="?([^"]+?)"?([ >])/href="$1"$2/g;
          $desc =~ s/<a>/<\/a>/g;
          $desc =~ s/"[ "]*>/">/g;
          
          $selected = qq{<span class="menu_help">Show info</span>$selected};
          $dd       = "<dd>$desc</dd>";
        }

        if ($submenu && $submenu != 1) {
          $pre_config_group = $self->build_enable_all_menu($submenu, $key, $select_all_menu, $controller, %renderers);
          $submenu          = 1;
        }
      }
      
      $config_group .= $pre_config_group;
              
      if ($name) {
        my $action = $image_config->{'type'} eq 'reg_detail_by_cell_line' ? 'Regulation' : 'Location';
        my $config = $action eq 'Location' ? 'cell_page' : '_page';
        
        my $config_link = $hub->url({
          type     => 'Config',
          action   => $action,
          function => 'Cell_line',
          config   => $config
        });

        $config = 'page' if $config eq '_page'; # FIXME: make it config=page normally!

	#though you might be tempted, do not revert this as a sprintf (one of the track names is '%GC')
	my $multiwiggle_multi_link =  $track_node->get('glyphset') eq 'fg_multi_wiggle' ? qq{<a href="$config_link" class="modal_link" rel="modal_config_$config" title="Configure this page">Configure Cell/Tissue</a>} : '';
        $config_group .= qq{
          <dt class="$class">
            <ul class="popup_menu">$menu$external_menu</ul>
            $selected <span class="menu_option">$name</span>
            $multiwiggle_multi_link
          </dt>
          $dd
        };
      }
    }
    
    $config_group = $self->build_enable_all_menu('tracks', $key, $select_all_menu, $controller, %renderers) . $config_group if !$submenu && $count - $ext_count > 1;
    
    $content .= sprintf('
      <div class="config %s">
        <h2>%s</h2>
        <dl class="config_menu">
          %s
        </dl>
      </div>', 
      $key, encode_entities($node->get('caption')), $config_group
    );
    
    $configuration->create_node($key,
      ( $count ? "($on/$count) " : '' ) . $node->get('caption'),
      [],
      { url => '#', availability => ($count > 0), class => $node->key } 
    );
  }
  
  return $content;
}

sub build_enable_all_menu {
  my ($self, $label, $key, $menu, $controller, %renderers) = @_;
  
  my %counts = reverse %renderers;
  
  if (scalar keys %counts != 1) {
    $menu  = '';
    $menu .= qq{<li class="$_->[2]"><img title="$_->[1]" alt="$_->[1]" src="/i/render/$_->[0].gif" class="$key" />$_->[1]</li>} for [ 'off', 'Off', 'off' ], [ 'normal', 'On', 'all_on' ];
  }
  
  return qq{
    <dt class="select_all">
      <ul class="popup_menu">$menu</ul>
      <img title="Enable/disable all" alt="Enable/disable all" src="/i/render/off.gif" class="menu_option" /> <strong class="menu_option">Enable/disable all $label</strong>
    </dt>
  };
}

sub add_reset_panel {
  my ($self, $controller, $title, $action, $config) = @_;
  
  my $panel = $self->new_panel('Configurator', $controller, code => 'x');
  
  my $url = $controller->hub->url({ 
    type   => 'Config',
    action => $action,
    config => $config,
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
    $html .= '
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
        Certain tracks displayed come from user-supplied or external data sources, these are clearly
        marked as <strong><img src="/i/track-das.gif" alt="DAS" style="vertical-align:top; width:40px;height:16px" title="DAS" /></strong> (Distributed Annotation Sources), 
        <strong><img src="/i/track-url.gif" alt="URL" style="vertical-align:top; width:40px;height:16px" title="URL" /></strong> (UCSC style web resources) or 
        <strong><img src="/i/track-user.gif" alt="User" style="vertical-align:top; width:40px;height:16px" title="User" /></strong> data uploaded by
        yourself or another user.
        </p>
        <p>
        Please note that the content of these tracks is not the responsibility of the Ensembl project.
        </p>
        <p>In the case of URL based or DAS tracks may either slow down your ensembl browsing experience OR may be unavailable as these are served and stored from other servers elsewhere on the Internet.
        </p>
      </li>
    </ul>';
  }
  
  $panel->set_content($html);
  $self->add_panel($panel);
}

1;
