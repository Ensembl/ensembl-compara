=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
  
  my $form = $self->new_form({'id' => 'url_feedback', 'method' => 'post'});

  $form->add_element(
      type  => 'Information',
      value => qq(Thank you - your remote data was successfully attached. Close this Control Panel to view your data),
    );
  $form->add_element( 'type' => 'ForceReload' );

  return $form->render;
}

1;
