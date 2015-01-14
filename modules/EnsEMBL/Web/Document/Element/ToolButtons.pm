=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Document::Element::ToolButtons;

# Generates the tools buttons below the left menu - configuration, data export, etc.

use strict;

use URI::Escape qw(uri_escape);

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
    'Add your data'       => 'data',
    'Export data'         => 'export',
    'Bookmark this page'  => 'bookmark',
    'Share this page'     => 'share',
  };
}

sub content {
  my $self = shift;
  my $entries = $self->entries;
  
  return unless scalar @$entries;
  
  my $classes = $self->label_classes;
  my $html;

  foreach (@$entries) {
    if (grep {$_ eq 'disabled'} split ' ', $_->{'class'}) {
      $html .= qq(<p class="$_->{'class'} $classes->{$_->{'caption'}}" title="$_->{'title'}">$_->{'caption'}</p>);
    } else {
      my $rel   = lc $_->{'rel'};
      my $class = join ' ', map $_ || (), $_->{'class'}, $rel eq 'external' ? 'external' : '', $classes->{$_->{'caption'}};
      $class    = qq{ class="$class"} if $class;
      $rel      = qq{ rel="$rel"}     if $rel;

      $html .= qq(<p><a href="$_->{'url'}"$class$rel>$_->{'caption'}</a></p>);
    }
  }
  
  return qq{<div class="tool_buttons">$html</div>};
}

sub init {
  my $self       = shift;  
  my $controller = shift;
  my $hub        = $controller->hub;
  my $object     = $controller->object;
  my @components = @{$hub->components};
  my $session    = $hub->session;
  my $user       = $hub->user;
  my $has_data   = grep($session->get_data(type => $_), qw (upload url das)) || ($user && (grep $user->get_records($_), qw(uploads urls dases)));
  my $view_config;
     $view_config = $hub->get_viewconfig(@{shift @components}) while !$view_config && scalar @components; 
  
  if ($view_config) {
    my $component = $view_config->component;
    
    $self->add_entry({
      caption => 'Configure this page',
      class   => 'modal_link',
      rel     => "modal_config_$component",
      url     => $hub->url('Config', {
        type      => $view_config->type,
        action    => $component,
        function  => undef,
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
    caption => $has_data ? 'Manage your data' : 'Add your data',
    class   => 'modal_link',
    rel     => 'modal_user_data',
    url     => $hub->url({
      time    => time,
      type    => 'UserData',
      action  => $has_data ? 'ManageData' : 'SelectFile',
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
      title   => 'Generic export has been disabled on this page. Check individual images, tables, etc for download buttons',
    });
  }
  
  if ($hub->user) {
    my $title = $controller->page->title;
    
    $self->add_entry({
      caption => 'Bookmark this page',
      class   => 'modal_link',
      url     => $hub->url({
        type        => 'Account',
        action      => 'Bookmark/Add',
        __clear     => 1,
        name        => uri_escape($title->get_short),
        description => uri_escape($title->get),
        url         => uri_escape($hub->species_defs->ENSEMBL_BASE_URL . $hub->url)
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
  
  $self->add_entry({
    caption => 'Share this page',
    url     => $hub->url('Share', {
      __clear => 1,
      create  => 1,
      time    => time
    })
  });
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
