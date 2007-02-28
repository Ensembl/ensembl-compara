package EnsEMBL::Web::DBSQL::UserAdaptor;

=head1 NAME

EnsEMBL::Web::DBSQL::UserAdaptor - SQL statements relating to Record::User activity. 

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';

=head1 SYNOPSIS

This class is used by EnsEMBL::Web::Record and it's subclasses to talk to the mySQL
database. 

=cut

=head1 FUNCTIONS
=cut

use strict;
use warnings;

use DBI;
use EnsEMBL::Web::Object::User;
use EnsEMBL::Web::RegObj;

sub new {
  my $caller = shift;
  my $r = shift;
  my $handle = shift;
  my $class = ref($caller) || $caller;
  my $self = { '_request' => $r };
  if ($EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY) {
    eval {
      ## Get the UserDBAdaptor from the registry
      $self->{'_handle'} =  $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->dbAdaptor();
    };
    unless($self->{'_handle'}) {
       warn( "Unable to connect to authentication database: $DBI::errstr" );
       $self->{'_handle'} = undef;
    }
  } else {
    if ($handle) {
      $self->{'_handle'} = $handle;
    } else {
      warn( "NO DB USER DATABASE DEFINED" );
      $self->{'_handle'} = undef;
    }
  }
  bless $self, $class;
  return $self;
}

sub user_table {
  return "user";
}

sub print_query {
  my $self = shift;
  my $q = shift;
  shift;
  foreach(@_) {
    $q=~s/\?/'$_'/;
  }
  $self->{'_request'}->log_reason("Query:\n-- $q") if($self->{'_request'});
}

sub find_user_by_email {
  my ($self, $email)  = @_;
  my $details = {};
  return $details unless $self->{'_handle'};
  my $sql = qq(
    SELECT ) . $self->user_table . qq(_id, name, organisation, email, data, salt, password, status 
    FROM ) . $self->user_table . qq(
    WHERE email = "$email"; 
  );
  #warn "SQL: " . $sql;

  my $R = $self->{'_handle'}->selectall_arrayref($sql); 
  return {} unless $R->[0];

  my @record = @{$R->[0]};
  $details = {
    'id' => $record[0],
    'user_id' => $record[0],
    'name'    => $record[1],
    'organisation' => $record[2],
    'email'   => $record[3],
    'data'   => $record[4],
    'salt'   => $record[5],
    'password'   => $record[6],
    'status'   => $record[7],
  };
  return $details;
}

sub find_user_by_email_and_password {
  my ($self, %params)  = @_;
  my $email = $params{email};
  my $password = $params{password};
  my $details = {};
  return $details unless $self->{'_handle'};
  my $sql = qq(
    SELECT ) . $self->user_table . qq(_id, name, organisation, email, data, salt, password, status 
    FROM ) . $self->user_table . qq(
    WHERE email = "$email" and password = "$password"; 
  );
  #warn "SQL: " . $sql;

  my $R = $self->{'_handle'}->selectall_arrayref($sql); 
  return {} unless $R->[0];

  my @record = @{$R->[0]};
  $details = {
    'id'           => $record[0],
    'user_id'      => $record[0],
    'name'         => $record[1],
    'organisation' => $record[2],
    'email'        => $record[3],
    'data'         => $record[4],
    'salt'         => $record[5],
    'password'     => $record[6],
    'status'       => $record[7],
  };
  return $details;
}

sub find_user_by_user_id {
  my ($self, $id) = @_;

  my $details = {};
  return $details unless $self->{'_handle'};

  my $sql = qq(
    SELECT ) . $self->user_table . qq(_id, name, organisation, email, data, salt, password, status 
    FROM ) . $self->user_table . qq(
    WHERE ) . $self->user_table . qq(_id = "$id" 
  );

  #warn "SQL: " . $sql;

  my $R = $self->{'_handle'}->selectall_arrayref($sql); 
  return {} unless $R->[0];

  my @record = @{$R->[0]};
  $details = {
    'id' => $record[0],
    'user_id' => $record[0],
    'name'    => $record[1],
    'organisation' => $record[2],
    'email'   => $record[3],
    'data'   => $record[4],
    'salt'   => $record[5],
    'password'   => $record[6],
    'status'   => $record[7],
  };
  return $details;
}

