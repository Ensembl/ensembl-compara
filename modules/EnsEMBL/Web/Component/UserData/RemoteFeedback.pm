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

package EnsEMBL::Web::Component::UserData::RemoteFeedback;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Constants;
use EnsEMBL::Web::Utils::Sanitize qw(clean_id);

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return 'URL attached';
}

sub content {
  my $self = shift;
  my $hub = $self->hub;
  
  my $form = $self->new_form({'id' => 'url_feedback', 'method' => 'post'});
  my $message;

  if ($hub->param('format') eq 'TRACKHUB') {
    $message = $self->get_message;
  }
  else {
    $message = qq(<p>Thank you - your remote data was successfully attached. Close this Control Panel to view your data</p>);
  }

  $form->add_element(
      type  => 'Information',
      value => $message, 
    );
  $form->add_element( 'type' => 'ForceReload' );

  return $form->render;
}

sub get_message {
  my $self  = shift;
  my $hub   = $self->hub;

  my $species_flag  = $hub->param('species_flag');
  my $assembly_flag = $hub->param('assembly_flag');
  my $species       = $hub->param('species') || $hub->species;
  my $reattach      = $hub->param('reattach');
  my %messages      = EnsEMBL::Web::Constants::USERDATA_MESSAGES;
  my $trackhub_ok   = 1;
  my $try_archive   = 0;
  my $message       = '';

  if ($assembly_flag) {
    $message = sprintf('<p><strong>%s</strong>', $messages{'hub_'.$assembly_flag}{'message'});
    if ($assembly_flag eq 'old_only') {
      $trackhub_ok = 0;
      $try_archive = 1;
    }
    elsif ($assembly_flag eq 'old_and_new') {
      $try_archive = 1;
    }
    elsif ($species_flag eq 'other_only') {
      $trackhub_ok = 0;
      my $url = sprintf('/%s/UserData/ManageData', $species);
      $message .= sprintf('Please check the <a href="%s" class="modal_link">Manage Data</a> page for other species supported by this hub.', $url);
    }
    $message .= '</p>';
  }
  elsif ($reattach) {
    $message = $messages{'hub_'.$reattach}{'message'};
    ## Internally configured hub
    if ($reattach eq 'preconfig') {
      $trackhub_ok = 0;
      my $link = $hub->url({'type' => 'Config', 'action' => 'Location', 'function' => 'ViewBottom'});
      my $menu = $hub->param('menu') || '';
      $message .= sprintf(' Tracks can be found in the <a class="modal_link" rel="modal_config_viewbottom%s%s" href="%s">Region in Detail configuration options</a>', $menu ? '-' : '', $menu, $link);
      $message = $self->info_panel('Note', $message);
    }
  }
  else {
    $message = $messages{'hub_ok'}{'message'};
  }

  my $page_action = $hub->referer->{'ENSEMBL_ACTION'};
  my $sample_data = $hub->species_defs->get_config($species, 'SAMPLE_DATA') || {};
  my $default_loc = $sample_data->{'LOCATION_PARAM'};
  my $current_loc = $hub->referer->{'params'}->{'r'}[0];
  my $params = {
                  species   => $species,
                  type      => 'Location',
                  action    => $page_action,
                  function  => undef,
                  r         => $current_loc || $default_loc,
                };

  ## We should only reach this step if the trackhub has a mixture of available species/assemblies 
  ## and unavailable ones, and therefore we want to warn the user before proceeding
  if ($try_archive) {
    my $archive_site = $hub->species_defs->get_config($species, 'SWITCH_ARCHIVE_URL');
    if ($archive_site) {
      my $assembly = $hub->species_defs->get_config($species, 'SWITCH_ASSEMBLY');
      $message .= sprintf('</p><p>If you wish to view data on assembly %s, please use archive site <a href="//%s/%s">%s</a>.</p>', 
                            $assembly, $archive_site, $species, $archive_site,
                    );
    }
  }

  my $position = $hub->param('position');
  if ($position) {
    $params->{'r'}  = $position;
    my $url         = $hub->url($params); 
    $message       .= sprintf '<p><a href="%s">Go to default location: %s</a>', $url, $position; 
  }

  return $message;
}

1;
