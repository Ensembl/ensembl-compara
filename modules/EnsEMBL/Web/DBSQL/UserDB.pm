package EnsEMBL::Web::DBSQL::UserDB;
# File Apache/EnsEMBL/UserDB.pm

# TODO: 1987 called, it wants its data structure back:
#  _userdatatype_ID and its uses
#   1  WebUserConfig/contigviewbottom
#   2  WebUserConfig/contigviewtop
#   3  WebUserConfig/geneview
#   4  WebUserConfig/protview
#   5  WebUserConfig/seqentryview
#   6  WebUserConfig/chromosome
#   7  WebUserConfig/transview
#   8  WebUserConfig/vc_dumper
#   9  External DAS sources

use DBI;
use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::RegObj;
use Digest::MD5;
use strict;
use CGI::Cookie;
use EnsEMBL::Web::Object::User;

sub new {
  my $caller = shift;
  my $r = shift;
  my $class = ref($caller) || $caller;
  my $self = { '_request' => $r };
  if(defined( EnsEMBL::Web::SpeciesDefs->ENSEMBL_USERDB_NAME ) and EnsEMBL::Web::SpeciesDefs->ENSEMBL_USERDB_NAME ne '') {
    eval {
      $self->{'_handle'} =  $ENSEMBL_WEB_REGISTRY->dbAdaptor();
    };
    unless($self->{'_handle'}) {
       warn( "Unable to connect to authentication database: $DBI::errstr" );
       $self->{'_handle'} = undef;
    }
  } else {
    warn( "NO DB USER DATABASE DEFINED" );
    $self->{'_handle'} = undef;
  }
  bless $self, $class;
  return $self;
}

sub user_table {
  return "user";
}

sub create_session {
  my $self            = shift; 
  my $firstsession_ID = shift;
  my $uri             = shift;
  return unless( $self->{'_handle'} );
  $self->{'_handle'}->do("lock tables SESSION write");
  $self->{'_handle'}->do(
            "insert into SESSION
                set firstsession_ID =?, starttime = now(), endtime = now(),
                    pages = 0, startpage = ?", {},
            $firstsession_ID, $uri
        );
  my $session_ID = $self->{'_handle'}->selectrow_array("select last_insert_id()");
  $self->{'_handle'}->do("unlock tables");
  return $session_ID;
}

sub update_session {
  my $self            = shift;
  my $session_ID      = shift;
  my $uri	 = shift;
  return unless( $self->{'_handle'} );
  $self->{'_handle'}->do(
    "update SESSION
        set pages = pages + 1, endtime = now(), endpage = ?
      where ID = ?", {},
    $uri, $session_ID
  );
} 

sub clearCookie {
  my $self = shift;
  my $r    = shift || $self->{'_request'};
  my $cookie = CGI::Cookie->new(
    -name    => EnsEMBL::Web::SpeciesDefs->ENSEMBL_FIRSTSESSION_COOKIE,
    -value   => EnsEMBL::Web::DBSQL::UserDB::encryptID(-1),
    -domain  => EnsEMBL::Web::SpeciesDefs->ENSEMBL_COOKIEHOST,
    -path    => "/",
    -expires => "Monday, 31-Dec-1970 23:59:59 GMT"
  );
  if( $r ) {
    $r->headers_out->add(     'Set-cookie' => $cookie );
    $r->err_headers_out->add( 'Set-cookie' => $cookie );
    $r->subprocess_env->{'ENSEMBL_FIRSTSESSION'} = 0;
  }
}

