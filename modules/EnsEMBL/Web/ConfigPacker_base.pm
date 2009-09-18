package EnsEMBL::Web::ConfigPacker_base;

use strict;
use DBI;

sub new {
  my( $class, $tree, $db_tree, $das_tree ) =@_;
  my $self = {
    _tree     => $tree     || {},
    _db_tree  => $db_tree  || {},
    _das_tree => $das_tree || {},
    _species  => undef
  };
  bless $self, $class;
  return $self;
}

sub full_tree {
  my $self = shift;
  $self->{'_tree'} = shift if @_;
  return $self->{'_tree'};
}

sub tree {
  my $self = shift;
  my $species = shift || $self->{'_species'};
  return $self->{'_tree'}{$species}||={};
}

sub full_db_tree {
  my $self = shift;
  $self->{'_db_tree'} = shift if @_;
  return $self->{'_db_tree'};
}

sub _table_exists {
  my( $self, $db_name, $table ) = @_;
  return exists( $self->db_tree->{'databases'}{$db_name}{'tables'}{$table} );
}

sub db_details {
  my $self = shift;
  my $db_name = shift;
  my $species = shift || $self->{'_species'};
  return $self->{'_db_tree'}{$species}{'databases'}{$db_name}||={};
}

sub db_multi_tree {
  my $self = shift;
  return $self->{'_db_tree'}{'MULTI'}||={};
}

sub db_tree {
  my $self = shift;
  my $species = $self->{'_species'};
  return $self->{'_db_tree'}{$species}||={};
}

sub das_tree {
  my $self = shift;
  my $species = $self->{'_species'};
  return $self->{'_das_tree'}{$species}||={};
}

sub species {
  my $self = shift;
  $self->{'_species'} = shift if @_;
  return $self->{'_species'};
}

sub db_connect {
  ### Connects to the specified database
  ### Arguments: configuration tree (hash ref), database name (string)
  ### Returns: DBI database handle
  my $self    = shift;
  my $db_name = shift;
  return unless exists $self->tree->{'databases'}->{$db_name};
  my $dbname  = $self->tree->{'databases'}->{$db_name}{'NAME'};
  return unless $dbname;

  #warn "Connecting to $db_name";
  my $dbhost  = $self->tree->{'databases'}->{$db_name}{'HOST'};
  my $dbport  = $self->tree->{'databases'}->{$db_name}{'PORT'};
  my $dbuser  = $self->tree->{'databases'}->{$db_name}{'USER'};
  my $dbpass  = $self->tree->{'databases'}->{$db_name}{'PASS'};
  my $dbdriver= $self->tree->{'databases'}->{$db_name}{'DRIVER'};
  my ($dsn, $dbh);
  eval {
    if( $dbdriver eq "mysql" ) {
      $dsn = "DBI:$dbdriver:database=$dbname;host=$dbhost;port=$dbport";
      $dbh = DBI->connect(
        $dsn,$dbuser,$dbpass, { 'RaiseError' => 1, 'PrintError' => 0 }
      );
    } elsif ( $dbdriver eq "Oracle") {
      $dsn = "DBI:$dbdriver:";
      my  $userstring = $dbuser . "\@" . $dbname;
      $dbh = DBI->connect(
        $dsn,$userstring,$dbpass, { 'RaiseError' => 1, 'PrintError' => 0 }
      );
    } elsif ( $dbdriver eq "ODBC") {
      $dsn = "DBI:$dbdriver:$dbname";
      $dbh = DBI->connect(
        $dsn, $dbuser, $dbpass,
        {'LongTruncOk' => 1,
         'LongReadLen' => 2**16 - 8,
         'RaiseError' => 1,
         'PrintError' => 0,
         'odbc_cursortype' => 2}
      );
    } else {
      print STDERR "\t  [WARN] Can't connect using unsupported DBI driver type: $dbdriver\n";
    }
  };

  if( $@ ) {
    print STDERR "\t  [WARN] Can't connect to $db_name\n", "\t  [WARN] $@";
    return undef();
  } elsif( !$dbh ) {
    print STDERR ( "\t  [WARN] $db_name database handle undefined\n" );
    return undef();
  }
  return $dbh;
}

sub db_connect_multi_species {
  ### Wrapper for db_connect, for use with multispecies configurations
  ### Arguments: database name (string)
  ### Returns: DBI database handle
  my $self    = shift;
  my $db_name = shift || die( "No database specified! Can't continue!" );

  return $self->db_connect( $db_name );
}

sub _meta_info {
  my( $self, $db, $key, $species_id ) = @_;
  $species_id ||= 1;
  return undef unless $self->db_details($db) &&
                   exists( $self->db_details($db)->{'meta_info'} );
  if (!$key) {
    return $self->db_details($db)->{'meta_info'};
  }
  else {
    if( exists( $self->db_details($db)->{'meta_info'}{$species_id} ) &&
      exists( $self->db_details($db)->{'meta_info'}{$species_id}{$key} ) ) {
        return $self->db_details($db)->{'meta_info'}{$species_id}{$key};
    }
    if( exists( $self->db_details($db)->{'meta_info'}{0} ) &&
      exists( $self->db_details($db)->{'meta_info'}{0}{$key} ) ) {
        return $self->db_details($db)->{'meta_info'}{0}{$key};
    }
  }
  return [];
}


1;
