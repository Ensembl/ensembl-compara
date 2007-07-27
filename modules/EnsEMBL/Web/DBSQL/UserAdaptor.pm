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
    WHERE email = ?
  );
  #warn "SQL: " . $sql;

  my $R = $self->{'_handle'}->selectall_arrayref($sql,{},$email); 
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
    WHERE email = ? and password = ?
  );
  #warn "SQL: " . $sql;

  my $R = $self->{'_handle'}->selectall_arrayref($sql, {}, $email, $password );
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
    WHERE ) . $self->user_table . qq(_id = ?
  );

  #warn "SQL: " . $sql;

  my $R = $self->{'_handle'}->selectall_arrayref($sql,{},$id); 
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
    WHERE group_member.webgroup_id = ?;
  );
  my $R = $self->{'_handle'}->selectall_arrayref($sql,{},$id);
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
    SET name        = ?,
        blurb       = ?,
        type        = ?,
        status      = ?,
        modified_by = ?,
        created_by  = ?,
        created_at  = CURRENT_TIMESTAMP
    WHERE webgroup_id = ?
  );
  #warn "SQL\n$sql";
  my $sth = $self->{'_handle'}->prepare($sql);
  my $result = $sth->execute($name,$description,$type,$status,$modified_by,$created_by,$id);
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
    SET name         = ?,
        email        = ?,
        password     = ?,
        organisation = ?,
        status       = ?,
        modified_at  = CURRENT_TIMESTAMP
    WHERE user_id = ?
  );
  #warn "SQL\n$sql";
  my $sth = $self->{'_handle'}->prepare($sql);
  my $result = $sth->execute($name,$email,$password,$organisation,$status,$id);
  return $self->last_inserted_id;
}

sub find_records {
  my ($self, %params) = @_; 
  my $results = [];
  
  my $sql = 'SELECT * FROM ' . $params{table} . ' WHERE ' .  $params{by} . ' = ?'; 
  if ($params{type}) {
    $sql .= ' AND type = "' . $params{type} . '"'; 
  }
  my $T = $self->{'_handle'}->selectall_arrayref($sql,{},$params{value});
  return [] unless $T;
  for (my $i=0; $i<scalar(@$T);$i++) {
    my @array = @{$T->[$i]};
    next unless $array[0];
    push (@$results,
      {
      'id'          => $array[0],
      'user'        => $array[1],
      'group'       => $array[1],
      'type'        => $array[2],
      'data'        => $array[3],
      'created_by'  => $array[4],
      'modified_by' => $array[5],
      'created_at'  => $array[6],
      'modified_at' => $array[7],
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
    WHERE user_id = ?
  );
  my $sth = $self->{'_handle'}->prepare($sql);
  my $result = $sth->execute( $id );

  return $result;
}

sub delete_record {
  my ($self, %params) = @_;
  my $id = $params{id};
  my ($table, $primary_key); 
  if ($params{table}) {
    $table = $params{table};
  }
  if ($params{primary_key}) {
    $primary_key = $params{primary_key};
    delete $params{primary_key};
  }
  #warn "DELETING: " . $id;
  my $sql = qq(DELETE FROM $table WHERE $primary_key = ?);
  my $sth = $self->{'_handle'}->prepare($sql);
  my $result = $sth->execute($id);

  return $result;
}

sub update_record {
  my ($self, %params) = @_;
  my $id = $params{id};
  my $user_id = $params{user};
  if (!$user_id ) {
    $user_id = $params{group};
  }
  my $type = $params{type};
  my $data = $params{data};
  my ($table, $primary_key); 
  if ($params{table}) {
    $table = $params{table};
  }
  my $owner_key = 'user_id';
  if ($table =~ /group/) {
    $owner_key = 'webgroup_id';
  }
  if ($params{primary_key}) {
    $primary_key = $params{primary_key};
  }
  #warn "UPDATING: " . $user_id . ": " . $type . ": " . $data;
  my $sql = qq(UPDATE $table SET $owner_key = ?, type = ?, data = ? WHERE $primary_key = ?);
  warn $sql;
  my $sth = $self->{'_handle'}->prepare($sql);
  my $result = $sth->execute($user_id, $type, $data, $id);

  return $result;
}

sub insert_record {
  my ($self, %params) = @_;
  my $type = $params{type};
  my $data = $params{data};
  my ($table, $primary_key); 
  my $primary_key = 'user_id';
  if ($params{table}) {
    $table = $params{table};
  }
  my $owner_key = 'user_id';
  my $owner_value = $ENV{'ENSEMBL_USER_ID'};
  if ($table =~ /group/) {
    $owner_key = 'webgroup_id';
    $owner_value = $params{owner};
  }
  #warn "INSERTING: " . $user_id . ": " . $type . ": " . $data;
  my $sql = qq(INSERT INTO $table SET $owner_key = ?, type = ?, data = ?, created_by = ?, created_at = NOW());
  warn "SQL: " . $sql;
  my $sth = $self->{'_handle'}->prepare($sql);
  my $result = $sth->execute($owner_value, $type, $data, $ENV{'ENSEMBL_USER_ID'});

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
    SET name    = ?,
        email   = ?,
        data    = ?,
        created_at = NOW()
  );
  my $sth = $self->{'_handle'}->prepare($sql);
  my $result = $sth->execute( $name, $email, $data);

  return $result;
}

sub insert_group {
  my ($self, %params) = @_;
  my $name = $params{name};
  my $description = $params{description};
  my $type = $params{type};
  my $status = $params{status};
  #warn "INSERTING: " . $name;
  my $sql = qq(
    INSERT INTO webgroup
    SET name        = ?,
        blurb       = ?,
        type        = ?,
        status      = ?,
        created_by  = ?,
        created_at  = NOW()
  );
  #warn "SQL\n$sql";
  my $sth = $self->{'_handle'}->prepare($sql);
  my $result = $sth->execute($name, $description, $type, $status, $ENV{'ENSEMBL_USER_ID'});
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
    SET webgroup_id = ?,
        user_id     = ?,
        level       = ?,
        status      = ?,
        created_by  = ?,
        created_at  = NOW()
  );
  #warn $sql;
  my $sth = $self->{'_handle'}->prepare($sql);
  my $result = $sth->execute($from_id, $to_id, $level, $status, $ENV{'ENSEMBL_USER_ID'});
}