sub find_users_by_group_id {
  my ($self, $id) = @_;
  my $table = $self->user_table;
  my $sql = qq(
    SELECT 
      user.) . $table . qq(_id,
      user.name,
      user.email,
      user.organisation,
      group_member.level,
      group_member.status
    FROM ) . $table . qq( 
    LEFT JOIN group_member 
    ON \(group_member.user_id = user.) . $table . qq(_id\) 
    WHERE group_member.webgroup_id = '$id';
  );
  my $R = $self->{'_handle'}->selectall_arrayref($sql);
  my $results = [];
  if ($R->[0]) {
    my @records = @{$R};
    foreach my $record (@records) {
      my $details = {
           'id'           => $record->[0],
           'name'         => $record->[1],
           'email'        => $record->[2],
           'organisation' => $record->[3],
           'level'        => $record->[4],
           'status'       => $record->[5],
         };
      push @{ $results }, $details;
    }
  }
  return $results;
}

sub find_users_by_level {
  my ($self, $level) = @_;
  #warn "FINDING USERS BY LEVEL";
}

sub update_group {
  my ($self, %params) = @_;
  my $id = $params{id};
  my $name = $params{name};
  my $description = $params{blurb};
  my $type = $params{type};
  my $status = $params{status};
  my $modified_by = $params{modified_by};
  my $created_by = $params{created_by};
  #warn "UPDATING: " . $name;
  my $sql = qq(
    UPDATE webgroup
    SET name        = "$name",
        blurb       = "$description",
        type        = "$type",
        status      = "$status",
        modified_by = "$modified_by",
        created_by  = "$created_by",
        created_at  = CURRENT_TIMESTAMP
    WHERE webgroup_id = ') . $id . qq(';
  );
  #warn "SQL\n$sql";
  my $sth = $self->{'_handle'}->prepare($sql);
  my $result = $sth->execute();
  return $self->last_inserted_id;
}

sub update_user {
  my ($self, %params) = @_;
  my $id = $params{id};
  my $name = $params{name};
  my $email = $params{email};
  my $password = $params{password};
  my $organisation = $params{organisation};
  my $status = $params{status};
  #warn "UPDATING: " . $name;
  #warn "STATUS: " . $status;
  my $sql = qq(
    UPDATE user 
    SET name         = "$name",
        email        = "$email",
        password     = "$password",
        organisation = "$organisation",
        status       = "$status",
        modified_at  = CURRENT_TIMESTAMP
    WHERE user_id = ') . $id . qq(';
  );
  #warn "SQL\n$sql";
  my $sth = $self->{'_handle'}->prepare($sql);
  my $result = $sth->execute();
  return $self->last_inserted_id;
}

sub find_records {
  my ($self, %params) = @_; 
  my $find_key;
  my $find_value;
  my $type = undef;
  my $table = "user";
  if ($params{type}) {
    $type = $params{type};
  }
  if ($params{table}) {
    $table = $params{table};
    delete $params{table};
  }
  #warn "TABLE: " . $table;
  my %options;
  if ($params{options}) {
    %options = %{ $params{options} }; 
    delete $params{options};
  }
  foreach my $key (keys %params) {
    if ($key ne "type" && $key ne "options") {
      $find_key = $key;
      $find_value = $params{$key};
      #warn "FIND KEY: " . $find_key . ": " . $find_value;
    }
  }
  my $results = [];
  
  ## maintain compatibility between schema versions
  if ($find_key eq 'id') {
    $find_key = "user_record_id";
  }
  if ($find_key eq 'group_id') {
    $find_key = 'webgroup_id';
  }

  my $sql = qq(
    SELECT * 
    FROM ) . $table . qq(_record WHERE $find_key = "$find_value"); 
  if ($type) {
    $sql .= qq( AND type = "$type"); 
  }
#warn "SQL:\n$sql"; 
  my $T = $self->{'_handle'}->selectall_arrayref($sql);
  return [] unless $T;
  for (my $i=0; $i<scalar(@$T);$i++) {
    my @array = @{$T->[$i]};
    push (@$results,
      {
      'id'          => $array[0],
      'user'        => $array[1],
      'type'        => $array[2],
      'data'        => $array[3],
      'created_at'  => $array[4],
      'modified_at' => $array[5],
      }
    );
  }
  return $results;
}

