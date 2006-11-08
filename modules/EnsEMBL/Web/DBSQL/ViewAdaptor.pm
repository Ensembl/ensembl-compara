package EnsEMBL::Web::DBSQL::ViewAdaptor;

### An inside-out class that acts as a simple wrapper for Perl DBI,
### enabling quick'n'dirty development of simple database front-ends

use strict;
use warnings;
no warnings 'uninitialized';

use DBI;
use Data::Dumper;
use EnsEMBL::Web::SpeciesDefs;

{

my %Hostname_of;
my %Port_of;
my %Database_of;
my %Table_of;
my %Username_of;
my %Password_of;
my %Handle_of;

sub new {
  ### c
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $Hostname_of{$self}          = defined $params{hostname} ? $params{hostname} : "";
  $Port_of{$self}              = defined $params{port}     ? $params{port}     : "";
  $Database_of{$self}          = defined $params{database} ? $params{database} : "";
  $Table_of{$self}             = defined $params{table}    ? $params{table}    : "";
  $Username_of{$self}          = defined $params{username} ? $params{username} : "";
  $Password_of{$self}          = defined $params{password} ? $params{password} : "";
  $Handle_of{$self}            = defined $params{handle}   ? $params{handle}   : undef;
  return $self;
}

sub handle {
  ### a
  ### Returns a database handle (creates one if it doesn't exist)
  my $self = shift;
  $Handle_of{$self} = shift if @_;
  if ($Handle_of{$self}) {
  } else {
    $Handle_of{$self} = $self->create_handle;
  }
  return $Handle_of{$self};
}

sub last_inserted_id {
}

sub discover {
  ### Queries the database metadata for information about available fields. 
  ### Returns: a reference to an array of hashrefs. Each hashref
  ### contains the defintion of the database field. For example, the name 
  ### of the field can be accessed by $fields->[0]->{'Field'}.
  my ($self, $query_table) = @_;
  my $table = $self->table;
  if ($query_table) {
    $table = $query_table;
  } 
  my $sql = "DESCRIBE " . $table . ";"; 
  my $results = $self->query($sql, 'Field');
  my $fields = [];
  foreach my $key (keys %{ $results }) {
    push @{ $fields }, $results->{$key};
  }
  return $fields;
}

sub edit {
  ### Updates an existing entry in the table
  my ($self, %params) = @_;
  my %set_parameters = %{ $params{set} };
  my $id = $params{id};
  my @definition = undef;
  my $user = undef;
  if ($params{definition}) {
    @definition = @{ $params{definition} };
  } 
  if ($params{user}) {
    $user = $params{user};
  }
  my $table = $self->table;
  my $sql = "UPDATE $table ";
  $sql .= $self->set_sql_with_parameters(\%set_parameters, \@definition, $user);
  $sql .= "WHERE " . $table . "_id='" . $id . "'";  
  return $self->execute($sql);
}

sub execute {
  my ($self, $sql) = @_;
  my $sth = $self->handle->prepare($sql);
  my $result = $sth->execute();
  return $result;
}

sub set_sql_with_parameters {
  my ($self, $set, $def, $user) = @_;
  my $sql = "SET ";
  foreach my $key (keys %{ $set }) {
    $sql .= $key . " = '" . $set->{$key} . "', ";
  }
  if ($self->definition_contains('created_at', @{ $def })) {
    $sql .= "created_at=CURRENT_TIMESTAMP, ";
  }
  if ($self->definition_contains('modified_at', @{ $def })) {
    $sql .= "modified_at=CURRENT_TIMESTAMP, ";
  }
  if ($user) {
    if ($self->definition_contains('created_by', @{ $def })) {
      $sql .= "created_by = '" . $user . "', ";
    }
    if ($self->definition_contains('modified_by', @{ $def })) {
      $sql .= "modified_by = '" . $user . "', ";
    }
  }
  $sql =~ s/, $//;
  return $sql;
}

sub create {
  ### Creates a new entry in the table
  my ($self, %params) = @_;

  my %set_parameters = %{ $params{set} };
  my @definition = undef;
  my $user = undef;
  my $record = undef;

  if ($params{definition}) {
    @definition = @{ $params{definition} };
  } 

  if ($params{user}) {
    $user = $params{user};
  }

  if ($params{record}) {
    $record = $params{record}; 
    my $dump = $self->dump_data(\%set_parameters);

    foreach my $key (keys %set_parameters) {
      delete $set_parameters{$key};
    }

    $set_parameters{type} = $record;
    $set_parameters{data} = $dump;
    $set_parameters{user_id} = $user;

  }

  my $table = $self->table;
  if ($params{table}) {
    $table = $params{table};
    @definition = @{ $self->discover($table) };
  }

  my $sql = "INSERT INTO " . $table . " ";
  $sql .= $self->set_sql_with_parameters(\%set_parameters, \@definition, $user);
  $sql .= ";";
  warn "SQL: " . $sql;
  if ($self->execute($sql)) {
    return $self->last_inserted_id;
  }
  return undef; 
}

sub create_record {
}

sub dump_data {
  my ($self, $data) = @_;
  my $dump = Dumper($data);
  $dump =~ s/'/\\'/g;
  $dump =~ s/^\$VAR1 = //;
  return $dump;
}

sub fetch_id {
  my ($self, $id) = @_;
  my $table = $self->table;
  my $id_field = $table . "_id";
  my $sql = "";
  $sql .= "SELECT * FROM " . $table . " ";
  $sql .= "WHERE " . $id_field . " = '" . $id . "'";
  $sql .= ";";
  return $self->query($sql, $id_field);
}

sub last_inserted_id {
  my ($self) = @_;
  my $sql = "SELECT LAST_INSERT_ID()";
  my $T = $self->handle->selectall_arrayref($sql);
  return '' unless $T;
  my @A = @{$T->[0]}[0];
  my $result = $A[0];
  return $result;
}


sub definition_contains {
  my ($self, $name, @definition) = @_;
  my $found = 0;
  foreach my $field (@definition) {
    if ($field->{'Field'} eq $name) {
      $found = 1;
    }
  }
  return $found;
}

sub query {
  ### Simple wrapper for a SELECT query
  ### Argument: string (SQL)
  my ($self, $sql, $key) = @_;
  my $results = undef;
  if ($key) {
    $results = $self->handle->selectall_hashref($sql, $key);
  } else {
    $results = $self->handle->selectall_hashref($sql);
  }
  return $results;
}

sub create_handle {
  ### Creates a standard DBI database handle
  my $self = shift;
  my $dbh = DBI->connect(
                         "DBI:mysql:database=" . $self->database . 
                         ";host=" . $self->hostname . 
                         ";port=" . $self->port, 
                         $self->username , 
                         $self->password
  );
  unless ($dbh) {
    warn ("Unable to connect to database");
    $dbh = undef;
  }
  warn "DBH: " . $dbh;
  return $dbh;
}

sub disconnect {
  ### Simple wrapper for DBI disconnect
  my $self = shift;
  #$self->handle->disconnect;
}

sub hostname {
  ### a
  my $self = shift;
  $Hostname_of{$self} = shift if @_;
  return $Hostname_of{$self};
}

sub port {
  ### a
  my $self = shift;
  $Port_of{$self} = shift if @_;
  return $Port_of{$self};
}

sub database {
  ### a
  my $self = shift;
  $Database_of{$self} = shift if @_;
  return $Database_of{$self};

}
sub table {
  ### a
  my $self = shift;
  $Table_of{$self} = shift if @_;
  return $Table_of{$self};
}

sub username {
  ### a
  my $self = shift;
  $Username_of{$self} = shift if @_;
  return $Username_of{$self};
}

sub password {
  ### a
  my $self = shift;
  $Password_of{$self} = shift if @_;
  return $Password_of{$self};
}

sub DESTROY {
  ### d
  my $self = shift;
  $self->disconnect;
  delete $Hostname_of{$self};
  delete $Port_of{$self};
  delete $Database_of{$self};
  delete $Table_of{$self};
  delete $Username_of{$self};
  delete $Password_of{$self};
}


}

1;
