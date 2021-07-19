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

package EnsEMBL::Web::Factory::UserData;
                                                                                   
use strict;
use warnings;
no warnings "uninitialized";
                                                                                   
use base qw(EnsEMBL::Web::Factory);

sub createObjects { 
  my $self   = shift;
  my $type = $self->param('data_type') || 'UserData';

  my ($userdata, $dataobject);
  if ($type) {
    my $create_method = "create_$type";
    $userdata   = defined &$create_method ? $self->$create_method : undef;
    $dataobject = $self->new_object( 'UserData', $userdata, $self->__data );
  }
  if( $dataobject ) {
    $dataobject->data_type($type);
    $self->DataObjects( $dataobject );
  }
}

#---------------------------------------------------------------------------

sub create_UserData {
  ## Creates a placeholder UserData object
  my $self   = shift;
  return {};
}

1;