sub setConfigByName {
  my( $self, $r, $session_ID, $key, $value ) = @_;
  #warn "==> Set config by name: $session_ID, $key, $value";
  return unless $self->{'_handle'};
  unless($session_ID) {
    $session_ID = $self->create_session( 0, $r ? $r->uri : '' );
    my $cookie = CGI::Cookie->new(
      -name    => EnsEMBL::Web::SpeciesDefs->ENSEMBL_FIRSTSESSION_COOKIE,
      -value   => EnsEMBL::Web::DBSQL::UserDB::encryptID($session_ID),
      -domain  => EnsEMBL::Web::SpeciesDefs->ENSEMBL_COOKIEHOST,
      -path      => "/",
      -expires => "Monday, 31-Dec-2037 23:59:59 GMT"
    );
    if( $r ) {
      $r->headers_out->add( 'Set-cookie' => $cookie );
      $r->err_headers_out->add( 'Set-cookie' => $cookie );
      $r->subprocess_env->{'ENSEMBL_FIRSTSESSION'} = $session_ID;
    }
    $ENV{'ENSEMBL_FIRSTSESSION'} = $session_ID;
  }
  my( $key_ID ) = $self->{'_handle'}->selectrow_array( "select ID from USERDATATYPE where name = ?", {},  $key );
## Create a USERDATATYPE value if one doesn't exist!! ##
  unless( $key_ID ) {
    $self->{'_handle'}->do( "insert ignore into USERDATATYPE set name = ?", {}, $key );
    ( $key_ID ) = $self->{'_handle'}->selectrow_array( "select ID from USERDATATYPE where name = ?", {}, $key );
  }
  $self->{'_handle'}->do(
    "insert ignore into USERDATA
        set session_ID = ?, userdatatype_ID = ?",{},
    $session_ID, $key_ID
  );
  $self->{'_handle'}->do(
    "update USERDATA
        set value= ?, updated = now()
      where session_ID = ? and userdatatype_ID = ?",{},
    $value, $session_ID, $key_ID
  );
  return $session_ID;
}

sub clearConfigByName {
  my( $self, $session_ID, $key ) = @_;
  return unless $self->{'_handle'};
  return unless $session_ID;
  my( $key_ID ) = $self->{'_handle'}->selectrow_array( "select ID from USERDATATYPE where name = ?", {}, $key );
  return unless $key_ID;
  $self->{'_handle'}->do( "delete from USERDATA where session_ID = ? and userdatatype_ID = ?", {}, $session_ID, $key_ID );
}

sub getConfigByName {
  my( $self, $session_ID, $key ) = @_;
  #warn "==> get config by name: $session_ID, $key";
  return unless $self->{'_handle'};
  return unless $session_ID;
  my( $key_ID ) = $self->{'_handle'}->selectrow_array( "select ID from USERDATATYPE where name = ?", {}, $key );
  return unless $key_ID;
  my( $value ) = $self->{'_handle'}->selectrow_array( "select value from USERDATA where session_ID = ? and userdatatype_ID = ?", {}, $session_ID, $key_ID );
  return $value;
}

sub setConfig {
  my $self            = shift;
  my $r               = shift;
  my $session_ID      = shift;
  my $userdatatype_ID = shift || 1;
  my $value           = shift;
  #warn "==> set config";
  return unless( $self->{'_handle'} );
  unless($session_ID) {
    $session_ID = $self->create_session( 0, $r ? $r->uri : '' );
    my $cookie = CGI::Cookie->new(
      -name    => EnsEMBL::Web::SpeciesDefs->ENSEMBL_FIRSTSESSION_COOKIE,
      -value   => EnsEMBL::Web::DBSQL::UserDB::encryptID($session_ID),
      -domain  => EnsEMBL::Web::SpeciesDefs->ENSEMBL_COOKIEHOST,
      -path 	 => "/",
      -expires => "Monday, 31-Dec-2037 23:59:59 GMT"
    );
    if( $r ) {
      $r->headers_out->add(	'Set-cookie' => $cookie );
      $r->err_headers_out->add( 'Set-cookie' => $cookie );
      $r->subprocess_env->{'ENSEMBL_FIRSTSESSION'} = $session_ID;
    }
    $ENV{'ENSEMBL_FIRSTSESSION'} = $session_ID;
  }
  $self->{'_handle'}->do(
   "insert ignore into USERDATA
       set session_ID = ?, userdatatype_ID = ?",{},
   $session_ID, $userdatatype_ID
  );
  $self->{'_handle'}->do(
    "update USERDATA
        set value= ?, updated = now()
      where session_ID = ? and userdatatype_ID = ?",{},
    $value, $session_ID, $userdatatype_ID
  );
  return $session_ID;
}

sub getConfig {
  my $self            = shift;
  my $session_ID      = shift;
  my $userdatatype_ID = shift || 1;  
  #warn "==> get config";
  return unless( $self->{'_handle'} && $session_ID > 0 );
  my $value = $self->{'_handle'}->selectrow_array(
    "select value
       from USERDATA
      where session_ID = ? and userdatatype_ID = ?", {},
    $session_ID, $userdatatype_ID
  );
  return $value;
}

