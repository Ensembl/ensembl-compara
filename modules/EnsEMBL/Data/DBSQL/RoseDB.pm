package EnsEMBL::Data::DBSQL::RoseDB;

### NAME: EnsEMBL::Data::DBSQL::RoseDB
### Subclass of Rose::DB, a wrapper around DBI 

### STATUS: Under Development
### You will need to uncomment the use base line in order to test this code!

### DESCRIPTION:

use strict;
use warnings;

no warnings qw(uninitialized);

#use base qw(Rose::DB);

sub new {
### Constructor - creates and initialises all the required database connections
### Arguments: class name (EnsEMBL::Data::DBSQL::RoseDB) plus hashref of database settings
  my ($class, $db_info) = @_;
  my $self = $class->SUPER::new;

  ## Use a private registry for this class
  self->use_private_registry;

  ## Set the default domain
  self->default_domain('ensembl');

  ## Register data sources
  foreach my $db (keys %$db_info) {
    self->register_db(
      type     => $db,
      driver   => 'mysql',
      database => $db_info->{$db}{'db'},
      host     => $db_info->{$db}{'host'},
      port     => $db_info->{$db}{'port'},
      username => $db_info->{$db}{'user'},
      password => $db_info->{$db}{'pass'},
    );
  }

  return $self;
}

1;

