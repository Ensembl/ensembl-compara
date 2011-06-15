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
  my $self = shift;
  
  return {
    wrapper   => qq{<div class="modal_wrapper"></div>},
    content   => $self->content,
    params    => { tracks => $self->{'tracks'}, order => $self->{'track_order'} },
    panelType => $self->{'panel_type'}
  };
}

sub init {
  my $self       = shift;
  my $controller = shift;
  my $navigation = $controller->page->navigation;
  
  $self->init_config($controller);
  
  $navigation->tree($self->tree);
  $navigation->active($self->active);
  $navigation->caption($self->caption);
  $navigation->configuration(1);
  
  $self->{'panel_type'} ||= 'Configurator';
}

sub init_config {
  my ($self, $controller, $url) = @_;
  my $hub         = $controller->hub;
  my $action      = $hub->action;
  my $view_config = $hub->get_viewconfig($action);
  my $image_config;
  
  if ($view_config) {
    my $panel = $self->new_panel('Configurator', $controller, code => 'configurator');
    my $species_select;
    
    $image_config = $hub->get_imageconfig($view_config->image_config, 'configurator', $hub->species);
    
    $view_config->build_form($controller->object, $image_config);
    
    my $form = $view_config->get_form;
    
    $form->add_element(type => 'Hidden', name => 'component', value => $action, class => 'component');
    
    if ($image_config) {
      my $top_panel = $self->new_panel('Configurator', $controller, code => 'configurator_top');
    
      if ($image_config->multi_species) {
        foreach (@{$image_config->species_list}) {
          $species_select .= sprintf(
            '<option value="%s"%s>%s</option>', 
            $hub->url('Config', { species => $_->[0], __clear => 1 }), 
            $hub->species eq $_->[0] ? ' selected="selected"' : '',
            $_->[1]
          );
        }
        
        if ($image_config->get_parameter('global_options')) {
          $species_select .= sprintf(
            '<option value="">-----</option><option value="%s"%s>All species</option>', 
            $hub->url('Config', { species => 'Multi', __clear => 1 }),
            $hub->species eq 'Multi' ? ' selected="selected"' : ''
          );
        }
        
        $species_select = qq{<div style="float:left">Select species: <select class="species">$species_select</select></div>} if $species_select;
      }
      
      $top_panel->set_content(qq{$species_select<div class="configuration_search"><input class="configuration_search_text" value="Find a track" /></div>});
      $self->add_panel($top_panel);
      $self->active = $image_config->get_parameter('active_menu') || 'active_tracks';
    }
    
    if (!$view_config->tree->get_node($self->active)) {
      my @nodes     = @{$view_config->tree->child_nodes};
      $self->active = undef;
      
      while (!$self->active && scalar @nodes) {
        my $node      = shift @nodes;
        $self->active = $node->id if $node->data->{'class'};
      }
    }
    
    if ($hub->param('partial')) {
      $panel->{'content'}   = join '', map $_->render, @{$form->child_nodes};
      $self->{'panel_type'} = $view_config->{'panel_type'} if $view_config->{'panel_type'};
    } else {
      $panel->set_content($form->render);
    }
    
    $self->add_panel($panel);
    
    $self->tree    = $view_config->tree;
    $self->caption = 'Configure view';
    
    $self->{$_} = $view_config->{$_} || {} for qw(tracks track_order);
  }
  
  $self->add_image_config_notes($controller) if $view_config->has_images;
}

sub add_image_config_notes {
  my ($self, $controller) = @_;
  my $panel   = $self->new_panel('Configurator', $controller, code => 'x', class => 'image_config_notes' );
  my $img_url = $controller->img_url;
  
  $panel->set_content(qq{
<p class="space-below"><strong>Key</strong>:</p>
<p class="space-below"><img src="/i/render/normal.gif" class="middle" /> Track style</p>
<p class="space-below"><img src="/i/strand-f.png" class="middle" /> Forward strand</p>
<p class="space-below"><img src="/i/strand-r.png" class="middle" /> Reverse strand</p>
<p class="space-below"><img src="/i/star-on.png" class="middle" /> Favourite track</p>
<p class="space-below"><img src="/i/info_blue_17.png" class="middle" /> Track information</p>
<p class="space-below"><strong>External tracks</strong></p>
<p class="space-below"><img src="/i/track-das.gif" class="middle" /> Distributed Annotation Source</p>
<p class="space-below"><img src="/i/track-tmp.gif" class="middle" /> Custom track - uploaded data</p>
<p class="space-below"><img src="/i/track-url.gif" class="middle" /> Custom track - UCSC-style web resource</p>
<p class="space-below"><img src="/i/track-user.gif" class="middle" /> Custom data saved to your user account</p>
<p class="space-below">Please note that the content of external tracks is not the responsibility of the Ensembl project.</p>
<p>URL-based or DAS tracks may either slow down your ensembl browsing experience OR may be unavailable as these are served and stored from other servers elsewhere on the Internet.</p>
  });

  $self->add_panel($panel);
}

1;
