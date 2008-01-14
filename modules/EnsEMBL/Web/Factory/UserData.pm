package EnsEMBL::Web::Factory::UserData;
                                                                                   
use strict;
use warnings;
no warnings "uninitialized";
                                                                                   
use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Proxy::Object;

use EnsEMBL::Web::Object::UserDAS;
## TO ADD
#use EnsEMBL::Web::Object::File;
#use EnsEMBL::Web::Data::UserFile;
                                                                                   
our @ISA = qw(  EnsEMBL::Web::Factory );

sub createObjects { 
  my $self   = shift;
  my $type = $self->param('data_type') || 'UserData';

  my ($userdata, $dataobject);
  if ($type) {
    my $create_method = "create_$type";
    $userdata   = defined &$create_method ? $self->$create_method : undef;
    $dataobject = EnsEMBL::Web::Proxy::Object->new( 'UserData', $userdata, $self->__data );
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

sub create_UserDAS {
  ## Creates a lightweight UserDAS object
  my $self   = shift;
  return EnsEMBL::Web::Object::UserDAS->new();
}


1;

