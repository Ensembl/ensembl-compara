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

package EnsEMBL::Web::Component::Transcript::ExternalData;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub caption {
  return undef;
}

sub content {
  my $self = shift;
  
  my $translation = $self->object->translation_object;
  if ( !$translation ) {
    my $msg = 'This transcript does not have a protein product. External data '.
              'is only supported for proteins.';
    return $self->_error( 'No protein product', $msg, '100%' );
  }
  
  my $msg = $self->config_msg;

  #my $msg = "Click 'configure this page' to change the sources of external ".
  #           "annotations that are available in the External Data menu.";
  return $self->_info('Info',"<p>$msg</p>", '100%');
}

1;

