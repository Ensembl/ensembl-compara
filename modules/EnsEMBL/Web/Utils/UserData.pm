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

package EnsEMBL::Web::Utils::UserData;

use EnsEMBL::Web::ImageConfig;
use EnsEMBL::Web::Utils::Sanitize qw(clean_id);

use base qw(Exporter);

our @EXPORT = our @EXPORT_OK = qw(check_attachment);

sub check_attachment {
### Check if a URL-based data file is already attached to the session
  my ($hub, $url) = @_;
  my $species_defs = $hub->species_defs;

  my $already_attached = 0;
  my ($redirect, $params, $menu);

  ## Check for pre-configured hubs
  my %preconfigured = %{$species_defs->ENSEMBL_INTERNAL_TRACKHUB_SOURCES||{}};
  while (my($k, $v) = each (%preconfigured)) {
    my $hub_info = $species_defs->get_config($hub->species, $k);
    if ($hub_info->{'url'} eq $url) {
      $already_attached = 'preconfig';
      ## Probably a submenu, so get full id
      my $menu_tree = EnsEMBL::Web::ImageConfig::menus({});
      my $menu_settings = $menu_tree->{$v};
      if (ref($menu_settings) eq 'ARRAY') {
        $menu = $menu_settings->[1].'-'.$v;
      }
      else {
        $menu = $v;
      }
      last;
    }
  }

  ## Check user's own data
  unless ($already_attached) {
    my @attachments = $hub->session->get_records_data({'type' => 'url'});
    foreach (@attachments) {
      if ($_->{'url'} eq $url) {
        $already_attached = 'user';
        $menu = clean_id($_->{'name'});
        last;
      }
    }
  }

  if ($already_attached) {
    $redirect = 'RemoteFeedback';
    $params = {'format' => 'TRACKHUB', 'reattach' => $already_attached};
    $params->{'menu'} = $menu if $menu;
  }

  return ($redirect, $params);
}

1;
