package EnsEMBL::Mock::DBSQL::MySQLHandle;

use strict;
use warnings;

use Class::Std;

{

my %Prepared_handle :ATTR(:get<prepared_handle> :set<prepared_handle>);

sub prepare {
  my ($self, $sql) = @_;
  warn "MOCK: Preparing SQL request with $sql";
  $self->set_prepared_handle({});
}

sub execute {
  warn "MOCK: Executing SQL request";
  my $self = shift; 
  return 1;
}

}


1;
