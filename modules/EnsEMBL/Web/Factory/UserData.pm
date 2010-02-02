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

