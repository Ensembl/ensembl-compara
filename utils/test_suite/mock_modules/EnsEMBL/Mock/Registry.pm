package EnsEMBL::Mock::Registry;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Mock::DBSQL::MySQLHandle;

{

sub dbAdaptor {
  return EnsEMBL::Mock::DBSQL::MySQLHandle->new();
}

}


1;