sub update_level {
  my ($self, %params) = @_;
  my $from_id = $params{from};
  my $to_id = $params{to};
  my $level = $params{level};
  my $sql = qq(
    UPDATE group_member 
    SET level       = ?,
        modified_by = ?,
        modified_at = NOW()
    WHERE
        webgroup_id = ?
    AND
        user_id     = ? 
  );
  #warn $sql;
  my $sth = $self->{'_handle'}->prepare($sql);
  my $result = $sth->execute($level, $ENV{'ENSEMBL_USER_ID'}, $from_id, $to_id);
}

sub update_status {
  my ($self, %params) = @_;
  my $from_id = $params{from};
  my $to_id = $params{to};
  my $status = $params{status};
  my $sql = qq(
    UPDATE group_member 
    SET status      = ?,
        modified_by = ?,
        modified_at = NOW()
    WHERE
        webgroup_id = ?
    AND
        user_id     = ? 
  );
  #warn $sql;
  my $sth = $self->{'_handle'}->prepare($sql);
  my $result = $sth->execute($status, $ENV{'ENSEMBL_USER_ID'}, $from_id, $to_id);
}

sub remove_relationship {
  my ($self, %params) = @_;
  my $from_id = $params{from};
  my $to_id = $params{to};
  my $sql = qq(
    DELETE FROM group_member 
    WHERE webgroup_id = ? AND user_id = ?
  );
  #warn $sql;
  my $sth = $self->{'_handle'}->prepare($sql);
  my $result = $sth->execute($from_id,$to_id);
}

sub group_by_id {
  my ($self, $id) = @_;
  my $sql = qq(
    SELECT webgroup_id, name, blurb, type, status, created_by, modified_by,
           UNIX_TIMESTAMP(created_at), UNIX_TIMESTAMP(modified_at)
    FROM webgroup
    WHERE webgroup_id = ?);
  my $R = $self->{'_handle'}->selectall_arrayref($sql,{},$id);
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
    WHERE webgroup.type = ? and webgroup.status = ?
  );
  #warn $sql;
  my $R = $self->{'_handle'}->selectall_arrayref($sql,{},$type,$status);
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
     WHERE group_member.user_id = ? AND webgroup.status = ?
  );

  my $R = $self->{'_handle'}->selectall_arrayref($sql,{},$user_id,$status);
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
