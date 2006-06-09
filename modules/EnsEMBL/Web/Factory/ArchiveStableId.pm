package EnsEMBL::Web::Factory::ArchiveStableId;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Proxy::Object;

our @ISA = qw(  EnsEMBL::Web::Factory );

sub createObjects {
  my $self      = shift;
  my $id        = shift;
  my $db          = $self->param( 'db' ) || 'core';
  my $db_adaptor  = $self->database($db) ;
  unless ($db_adaptor){
    $self->problem('Fatal',
                   'Database Error',
                   "Could not connect to the $db database."  );
    return ;
  }

  unless ($id) {
    foreach ( $self->param() ) {
      next unless $_ =~ /gene|transcript|peptide/;
      $id = $self->param($_);
      last;
    }
  }
  return undef unless $id;

  my $aa = $db_adaptor->get_ArchiveStableIdAdaptor;
  my $archiveStableId = $aa->fetch_by_stable_id($id);
  unless ($archiveStableId) {
    $archiveStableId =~ s/\..*//;
  }
  return $self->problem( 'Fatal', "Unknown ID $id",  "Either $id is an unknown ID or there was a problem retrieving it." ) unless $archiveStableId;

  my $obj = EnsEMBL::Web::Proxy::Object->new( 'ArchiveStableId', $archiveStableId, $self->__data );
   $self->DataObjects($obj);
}

1;
