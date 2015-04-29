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

package EnsEMBL::Web::Command::UserData::CheckServer;

use strict;
use warnings;

use EnsEMBL::Web::Filter::DAS;
use base qw(EnsEMBL::Web::Command);

sub process {
  my $self   = shift;
  my $object = $self->object;
  my $url    = $object->species_path($object->data_species) . '/UserData/';
  my $param;

  ## Catch any errors at the server end
  my $server  = $object->param('other_das') || $object->param('preconf_das');

  # Hack for cache reloading for now - special text in filter box
  if ($object->param('das_name_filter') eq 'reloadCache') {
    $object->param('das_clear_cache','1');
    $object->param('das_name_filter','');
  }

  my $filter  = EnsEMBL::Web::Filter::DAS->new({ object => $object });
  my $sources = $filter->catch($server);

  if ($sources) {
    $param->{'das_server'} = $server;
    $param->{'das_name_filter'} = $object->param('das_name_filter');
    $url .= 'DasSources';
  } else {
    $param->{'filter_module'} = 'DAS';
    $param->{'filter_code'} = $filter->error_code;
    $url .= 'SelectServer';
  }
  
  $self->ajax_redirect($url, $param);
}

1;
