package EnsEMBL::Web::DBSQL::RoseDB;

### NAME: EnsEMBL::Web::DBSQL::RoseDB
### Subclass of Rose::DB, a wrapper around DBI 

### STATUS: Under Development
### You will need to uncomment the use base line in order to test this code!

### DESCRIPTION:

use strict;
use warnings;

no warnings qw(uninitialized);

use EnsEMBL::Web::SpeciesDefs;

#use base qw(Rose::DB);

sub new {
  my $class = shift;
  my $species_defs = shift;
  my $self = $class->SUPER::new(@);

  ## Slightly hacky insertion of db user and password!
  my $db_user = $species_defs->multidb->{'DATABASE_WEBSITE'}{'USER'} 
                  || $species_defs->DATABASE_WRITE_USER;

  my $db_pass = defined $species_defs->multidb->{'DATABASE_WEBSITE'}{'PASS'} 
                  ? $species_defs->multidb->{'DATABASE_WEBSITE'}{'PASS'} 
                  : $species_defs->DATABASE_WRITE_PASS;
  $self->{'ensembl_user'} = $db_user;
  $self->{'ensembl_pass'} = $db_pass;

  return $self;
}

sub db_user { return $_->{'ensembl_user'}; }
sub db_pass { return $_->{'ensembl_pass'}; }

## Use a private registry for this class
__PACKAGE__->use_private_registry;

## Set the default domain
__PACKAGE__->default_domain('ensembl');

## Register the ensembl_website data source
__PACKAGE__->register_db(
  type     => 'website',
  driver   => 'mysql',
  database => $species_defs->multidb->{'DATABASE_WEBSITE'}{'NAME'},
  host     => $species_defs->multidb->{'DATABASE_WEBSITE'}{'HOST'},
  port     => $species_defs->multidb->{'DATABASE_WEBSITE'}{'PORT'},
  username => $self->db_user, 
  password => $self->db_pass,
);

## Register the ensembl_web_user_db data source
__PACKAGE__->register_db(
  type     => 'user',
  driver   => 'mysql',
  database => $species_defs->ENSEMBL_USERDB_NAME,
  host     => $species_defs->ENSEMBL_USERDB_HOST, 
  port     => $species_defs->ENSEMBL_USERDB_PORT, 
  username => $self->db_user, 
  password => $self->db_pass,
);

1;

