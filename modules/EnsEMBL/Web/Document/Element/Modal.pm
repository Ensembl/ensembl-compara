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
  my ($panels, $content);
  
  foreach my $entry (@{$self->entries}) {
    $entry->{'url'} ||= '#';
    
    my $id   = 'modal_' . lc($entry->{'id'} || $entry->{'type'});
    my $name = encode_entities($self->strip_HTML($entry->{'caption'}));
    
    if ($id =~ /config/) {
      $name    = qq{<a rel="$id" href="$entry->{'url'}">$name</a>};
      $panels .= qq{<div id="$id" class="modal_content js_panel" style="display:none"></div>};
    } else {
      $name = qq{<a href="$entry->{'url'}">$name</a>};
    }
    
    $content .= qq{<li class="$entry->{'class'}">$name</li>};
  }
  
  $content = qq{
  <div id="modal_bg"></div>
  <div id="modal_border"></div>
  <div id="modal_panel" class="js_panel">
    <input type="hidden" class="panel_type" value="ModalContainer" />
    <div class="modal_title">
      <ul class="tabs">
        $content
      </ul>
      <div class="modal_caption"></div>
      <img class="modal_close" src="${img_url}cp_close.png" alt="Save and close" title="Save and close" />
    </div>
    $panels
    <div id="modal_default" class="modal_content js_panel" style="display:none"></div>
  </div>
  };
  
  return $content;
}

sub init {
  my $self        = shift;
  my $controller  = shift;
  my $hub         = $controller->hub;
  my $view_config = $controller->view_config;
  my $type        = $hub->type;
  
  if ($view_config) {
    my $action        = join '/', grep $_, $type, $hub->action, $hub->function;
    my %image_configs = $view_config ? $view_config->image_configs : undef;
    
    if ($view_config->has_form) {
      $self->add_entry({
        type    => 'Config',
        id      => 'config_page',
        caption => 'Configure page',
        url     => $hub->url({
          time   => time, 
          type   => 'Config',
          action => $action,
          config => '_page'
        })
      });
    }
  
    foreach my $code (sort keys %image_configs) {
      my $image_config = $hub->get_imageconfig($code);
      
      $self->add_entry({
        type    => 'Config',
        id      => "config_$code",
        caption => $image_config->get_parameter('title'),
        url     => $hub->url({
          time   => time, 
          type   => 'Config',
          action => $action,
          config => $code
        })
      });
    }
    
    # FIXME: Hack to add Cell/Tissue config for Region in Detail
    if ($action =~ /^Location\/(View|Cell_line)$/ && keys %{$hub->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'}{'cell_type'}{'ids'}}) {      
      $self->add_entry({
        type    => 'Config',
        id      => 'config_cell_page',
        caption => 'Cell/Tissue',
        url     => $hub->url({
          time   => time,
          type   => 'Config',
          action => 'Location/Cell_line',
          config => 'cell_page'
        })
      });
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
