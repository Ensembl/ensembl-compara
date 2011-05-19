# $Id$

package EnsEMBL::Web::Document::Element::Modal;

# Generates the modal context navigation menu, used in dynamic pages

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Document::Element);

sub add_entry {
  my $self = shift;
  push @{$self->{'_entries'}}, @_;
}

sub entries {
  my $self = shift;
  return $self->{'_entries'} || [];
}

sub active {
  my $self = shift;
  $self->{'_active'} = shift if @_;
  return $self->{'_active'};
}

sub content {
  my $self    = shift; 
  my $img_url = $self->img_url;
  my ($panels, $content, $default);
  
  foreach my $entry (@{$self->entries}) {
    my $id = lc $entry->{'id'};
    
    if ($entry->{'type'} ne 'Config') {
      next if $default;
      $default = 1;
      $id      = 'default';
    }
    
    $panels  .= qq{<div id="modal_$id" class="modal_content js_panel" style="display:none"></div>};
    $content .= sprintf '<li class="%s"><a class="modal_%s" href="%s">%s</a></li>', $entry->{'class'}, $id, $entry->{'url'} || '#', encode_entities($self->strip_HTML($entry->{'caption'}));
  }
  
  $content = qq{
  <div id="modal_bg"></div>
  <div id="modal_panel" class="js_panel">
    <input type="hidden" class="panel_type" value="ModalContainer" />
    <div class="modal_title">
      <ul class="tabs">
        $content
      </ul>
      <div class="modal_caption"></div>
      <div class="modal_close"></div>
    </div>
    $panels
  </div>
  };
  
  return $content;
}

sub init {
  my $self       = shift;
  my $controller = shift;
  my $hub        = $controller->hub;
  my %done;
  
  foreach my $component (@{$hub->components}) {
    my $view_config = $hub->get_viewconfig($component);
    
    if ($view_config && !$done{$component}) {
      $self->add_entry({
        type    => 'Config',
        id      => "config_$component",
        caption => 'Configure ' . ($view_config->title || 'Page'),
        url     => $hub->url('Config', {
          action    => $component,
          function  => undef
        })
      });
      
      $done{$component} = 1;
    }
  }
  
  $self->add_entry({
    type    => 'UserData',
    id      => 'user_data',
    caption => 'Custom Data',
     url    => $hub->url({
       type    => 'UserData',
       action  => 'ManageData',
       time    => time,
       __clear => 1
     })
  });
}

1;
