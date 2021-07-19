=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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
    my $id    = lc $entry->{'id'};
    $panels  .= qq(<div id="modal_$id" class="modal_content js_panel $entry->{'class'}" style="display:none"></div>);
    $content .= sprintf '<li><a class="modal_%s" href="%s">%s</a></li>', $id, $entry->{'url'} || '#', encode_entities($self->strip_HTML($entry->{'caption'}));
  }
  
  $content = qq(
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
    <div id="modal_default" class="modal_content js_panel fixed_width" style="display:none"></div>
    <div class="modal_overlay"><img class="overlay_close" title="Cancel" alt="close" src="${img_url}close.png" /><div class="overlay_content"></div></div>
    <div class="modal_overlay_bg"></div>
  </div>
  );
  
  return $content;
}

sub init {
  my $self       = shift;
  my $controller = shift;
  my $hub        = $controller->hub;
  my $components = $hub->components;
  my (%done, @extra);
  
  foreach (@$components) {
    my $component = $_->[0];
    my $type      = $_->[1];
    
    next if $done{$component};
    
    my $view_config = $hub->get_viewconfig({component => $component, type => $type});

    if ($view_config) {
      $self->add_entry({
        id      => "config_$component",
        caption => 'Configure ' . (scalar @$components > 1 ? $view_config->title : '' || 'Page'),
        url     => $hub->url('Config', {
          type      => $type,
          action    => $component,
          function  => undef
        })
      });

      foreach ($view_config->extra_tabs) {
        (my $id = $_->[0]) =~ s/ /_/g;

        push @extra, {
          id      => $id,
          class   => 'fixed_width',
          caption => $_->[0],
          url     => $_->[1]
        };
      }

      $done{$component} = 1;
    }
  }
  
  $self->add_entry(@extra);
  
  $self->add_entry({
    id      => 'user_data',
    class   => 'fixed_width',
    caption => 'Personal Data',
    url     => $hub->url({
       type    => 'UserData',
       action  => 'ManageData',
       time    => time,
       __clear => 1
     })
  });
}
1;
