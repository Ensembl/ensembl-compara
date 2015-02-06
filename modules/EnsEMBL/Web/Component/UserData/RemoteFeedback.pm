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

package EnsEMBL::Web::Component::UserData::RemoteFeedback;

use strict;
use warnings;
no warnings "uninitialized";

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

  if ($hub->param('format') eq 'DATAHUB') {
    $message = $self->get_message($hub->param('species_flag'), $hub->param('assembly_flag'));
  }
  else {
    $message = qq(Thank you - your remote data was successfully attached. Close this Control Panel to view your data);
  }

  $form->add_element(
      type  => 'Information',
      value => '<p>'.$message.'</p>', 
    );
  $form->add_element( 'type' => 'ForceReload' );

  return $form->render;
}

sub get_message {
  my ($self, $species_flag, $assembly_flag) = @_;
  my $hub         = $self->hub;
  my $species     = $hub->param('species');
  my $trackhub_ok = 0;
  my $try_archive = 0;
  my $message     = '';

  if ($assembly_flag eq 'old_only') {
    $message = 'This hub contains no data on any current assemblies. Please check our <a href="/info/website/archives/">archive list</a> for alternative sites.';
    $try_archive = 1;
  }
  elsif ($assembly_flag eq 'old_and_new') {
    ## Multiple assemblies for the chosen species (usually only seen for human)
    $message = '<strong>Your hub includes multiple assemblies, so not all features will be shown. Alternative assemblies may available on archive sites.</strong>';
    $trackhub_ok = 1;
    $try_archive = 1;
  }
  elsif ($species_flag eq 'other_only') {
    my $url = sprintf('/%s/UserData/ManageData', $species);
    $message = sprintf('<strong>Your hub contains no data on the chosen species</strong>. Please check the <a href="%s" class="modal_link">Manage Data</a> page for other species supported by this hub.</p>', $url);
  }
  else {
    $message = 'Your hub attached successfully.';
    $trackhub_ok = 1;
  }

  if ($trackhub_ok) {
    (my $menu_name = $hub->param('name')) =~ s/ /_/g;
    my $sample_data = $hub->species_defs->get_config($species, 'SAMPLE_DATA') || {};
    my $default_loc = $sample_data->{'LOCATION_PARAM'};
    my $url = $hub->url({
                          species   => $species,
                          type      => 'Location',
                          action    => 'View',
                          function  => undef,
                          r         => $hub->param('r') || $default_loc,
              });
    $message .= sprintf('</p><p><a href="%s#modal_config_viewbottom-%s">Configure your hub</a>', $url, $menu_name);
  }

  if ($try_archive) {
    my $archive_site = $hub->species_defs->get_config($species, 'SWITCH_ARCHIVE_URL');
    if ($archive_site) {
      my $assembly = $hub->species_defs->get_config($species, 'SWITCH_ASSEMBLY');
      $message .= sprintf('</p><p>If you wish to view data on assembly %s, please use archive site <a href="http://%s/%s">%s</a>.</p>', 
                            $assembly, $archive_site, $species, $archive_site,
                    );
    }
  }

  return $message;
}

1;
