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

package EnsEMBL::Web::Command::UserData::SaveExtraConfig;

use strict;

use EnsEMBL::Web::Root;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self     = shift;
  my $hub      = $self->hub;
  my $object   = $self->object;
  my $session  = $hub->session;
  my $redirect = $hub->species_path($hub->data_species) . '/UserData/RemoteFeedback';
  my $param    = {};
  my $code     = $hub->param('code');
  my $type     = $hub->param('record_type');

  my $data = $session->get_record_data({type => $type, code => $code});

  $data->{'colour'} = $hub->param('colour');
  $data->{'y_max'}  = $hub->param('y_max');
  $data->{'y_min'}  = $hub->param('y_min');
  $session->set_record_data($data);

  $self->ajax_redirect($redirect, $param);  
}

1;
