package EnsEMBL::Data::DBSQL::RoseDB;

### NAME: EnsEMBL::Data::DBSQL::RoseDB
### Subclass of Rose::DB, a wrapper around DBI 

### STATUS: Under Development
### You will need to uncomment the use base line in order to test this code!

### DESCRIPTION:
### To use this module, you will need to pass the constructor a hashref 
### containing connection details for all the databases you want to use:
### $db_info = {
###     'user' => {
###       'db'    => 'ensembl_web_user_db',
###       'host'  => 'db.mydomain.org',
###       'port'  => '3306',
###       'user'  => 'my_write_user',
###       'pass'  => 'my_write_password', 
###     },
### };
### The 'port' parameter is optional and will default to 3306
###
### The expected keys are:
### user - Ensembl user database
### website - Website database (news, help, etc)
### session - Session database used to store web session IDs
### production - Production database used in release cycle

use strict;
use warnings;

no warnings qw(uninitialized);

#use base qw(Rose::DB);

sub new {
### Constructor - creates and initialises all the required database connections
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
      port     => $db_info->{$db}{'port'} || 3306,
      username => $db_info->{$db}{'user'},
      password => $db_info->{$db}{'pass'},
    );
  }

  return $self;
}

1;

