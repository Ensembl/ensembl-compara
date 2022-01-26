=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

use base qw(EnsEMBL::Web::Document::Element);

use HTML::Entities qw(encode_entities);

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

sub content {
  my $self = shift;
  my $entries = $self->entries;
  
  return unless scalar @$entries;
  
  my $html;

  foreach (@$entries) {
    if (grep {$_ eq 'disabled'} split ' ', $_->{'class'}) {
      $html .= qq(<p class="$_->{'class'} $_->{'icon'}" title="$_->{'title'}">$_->{'caption'}</p>);
    } else {
      my $rel   = lc $_->{'rel'};
      my $class = join ' ', map $_ || (), $_->{'class'}, $rel eq 'external' ? 'external' : '', $_->{'icon'};
      $class    = qq{ class="$class"} if $class;
      $rel      = qq{ rel="$rel"}     if $rel;

      my $url = encode_entities($_->{'url'});
      $html .= qq(<p><a href="$url"$class$rel>$_->{'caption'}</a></p>);
    }
  }
  
  return qq{<div class="tool_buttons">$html</div>};
}

sub init {
  my $self       = shift;  
  my $controller = shift;
  my $hub        = $self->hub;
  my $object     = $controller->object;
  my @components = @{$hub->components};
  my $session    = $hub->session;
  my $user       = $hub->user;
  my $view_config;
  while (!$view_config && scalar @components) {
    my ($component, $type) = @{shift @components};
    $view_config = $hub->get_viewconfig({component => $component, type => $type});
  }

  if ($view_config) {
    my $component = $view_config->component;
    
    $self->add_entry({
      caption => 'Configure this page',
      icon    => 'config',
      class   => 'modal_link',
      rel     => "modal_config_$component",
      url     => $hub->url('Config', {
        type      => $view_config->type,
        action    => $component,
        function  => undef,
        strain    => $hub->action =~ /Strain_/ ?  1 : 0, #once we have a better check for strain view, we can remove this dirty check
      })
    });
  } else {
    $self->add_entry({
      caption => 'Configure this page',
      icon    => 'config',
      class   => 'disabled',
      url     => undef,
      title   => 'There are no options for this page'
    });
  }
 
  ## TODO - make this more generic - but how does an Element find out
  ## about the images on the page and whether they accept userdata? 
  if ($hub->action =~ 'Prot|Domain') {
    $self->add_entry({
      caption => 'Custom tracks',
      icon    => 'data',
      class   => 'disabled',
      url     => undef,
      title   => 'Data upload is not available on this page'
    });
  }
  else {
    $self->add_entry({
      caption => 'Custom tracks',
      icon    => 'data',
      class   => 'modal_link',
      rel     => 'modal_user_data',
      url     => $hub->url({
        time    => time,
        type    => 'UserData',
        action  => 'ManageData',
        __clear => 1
      })
    });
  }
 
  if ($object && $object->can_export) {
    my $strain_param = ";strain=1" if($hub->action =~ /Strain_/); #once we have a better check for strain view, we can remove this dirty check
    my $caption = $object->can_export =~ /[A-Za-z]/ ? $object->can_export : 'Export data';
    $self->add_entry({
      caption => $caption,
      icon    => 'export',
      class   => 'modal_link',
      url     => $self->export_url($hub).$strain_param
    });
  } else {
    $self->add_entry({
      caption => 'Export data',
      icon    => 'export',
      class   => 'disabled',
      url     => undef,
      title   => 'Generic export has been disabled on this page. Check individual images, tables, etc for download buttons',
    });
  }
  
  $self->add_entry({
    caption => 'Share this page',
    icon    => 'share',
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

  if ($type eq 'Gene' && $action eq 'Sequence') {
    return $hub->url({ type => 'DataExport', action => 'GeneSeq',
                       component =>  'GeneSeq', 'data_type' => 'Gene'});
  }
  else {  
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
}

1;
