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
  my $size = $self->species_defs->get_table_size(
    {-db    => "DATABASE_CORE", -table => "gene_archive"}  );

  return $self->problem('Fatal', "No archive for this species", "No IDs have been archived in this species") unless $size;

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
  my $archiveStableId;
  
  if ($id =~ /(\S+)\.(\d+)/) {
    $archiveStableId = $aa->fetch_by_stable_id_version($1, $2);
  }
  else {
    $archiveStableId = $aa->fetch_by_stable_id($id);
  }

  return $self->problem( 'Fatal', "$id not in Archive",  "$id is not in the ID Archive (or there was a problem retrieving it)." ) unless $archiveStableId;

  my $obj = EnsEMBL::Web::Proxy::Object->new( 'ArchiveStableId', $archiveStableId, $self->__data );
   return unless $obj;
   $self->DataObjects($obj);
}

1;