sub resetConfig {
  my $self            = shift;
  my $session_ID      = shift;
  my $userdatatype_ID = shift || 1;  
  return unless( $self->{'_handle'} && $session_ID > 0 );
  $self->{'_handle'}->do(
    "delete from USERDATA
      where session_ID = ? and userdatatype_ID = ?", {},
    $session_ID, $userdatatype_ID
  );
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

sub encryptID {
    my $ID = shift;
    my $rand1 = 0x8000000 + 0x7ffffff * rand();
    my $rand2 = $rand1 ^ ($ID + EnsEMBL::Web::SpeciesDefs->ENSEMBL_ENCRYPT_0);
    my $encrypted = crypt(crypt(crypt(sprintf("%x%x",$rand1,$rand2),EnsEMBL::Web::SpeciesDefs->ENSEMBL_ENCRYPT_1),EnsEMBL::Web::SpeciesDefs->ENSEMBL_ENCRYPT_2),EnsEMBL::Web::SpeciesDefs->ENSEMBL_ENCRYPT_3);
    my $MD5d = Digest::MD5->new->add($encrypted)->hexdigest();
    return sprintf("%s%x%x%s", substr($MD5d,0,16), $rand1, $rand2, substr($MD5d,16,16));

}

sub decryptID {
    my $encrypted = shift;
    my $rand1  = substr($encrypted,16,7);
    my $rand2  = substr($encrypted,23,7);
    my $ID = ( hex( $rand1 ) ^ hex( $rand2 ) ) - EnsEMBL::Web::SpeciesDefs->ENSEMBL_ENCRYPT_0;
    my $XXXX = crypt(crypt(crypt($rand1.$rand2,EnsEMBL::Web::SpeciesDefs->ENSEMBL_ENCRYPT_1),EnsEMBL::Web::SpeciesDefs->ENSEMBL_ENCRYPT_2),EnsEMBL::Web::SpeciesDefs->ENSEMBL_ENCRYPT_3);
    my $MD5d = Digest::MD5->new->add($XXXX)->hexdigest();
    $ID = substr($MD5d,0,16).$rand1.$rand2.substr($MD5d,16,16) eq $encrypted ? $ID : 0;
}

#------------------------------------------------------------------------------
# USER ACCOUNT - management methods
#------------------------------------------------------------------------------

sub _random_string {
  my $length = shift || 8;

  my @chars = ('a'..'z','A'..'Z','0'..'9','_');
  my $random_string;
  foreach (1..$length) 
  {
    $random_string .= $chars[rand @chars];
  }
  return $random_string;
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

sub getUserByID {
  my ($self, $id) = @_;

  my $details = {};
  return $details unless $self->{'_handle'};

  my $sql = qq(
    SELECT ) . $self->user_table . qq(_id, name, organisation, email, data 
    FROM ) . $self->user_table . qq( 
    WHERE ) . $self->user_table . qq(_id = "$id" 
  );

  my $R = $self->{'_handle'}->selectall_arrayref($sql); 
  return {} unless $R->[0];

  my @record = @{$R->[0]};
  $details = {
    'id' => $record[0],
    'user_id' => $record[0],
    'name'    => $record[1],
    'organisation' => $record[2],
    'email'   => $record[3],
    'extra'   => $record[4],
  };
  return $details;
}

sub getUserByEmail {
  my ($self, $email) = @_;

  my $details = {};
  return $details unless $self->{'_handle'};

  my $sql = qq(
    SELECT ) . $self->user_table . qq(_id, name, salt, organisation, data 
    FROM ) . $self->user_table . qq( 
    WHERE email = "$email" 
  );

  my $R = $self->{'_handle'}->selectall_arrayref($sql); 
  return {} unless $R->[0];

  my @record = @{$R->[0]};
  $details = {
    'user_id' => $record[0],
    'name'    => $record[1],
    'salt'    => $record[2],
    'organisation'     => $record[3],
    'extra'   => $record[4],
  };
  return $details;
}

## This method validates a user from a URL sent via email (lost password)

sub getUserByCode {
  my ($self, $code) = @_;
  my ($self, $id) = @_;
  

  my $details = {};
  return $details unless $self->{'_handle'};

  my $sql = qq(
    SELECT ) . $self->user_table . qq(_id, name, salt, organisation, data 
    FROM ) . $self->user_table . qq( 
    WHERE password = "$code"
  );
#warn $sql;

  my $R = $self->{'_handle'}->selectall_arrayref($sql); 
  return {} unless $R->[0];

  my @record = @{$R->[0]};
  my $expires = undef;
  if (!$expires || time() < $expires) {
    my $user_id = $record[0];
    $details = {
      'user_id' => $user_id,
      'name'    => $record[1],
      'salt'    => $record[2],
      'organisation'=> $record[4],
      'extra'   => $record[5],
    };
    if ($expires) {
      ## reset expiry so user can log in
      $sql = qq(UPDATE user SET expires = null WHERE ) . $self->user_table . qq(_id = "$user_id");
      my $sth = $self->{'_handle'}->prepare($sql);
      my $result = $sth->execute();
    }
  }
  return $details;
}

sub createUserAccount {
  my ($self, $record) = @_;
  return unless $self->{'_handle'};
  
  my %details = %$record; 

  my $name      = $details{'name'}; 
  my $email     = $details{'email'}; 
  my $password  = $details{'password'}; 
  my $organisation = $details{'organisation'}; 
  my $extra     = $details{'extra'}; 
  my $salt      = _random_string(8); 
  my $encrypted = Digest::MD5->new->add($password.$salt)->hexdigest();

  my $sql = qq(
    INSERT INTO user SET  
      name          = "$name", 
      email         = "$email", 
      salt          = "$salt",
      password      = "$encrypted",
      organisation  = "$organisation",
      data          = "$extra",
      date_created  = NOW()
  );
  
  my $sth = $self->{'_handle'}->prepare($sql);
  my $result = $sth->execute();

  ## get new user ID so we can return it and set a cookie
  if ($result) {
    # get id for inserted record
    $sql = "SELECT LAST_INSERT_ID()";
    my $T = $self->{'_handle'}->selectall_arrayref($sql);
    return '' unless $T;
    my @A = @{$T->[0]}[0];
    $result = $A[0];
  }
  return $result;
}

sub updateUserAccount {
  my ($self, $record) = @_;
  return unless $self->{'_handle'};
  
  my %details = %$record; 

  my $user_id   = $details{'user_id'};
  my $name      = $details{'name'}; 
  my $email     = $details{'email'}; 
  my $organisation = $details{'organisation'}; 
  my $extra     = $details{'extra'}; 

  my $result;
    if ($user_id > 0) {
    my $sql = qq(
      UPDATE user SET  
        name          = "$name", 
        email         = "$email", 
        organisation  = "$organisation",
        data          = "$extra",
        last_updated  = NOW(),
        updated_by    = $user_id
      WHERE ) . $self->user_table . qq(_id   = $user_id
    );
  
    my $sth = $self->{'_handle'}->prepare($sql);
    $result = $sth->execute();
  }
  return $user_id if $result;
  return 0;
}

sub validateUser {
  my ($self, $email, $password) = @_;
  return {} unless $self->{'_handle'};
  my $result = {error => 'Problem with validation'};
  my %user = %{$self->getUserByEmail($email)};
  my $id = $user{'user_id'};
  return $result;
}

sub validateUser_old {
  my ($self, $email, $password) = @_;
  return {} unless $self->{'_handle'};

  my $result = {};
  ## first, do we have this email address?
  my %user = %{$self->getUserByEmail($email)};
  my $id = $user{'user_id'};
  if ($id > 0) {
    my $salt = $user{'salt'};
    my $encrypted = Digest::MD5->new->add($password.$salt)->hexdigest();
    my $sql = qq(
      SELECT ) . $self->user_table . qq(_id, data 
      FROM ) . $self->user_table . qq( 
      WHERE email = "$email" AND password = "$encrypted"
    );
    my $R = $self->{'_handle'}->selectall_arrayref($sql); 
    return unless $R->[0];

    my @record = @{$R->[0]};
    my $user_id = $record[0];
    my $expires = $record[1];
    if ($user_id) {
      $$result{'user_id'} = $record[0];
    }
    else {
      $$result{'error'} = 'invalid';
    }
  }
  else {
    $$result{'error'} = 'not_found';
  }
  return $result;
}

sub setPassword {
  my ($self, $record) = @_;
  return unless $self->{'_handle'};

  my $result = {};
  my $id        = $$record{'user_id'};
  return unless $id > 0;

  my $password  = $$record{'password'} || _random_string(16);
  my $expiry    = $$record{'expiry'};
  my $salt      = _random_string(8); 
  my $encrypted = Digest::MD5->new->add($password.$salt)->hexdigest();
 
  my $sql = qq(
    UPDATE user  
    SET 
      password  = "$encrypted",
      salt      = "$salt");
  if ($expiry) {
    $sql .= qq(,
      expires   = DATE_ADD(NOW(), INTERVAL $expiry SECOND)
    );
  }
  $sql .= qq( WHERE ) . $self->user_table . qq(_id = "$id");

  my $sth = $self->{'_handle'}->prepare($sql);
  my $result = $sth->execute();
 
  return $encrypted; ## string used in URL sent to user
}

#------------------------------------------------------------------------------
# USER ACCOUNT - customisation methods
#------------------------------------------------------------------------------

#------------------------ GROUPS -------------------------------------------

sub getGroupsByType {
  my ($self, $type) = @_;
  return [] unless $self->{'_handle'};
  return [] unless $type;

  my $results = [];
  my $sql = qq(
    SELECT webgroup_id, name, blurb
    FROM webgroup
    WHERE type = "$type" 
    ORDER BY name
  ); 
  my $T = $self->{'_handle'}->selectall_arrayref($sql);
  return [] unless $T;
  for (my $i=0; $i<scalar(@$T);$i++) {
    my @array = @{$T->[$i]};
    push (@$results,
      {
      'webgroup_id' => $array[0],
      'name'        => $array[1],
      'blurb'       => $array[2],
      }
    );
  }
  return $results;
}

sub getGroupByID {
  my ($self, $id) = @_;
  return {} unless $self->{'_handle'};
  return {} unless $id;

  my $sql = qq(
    SELECT g.webgroup_id, g.name, g.blurb, g.type, u1.name, u1.organisation, 
          g.created_at, u2.name, u2.organisation, g.modified_at
    FROM webgroup as g, user as u1, user as u2
    WHERE g.webgroup_id  = "$id" 
      AND g.created_by = u1.) . $self->user_table . qq(_id
      AND g.modified_by = u2.) . $self->user_table . qq(_id
    ORDER BY g.name
  ); 
  my $T = $self->{'_handle'}->selectall_arrayref($sql);
  return {} unless $T;
  my @array = @{$T->[0]};
  my $results = {
      'webgroup_id'   => $array[0],
      'name'          => $array[1],
      'blurb'         => $array[2],
      'type'          => $array[3],
      'creator_name'  => $array[4],
      'creator_org'   => $array[5],
      'created_at'    => $array[6],
      'modifier_name' => $array[7],
      'modifier_org'  => $array[8],
      'modified_at'   => $array[9],
      };

  return $results;
}

sub getAllGroups {
  my $self = shift;
  return [] unless $self->{'_handle'};

  my $results = [];
  my $sql = qq(
    SELECT webgroup_id, name, blurb, type
    FROM webgroup
    ORDER BY name
  ); 
  my $T = $self->{'_handle'}->selectall_arrayref($sql);
  return [] unless $T;
  for (my $i=0; $i<scalar(@$T);$i++) {
    my @array = @{$T->[$i]};
    push (@$results,
      {
      'webgroup_id' => $array[0],
      'name'        => $array[1],
      'blurb'       => $array[2],
      'type'        => $array[3],
      }
    );
  }
  return $results;
}

sub createGroup {
  my ($self, $record) = @_;
  return {} unless $self->{'_handle'};

  my $name          = $record->{'group_name'};
  my $blurb         = $record->{'group_blurb'};
  my $type          = $record->{'group_type'};
  my $status        = $record->{'group_status'};
  my $user_id       = $record->{'user_id'};

  my $sql = qq(INSERT INTO webgroup
                SET 
                  webgroup_id = NULL,
                  name = "$name", 
                  blurb = "$blurb",
                  type = "$type",
                  status = "$status",
                  created_at = NOW(),
                  created_by = "$user_id"
  );
  my $sth = $self->{'_handle'}->prepare($sql);
  my $result; # = $sth->execute();

  ## get new group ID
  if ($result) {
    # get id for inserted record
    $sql = "SELECT LAST_INSERT_ID()";
    my $T = $self->{'_handle'}->selectall_arrayref($sql);
    return '' unless $T;
    my @A = @{$T->[0]}[0];
    $result = $A[0];
  }
  return $result;
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
  warn "UPDATING: " . $name;
  warn "STATUS: " . $status;
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
  warn "SQL\n$sql";
  my $sth = $self->{'_handle'}->prepare($sql);
  my $result = $sth->execute();
  return $self->last_inserted_id;
}

sub updateGroup {
  my ($self, $record) = @_;
  return {} unless $self->{'_handle'};

  my $webgroup_id   = $record->{'webgroup_id'};
  my $name          = $record->{'name'};
  my $blurb         = $record->{'blurb'};
  my $type          = $record->{'type'};
  my $status        = $record->{'status'};
  my $user_id       = $record->{'user_id'};

  my $sql = qq(UPDATE webgroup
                SET 
                  name = "$name", 
                  blurb = "$blurb",
                  type = "$type",
                  status = "$status",
                  modified_at = NOW(),
                  modified_by = "$user_id",
                WHERE webgroup_id = "$webgroup_id"
  );
  my $sth = $self->{'_handle'}->prepare($sql);
  my $result = $sth->execute();

  if ($result) {
    return $webgroup_id;
  }
  else {
    return 0;
  }
}

sub getMembership {
  my ($self, $record) = @_;
  my $results = [];
  return $results unless $self->{'_handle'};
  my %criteria;
  
  if (ref($record) eq 'HASH') {
    %criteria = (
      'm.' . $self->user_table . '_id'     => $record->{'user_id'},
      'm.webgroup_id' => $record->{'webgroup_id'},
      'm.level'       => $record->{'level'},
      'm.status'      => $record->{'status'},
    );
  }

  my $sql = qq(SELECT g.webgroup_id, g.name, g.blurb, g.type, g.status,
                      u1.name, u1.organisation, g.created_at, u2.name, u2.organisation, g.modified_at,
                      m.) . $self->user_table . qq(_id, m.level, m.status
              FROM webgroup as g, group_member as m, user as u1, user as u2
              WHERE g.webgroup_id = m.webgroup_id
                AND g.created_by = u1.) . $self->user_table . qq(_id
                AND g.modified_by = u2.) . $self->user_table . qq(_id
      );
  while (my ($column, $value) = each (%criteria)) {
    if ($value) {
      $sql .= qq( AND $column = "$value");
    }
  }
  $sql .= qq( ORDER BY g.name);

  my $T = $self->{'_handle'}->selectall_arrayref($sql);
  return [] unless $T;
  for (my $i=0; $i<scalar(@$T);$i++) {
    my @array = @{$T->[$i]};
    push (@$results,
      {
      'webgroup_id'   => $array[0],
      'group_name'    => $array[1],
      'group_blurb'   => $array[2],
      'group_type'    => $array[3],
      'group_status'  => $array[4],
      'creator_name'  => $array[5],
      'creator_org'   => $array[6],
      'created_at'    => $array[7],
      'modifier_name' => $array[8],
      'modifier_org'  => $array[9],
      'modified_at'   => $array[10],
      'member_id'     => $array[11],
      'member_level'  => $array[12],
      'member_status' => $array[13],
      }
    );
  }
  return $results;
}

sub getGroupAdmins {
  my ($self, $group) = @_;
  return [] unless $self->{'_handle'};
  return [] unless $group;

  my $results = [];
  my $sql = qq(
    SELECT u.user_id, u.name, u.email
    FROM ) . $self->user_table . qq( as u, group_member as m
    WHERE u.user_id = m.user_id
      AND m.webgroup_id = "$group"
      AND m.level = "administrator"
    ORDER BY u.name
  ); 
  my $T = $self->{'_handle'}->selectall_arrayref($sql);
  return [] unless $T;
  for (my $i=0; $i<scalar(@$T);$i++) {
    my @array = @{$T->[$i]};
    push (@$results,
      {
      'user_id'  => $array[0],
      'name'      => $array[1],
      'email'     => $array[2],
      }
    );
  }
  return $results;
}

#------------------------ GENERIC 'RECORD' QUERIES ---------------------------

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
  my %options;
  if ($params{options}) {
    %options = %{ $params{options} }; 
    delete $params{options};
  }
  foreach my $key (keys %params) {
    if ($key ne "type" && $key ne "options") {
      $find_key = $key;
      $find_value = $params{$key};
    }
  }
  my $results = [];
  
  ## maintain compatibility between schema versions
  if ($find_key eq 'id') {
    $find_key = "user_record_id";
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


1;