sub delete_user {
  my ($self, $id) = @_;
  my $table = "user"; 
  my $sql = qq(
    DELETE FROM user
    WHERE user_id = $id;
  );
  my $sth = $self->{'_handle'}->prepare($sql);
  my $result = $sth->execute();

  return $result;
}

sub delete_record {
  my ($self, %params) = @_;
  my $id = $params{id};
  my $table = "user"; 
  if ($params{table}) {
    $table = $params{table};
  }
  #warn "DELETING: " . $id;
  my $sql = qq(
    DELETE FROM ) . $table . qq(_record 
    WHERE ) . $table . qq(_record_id = $id
  );
  my $sth = $self->{'_handle'}->prepare($sql);
  my $result = $sth->execute();

  return $result;
}

sub update_record {
  my ($self, %params) = @_;
  my $id = $params{id};
  my $user_id = $params{user};
  my $type = $params{type};
  my $data = $params{data};
  my $table = "user"; 
  if ($params{table}) {
    $table = $params{table};
  }
  #warn "UPDATING: " . $user_id . ": " . $type . ": " . $data;
  my $sql = qq(
    UPDATE ) . $table . qq(_record
    SET ) . $table . qq(_id = $user_id,
        type    = "$type",
        data    = "$data"
    WHERE ) . $table . qq(_record_id = $id
  );
  #warn $sql;
  my $sth = $self->{'_handle'}->prepare($sql);
  my $result = $sth->execute();

  return $result;
}

sub insert_record {
  my ($self, %params) = @_;
  my $user_id = $params{user};
  my $type = $params{type};
  my $data = $params{data};
  my $table = "user"; 
  if ($params{table}) {
    $table = $params{table};
  }
  #warn "INSERTING: " . $user_id . ": " . $type . ": " . $data;
  my $sql = qq(
    INSERT INTO ) . $table . qq(_record 
    SET ) . $table . qq(_id = $user_id,
        type    = "$type",
        data    = "$data",
        created_at=CURRENT_TIMESTAMP
  );
  warn "SQL: " . $sql;
  my $sth = $self->{'_handle'}->prepare($sql);
  my $result = $sth->execute();

  return $self->last_inserted_id;
}

sub insert_user {
  my ($self, %params) = @_;
  my $name = $params{name};
  my $email = $params{email};
  my $data = $params{data};
  #warn "INSERTING: " . $name;
  my $sql = qq(
    INSERT INTO user 
    SET name    = "$name",
        email   = "$email",
        data    = "$data",
        created_at=CURRENT_TIMESTAMP
  );
  my $sth = $self->{'_handle'}->prepare($sql);
  my $result = $sth->execute();

  return $result;
}

sub insert_group {
  my ($self, %params) = @_;
  my $name = $params{name};
  my $description = $params{description};
  my $type = $params{type};
  my $status = $params{status};
  my $modified_by = $params{modified_by};
  my $created_by = $params{created_by};
  #warn "INSERTING: " . $name;
  my $sql = qq(
    INSERT INTO webgroup
    SET name        = "$name",
        blurb       = "$description",
        type        = "$type",
        status      = "$status",
        modified_by = "$modified_by",
        created_by  = "$created_by",
        created_at  = CURRENT_TIMESTAMP
  );
  #warn "SQL\n$sql";
  my $sth = $self->{'_handle'}->prepare($sql);
  my $result = $sth->execute();
  return $self->last_inserted_id;
}

sub add_relationship {
  my ($self, %params) = @_;
  my $from_id = $params{from};
  my $to_id = $params{to};
  my $level = $params{level};
  my $status = $params{status};
  my $sql = qq(
    INSERT INTO group_member 
    SET webgroup_id = "$from_id",
        user_id     = "$to_id",
        level       = "$level",
        status      = "$status",
        created_at  = CURRENT_TIMESTAMP
  );
  #warn $sql;
  my $sth = $self->{'_handle'}->prepare($sql);
  my $result = $sth->execute();
}

sub remove_relationship {
  my ($self, %params) = @_;
  my $from_id = $params{from};
  my $to_id = $params{to};
  my $sql = qq(
    DELETE FROM group_member 
    WHERE webgroup_id = "$from_id" AND user_id = "$to_id";
  );
  #warn $sql;
  my $sth = $self->{'_handle'}->prepare($sql);
  my $result = $sth->execute();
}

