# $Id$

package EnsEMBL::Web::Document::Element::ToolButtons;

# Generates the tools buttons below the left menu - configuration, data export, etc.

use strict;

use base qw(EnsEMBL::Web::Document::Element);

sub entries {
  my $self = shift;
  return $self->{'_entries'} || [];
}

sub add_entry {
  my $self = shift;
  push @{$self->{'_entries'}}, @_;
}

sub get_json {
  my $self = shift;
  return { tools => $self->content };
} 

sub label_classes {
  return {
    'Configure this page' => 'config',
    'Manage your data'    => 'data',
    'Export data'         => 'export',
    'Bookmark this page'  => 'bookmark'
  };
}

sub content {
  my $self = shift;
  my $entries = $self->entries;
  
  return unless scalar @$entries;
  
  my $classes = $self->label_classes;
  my $html;

  foreach (@$entries) {
    if ($_->{'class'} eq 'disabled') {
      $html .= qq{<p class="disabled $classes->{$_->{'caption'}}" title="$_->{'title'}">$_->{'caption'}</p>};
    } else {
      my $rel   = lc $_->{'rel'};
      my $class = join ' ', map $_ || (), $_->{'class'}, $rel eq 'external' ? 'external' : '', $classes->{$_->{'caption'}};
      $class    = qq{ class="$class"} if $class;
      $rel      = qq{ rel="$rel"}     if $rel;

      $html .= qq{<p><a href="$_->{'url'}"$class$rel>$_->{'caption'}</a></p>};
    }
  }
  
  return qq{<div class="tool_buttons">$html</div>};
}

sub init {
  my $self        = shift;  
  my $controller  = shift;
  my $hub         = $controller->hub;
  my $object      = $controller->object;
  my $view_config = $controller->view_config;
  my $config      = $view_config && $view_config->real ? $view_config->default_config : undef;
  
  if ($config) {
    my $action = join '/', map $hub->$_ || (), qw(type action function);
    (my $rel   = $config) =~ s/^_//;
    
    $self->add_entry({
      caption => 'Configure this page',
      class   => 'modal_link',
      rel     => "modal_config_$rel",
      url     => $hub->url({ 
        time   => time, 
        type   => 'Config', 
        action => $action,
        config => $config
      })
    });
  } else {
    $self->add_entry({
      caption => 'Configure this page',
      class   => 'disabled',
      url     => undef,
      title   => 'There are no options for this page'
    });
  }
  
  $self->add_entry({
    caption => 'Manage your data',
    class   => 'modal_link',
    url     => $hub->url({
      time    => time,
      type    => 'UserData',
      action  => 'ManageData',
      __clear => 1 
    })
  });
  
  if ($object && $object->can_export) {       
    $self->add_entry({
      caption => 'Export data',
      class   => 'modal_link',
      url     => $self->export_url($hub)
    });
  } else {
    $self->add_entry({
      caption => 'Export data',
      class   => 'disabled',
      url     => undef,
      title   => 'You cannot export data from this page'
    });
  }
  
  if ($hub->user) {
    my $title = $controller->page->title;
    
    $self->add_entry({
      caption => 'Bookmark this page',
      class   => 'modal_link',
      url     => $hub->url({
        type      => 'Account',
        action    => 'Bookmark/Add',
        __clear   => 1,
        name      => $title->get,
        shortname => $title->get_short,
        url       => $hub->species_defs->ENSEMBL_BASE_URL . $hub->url
      })
    });
  } else {
    $self->add_entry({
      caption => 'Bookmark this page',
      class   => 'disabled',
      url     => undef,
      title   => 'You must be logged in to bookmark pages'
    });
  } 
}

sub export_url {
  my $self   = shift;
  my $hub    = shift;
  my $type   = $hub->type;
  my $action = $hub->action;
  my $export;
  
  if ($type eq 'Location' && $action eq 'LD') {
    $export = 'LDFormats';
  } elsif ($type eq 'Transcript' && $action eq 'Population') {
    $export = 'PopulationFormats';
  } elsif ($action eq 'Compara_Alignments') {
    $export = 'Alignments';
  } else {
    $export = 'Configure';
  }
  
  return $hub->url({ type => 'Export', action => $export, function => $type });
}

1;
