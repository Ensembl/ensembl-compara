package EnsEMBL::Web::DBSQL::ViewAdaptor;

use strict;
use warnings;
no warnings 'uninitialized';

use DBI;
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
  my $self = shift;
  $Handle_of{$self} = shift if @_;
  if ($Handle_of{$self}) {
  } else {
    $Handle_of{$self} = $self->create_handle;
  }
  return $Handle_of{$self};
}

sub discover {
  my $self = shift;
  my $sql = "DESCRIBE " . $self->table . ";"; 
  my $results = $self->query($sql);
  my $fields = [];
  foreach my $key (keys %{ $results }) {
    push @{ $fields }, $results->{$key};
  }
  return $fields;
}


sub query {
  my ($self, $sql) = @_;
  my $results = $self->handle->selectall_hashref($sql, "Field");
  if ($results) {
    warn "FOUND!";
  }
  return $results;
}

sub create_handle {
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