sub group_by_id {
  my ($self, $id) = @_;
  my $sql = qq(
    SELECT webgroup_id, name, blurb, type, status, created_by, modified_by,
           UNIX_TIMESTAMP(created_at), UNIX_TIMESTAMP(modified_at)
    FROM webgroup
    WHERE webgroup_id = ') . $id . "';";
  my $R = $self->{'_handle'}->selectall_arrayref($sql);
  my $results = [];
  if ($R->[0]) {
    my @records = @{$R};  
    foreach my $record (@records) {
      my $details = {
           'id'           => $record->[0],
           'name'         => $record->[1],
           'blurb'        => $record->[2],
           'type'         => $record->[3],
           'status'       => $record->[4],
           'created_by'   => $record->[5],
           'modified_by'  => $record->[6],
           'created_at'   => $record->[7],
           'modified_at'  => $record->[8],
         };
      push @{ $results }, $details;
    }
  }
  return $results;
}

sub groups_for_type {
  my ($self, $type, $status) = @_;
  if (!$status) {
    $status = "active";
  }
  my $sql = qq(
    SELECT 
           webgroup.webgroup_id,
           webgroup.name,
           webgroup.blurb,
           webgroup.type,
           webgroup.status,
           webgroup.created_by,
           webgroup.modified_by,
           UNIX_TIMESTAMP(webgroup.created_at),
           UNIX_TIMESTAMP(webgroup.modified_at)
    FROM webgroup 
    WHERE webgroup.type = '$type' and webgroup.status = '$status';
  );
  #warn $sql;
  my $R = $self->{'_handle'}->selectall_arrayref($sql);
  my $results = [];
  if ($R->[0]) {
    my @records = @{$R};  
    foreach my $record (@records) {
      my $details = {
           'id'           => $record->[0],
           'name'         => $record->[1],
           'blurb'        => $record->[2],
           'type'         => $record->[3],
           'status'       => $record->[4],
           'created_by'   => $record->[5],
           'modified_by'  => $record->[6],
           'created_at'   => $record->[7],
           'modified_at'  => $record->[8],
         };
      push @{ $results }, $details;
    }
  }

  return $results;
}

sub groups_for_user_id {
  my ($self, $user_id, $status) = @_;
  if (!$status) {
    $status = 'active';
  }
  #warn "FINDING GROUPS FOR USER ID: $user_id";
  my $sql = qq(
    SELECT 
           webgroup.webgroup_id,
           webgroup.name,
           webgroup.blurb,
           webgroup.type,
           webgroup.status,
           webgroup.created_by,
           webgroup.modified_by,
           UNIX_TIMESTAMP(webgroup.created_at),
           UNIX_TIMESTAMP(webgroup.modified_at)
    FROM group_member 
    LEFT JOIN webgroup
    ON (group_member.webgroup_id = webgroup.webgroup_id)
     WHERE group_member.user_id = $user_id AND webgroup.status = '$status';
  );

  my $R = $self->{'_handle'}->selectall_arrayref($sql);
  my $results = [];
  if ($R->[0]) {
    my @records = @{$R};  
    foreach my $record (@records) {
      my $details = {
           'id'           => $record->[0],
           'name'         => $record->[1],
           'blurb'        => $record->[2],
           'type'         => $record->[3],
           'status'       => $record->[4],
           'created_by'   => $record->[5],
           'modified_by'  => $record->[6],
           'created_at'   => $record->[7],
           'modified_at'  => $record->[8],
         };
      push @{ $results }, $details;
    }
  }
  return $results;

}

sub last_inserted_id {
  my ($self, $result) = @_;
  my $reult;
  my $sql = "SELECT LAST_INSERT_ID()";
  my $T = $self->{'_handle'}->selectall_arrayref($sql);
  return '' unless $T;
  my @A = @{$T->[0]}[0];
  $result = $A[0];
  return $result;
}

sub get_user_from_cookie {
  my( $self, $arg_ref ) = @_;
  $arg_ref->{'cookie'}->retrieve($arg_ref->{'r'});

  my $user = EnsEMBL::Web::Object::User->new({
               adaptor => $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->userAdaptor,
                    id => $arg_ref->{'cookie'}->get_value,
                 defer => 'yes'
             });

  return $user;
}

1;
