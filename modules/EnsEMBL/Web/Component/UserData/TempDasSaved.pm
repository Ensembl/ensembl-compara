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

package EnsEMBL::Web::Component::UserData::TempDasSaved;

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
  return 'Sources Saved';
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my $form = $self->modal_form('ok_tempdas', '');

  if ($self->object->param('source')) {
    $form->add_element('type'=>'Information', 'value' => 'The DAS source details were saved to your user account.');
  }

  if ($self->object->param('url')) {
    $form->add_element('type'=>'Information', 'value' => 'The data URL was saved to your user account.');
  }
  $form->add_element('type'=>'Information', 'value' => "Click on 'Manage Data' in the lefthand menu to see all your saved URLs and DAS sources");

  $form->add_element( 'type' => 'ForceReload' );

  return $form->render;
}

1;
