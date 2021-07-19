=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::ConfigPacker_base;

use strict;
use DBI;

sub new {
  my( $class, $tree, $db_tree) = @_;
  my $self = {
    _tree     => $tree     || {},
    _db_tree  => $db_tree  || {},
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

sub species {
  ## Return the "species" (actually the first part of the db name - could be 
  ## a clade in the case of a collection database)
  my $self = shift;
  $self->{'_species'} = shift if @_;
  return $self->{'_species'};
}

sub db_connect {
  ### Connects to the specified database
  ### Arguments: configuration tree (hash ref), database name (string)
  ### Returns: DBI database handle
  my ($self, $db, $details, $no_warn) = @_;
  return unless ($details || exists $self->tree->{'databases'}{$db});
  $details ||= $self->tree->{'databases'}{$db};
  my $dbname  = $details->{'NAME'};
  return unless $dbname;

  my $dbhost  = $details->{'HOST'};
  my $dbport  = $details->{'PORT'};
  my $dbuser  = $details->{'USER'};
  my $dbpass  = $details->{'PASS'};
  my $dbdriver= $details->{'DRIVER'};
  my ($dsn, $dbh);
  # warn "Connecting to $dbname ($db_name) with args: $dbuser\@$dbhost:$dbport\n";
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
    unless ($no_warn || ($db =~ /COMPARA/ && $self->{'_tree'}{'NO_COMPARA'})) {
      print STDERR "\t  [WARN] Can't connect to $db\n", "\t  [WARN] $@";
      $dbh = undef;
    }
  } elsif( !$dbh ) {
    print STDERR ( "\t  [WARN] $db database handle undefined\n" ) unless $no_warn;
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
