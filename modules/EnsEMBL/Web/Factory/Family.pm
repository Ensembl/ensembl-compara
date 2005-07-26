package EnsEMBL::Web::Factory::Family;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Proxy::Object;

our @ISA = qw(  EnsEMBL::Web::Factory );

sub createObjects { 
  my $self = shift;
  $self->get_databases( qw(core compara) );
  my $database  = $self->database('compara');
  return $self->problem( 'Fatal', 'Database Error', "Could not connect to the compara database." ) unless $database;

  my $family_id = $self->param('family') || $self->param('family_id');
  return $self->problem( 'Fatal', 'No family name supplied', "Please specify a valid family name." ) unless $family_id;
  my $family;
  eval {
    $family = $database->get_FamilyAdaptor->fetch_by_stable_id( $family_id );
  };
  if( $@ || !$family ) {
    (my $T2 = $family_id) =~ s/^(\S+?)(\d+)(\.\d*)?/$1.sprintf("%011d",$2)/eg ; # Strip versions
    $family = $database->get_FamilyAdaptor->fetch_by_stable_id( $T2 );
  }
  if( $@ || !$family) {
    return $self->problem( 'Fatal', "Unknown family", "The family identifier you entered is not present in this species." );
  }
  $self->DataObjects( EnsEMBL::Web::Proxy::Object->new( 'Family', $family, $self->__data ) );
}

1;

