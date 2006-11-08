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
      $self->{'_handle'} =  $EnsEMBL::Web::Apache::Handlers::ENSEMBL_USER_DB_HANDLE ||=
         DBI->connect(
 	  	"dbi:mysql:@{[EnsEMBL::Web::SpeciesDefs->ENSEMBL_USERDB_NAME]}:@{[EnsEMBL::Web::SpeciesDefs->ENSEMBL_USERDB_HOST]}:@{[EnsEMBL::Web::SpeciesDefs->ENSEMBL_USERDB_PORT]}",
		EnsEMBL::Web::SpeciesDefs->ENSEMBL_USERDB_USER,
		EnsEMBL::Web::SpeciesDefs->ENSEMBL_USERDB_PASS,
	        {RaiseError=>1,PrintError=>0}
         );
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

sub find_user_by_user_id {
  my ($self, $id) = @_;
  warn "FIND USER BY ID";
  my $user = EnsEMBL::Web::Object::User->new({ adaptor => $self, id => $id });
  return $user;
}

sub find_users_by_group_id {
  my ($self, $id) = @_;
  my $sql = qq(
    SELECT 
      user.user_id,
      user.name,
      user.email,
      user.org,
      group_member.level,
      group_member.status
    FROM user 
    LEFT JOIN group_member 
    ON (group_member.user_id = user.user_id) 
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
           'org'          => $record->[3],
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
  warn "FINDING USERS BY LEVEL";
}

sub getUserByID {
  my ($self, $id) = @_;

  my $details = {};
  return $details unless $self->{'_handle'};

  my $sql = qq(
    SELECT user_id, name, org, email, extra
    FROM user
    WHERE user_id = "$id" 
  );

  my $R = $self->{'_handle'}->selectall_arrayref($sql); 
  return {} unless $R->[0];

  my @record = @{$R->[0]};
  $details = {
    'id' => $record[0],
    'user_id' => $record[0],
    'name'    => $record[1],
    'org'     => $record[2],
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
    SELECT user_id, name, salt, org, extra
    FROM user
    WHERE email = "$email" 
  );

  my $R = $self->{'_handle'}->selectall_arrayref($sql); 
  return {} unless $R->[0];

  my @record = @{$R->[0]};
  $details = {
    'user_id' => $record[0],
    'name'    => $record[1],
    'salt'    => $record[2],
    'org'     => $record[3],
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
    SELECT user_id, name, salt, UNIX_TIMESTAMP(expires), org, extra
    FROM user
    WHERE password = "$code"
  );
warn $sql;

  my $R = $self->{'_handle'}->selectall_arrayref($sql); 
  return {} unless $R->[0];

  my @record = @{$R->[0]};
  my $expires = $record[3];
  if (!$expires || time() < $expires) {
    my $user_id = $record[0];
    $details = {
      'user_id' => $user_id,
      'name'    => $record[1],
      'salt'    => $record[2],
      'org'     => $record[4],
      'extra'   => $record[5],
    };
    if ($expires) {
      ## reset expiry so user can log in
      $sql = qq(UPDATE user SET expires = null WHERE user_id = "$user_id");
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
  my $org       = $details{'org'}; 
  my $extra     = $details{'extra'}; 
  my $salt      = _random_string(8); 
  my $encrypted = Digest::MD5->new->add($password.$salt)->hexdigest();

  my $sql = qq(
    INSERT INTO user SET  
      name          = "$name", 
      email         = "$email", 
      salt          = "$salt",
      password      = "$encrypted",
      org           = "$org",
      extra         = "$extra",
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
  my $org       = $details{'org'}; 
  my $extra     = $details{'extra'}; 

  my $result;
    if ($user_id > 0) {
    my $sql = qq(
      UPDATE user SET  
        name          = "$name", 
        email         = "$email", 
        org           = "$org",
        extra         = "$extra",
        last_updated  = NOW(),
        updated_by    = $user_id
      WHERE user_id   = $user_id
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

  my $result = {};
  ## first, do we have this email address?
  my %user = %{$self->getUserByEmail($email)};
  my $id = $user{'user_id'};
  if ($id > 0) {
    my $salt = $user{'salt'};
    my $encrypted = Digest::MD5->new->add($password.$salt)->hexdigest();
    my $sql = qq(
      SELECT user_id, expires
      FROM user
      WHERE email = "$email" AND password = "$encrypted"
    );
    my $R = $self->{'_handle'}->selectall_arrayref($sql); 
    return unless $R->[0];

    my @record = @{$R->[0]};
    my $user_id = $record[0];
    my $expires = $record[1];
    if ($user_id && !$expires) {
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
  $sql .= qq( WHERE user_id = "$id");

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
    SELECT g.webgroup_id, g.name, g.blurb, g.type, u1.name, u1.org, 
          g.created_at, u2.name, u2.org, g.modified_at
    FROM webgroup as g, user as u1, user as u2
    WHERE g.webgroup_id  = "$id" 
      AND g.created_by = u1.user_id
      AND g.modified_by = u2.user_id
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
      'm.user_id'     => $record->{'user_id'},
      'm.webgroup_id' => $record->{'webgroup_id'},
      'm.level'       => $record->{'level'},
      'm.status'      => $record->{'status'},
    );
  }

  my $sql = qq(SELECT g.webgroup_id, g.name, g.blurb, g.type, g.status,
                      u1.name, u1.org, g.created_at, u2.name, u2.org, g.modified_at,
                      m.user_id, m.level, m.status
              FROM webgroup as g, group_member as m, user as u1, user as u2
              WHERE g.webgroup_id = m.webgroup_id
                AND g.created_by = u1.user_id
                AND g.modified_by = u2.user_id
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

=pod
sub saveMembership {
## NB Unlike single-table saves, we decide between update and insert in the adaptor,
## because a cross-reference needs to do a query to check for existing entries instead of
## relying on the presence of id parameters
  my ($self, $record) = @_;
  my $result = {};
  return $result unless $self->{'_handle'};

  my $logged_in = $record->{'logged_in'};
  my $user_id   = $record->{'user_id'};
  my $webgroup_id  = $record->{'webgroup_id'};
  my $status    = $record->{'status'};
  my $level     = $record->{'level'};
  return {} unless ($user_id && $group_id);
  return {} unless ($status || $level);

  ## Is this user already a member of this group?
  my $sql = qq(SELECT user_id FROM group_member 
                WHERE user_id = "$user_id"
                AND webgroup_id = "$webgroup_id"
  );
  my $T = $self->db->selectall_arrayref($sql);
  if ($T->[0][0]) {
  ## User is already a member, so update status and/or level
    $sql = 'UPDATE group_member SET ';
    if ($status) {
      $sql .= qq( status = "$status");
    }
    if ($status && $level) {
      $sql .= ',';
    }
    if ($level) {
      $sql .= qq( level = "$level");
    }
    $sql = qq(last_updated = NOW(), updated_by = "$logged_in"
                WHERE user_id = "$user_id"
                AND webgroup_id = "$webgroup_id"
    );
  }
  else {
  ## Create new member record
    $sql = qq(INSERT INTO group_member SET user_id = $user_id, webgroup_id = $webgroup_id, );
    if ($status) {
      $sql .= qq(status = "$status", );
    }
    else {
      $sql .= qq(status = 'inactive', );
    }
    if ($level) {
      $sql .= qq(level = "$level", );
    }
    else {
      $sql .= qq(level = "member", );
    }
    $sql .= qq(created_at = NOW(), created_by = "$logged_in");
  }

  my $sth = $self->{'_handle'}->prepare($sql);
  my $result = $sth->execute();

  return $result;
}

sub getGroupAdmins {
  my ($self, $group) = @_;
  return [] unless $self->{'_handle'};
  return [] unless $group;

  my $results = [];
  my $sql = qq(
    SELECT u.user_id, u.name, u.email
    FROM user as u, group_member as m
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
=cut

#------------------------ GENERIC 'RECORD' QUERIES ---------------------------

sub find_records {
  my ($self, %params) = @_; 
  my $find_key;
  my $find_value;
  my $type = undef;
  if ($params{type}) {
    $type = $params{type};
  }
  my %options;
  if ($params{options}) {
    %options = %{ $params{options} }; 
  }
  foreach my $key (keys %params) {
    if ($key ne "type") {
      $find_key = $key;
      $find_value = $params{$key};
    }
  }
  my $results = [];
  my $sql = qq(
    SELECT * 
    FROM record WHERE $find_key = "$find_value"); 
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
      'user_id'     => $array[1],
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
  warn "DELETING: " . $id;
  my $sql = qq(
    DELETE FROM record 
    WHERE id = $id
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
  warn "UPDATING: " . $user_id . ": " . $type . ": " . $data;
  my $sql = qq(
    UPDATE record
    SET user_id = $user_id,
        type    = "$type",
        data    = "$data"
    WHERE id = $id
  );
  my $sth = $self->{'_handle'}->prepare($sql);
  my $result = $sth->execute();

  return $result;
}

sub insert_record {
  my ($self, %params) = @_;
  my $user_id = $params{user};
  my $type = $params{type};
  my $data = $params{data};
  warn "INSERTING: " . $user_id . ": " . $type . ": " . $data;
  my $sql = qq(
    INSERT INTO record 
    SET user_id = $user_id,
        type    = "$type",
        data    = "$data",
        created_at=CURRENT_TIMESTAMP
  );
  my $sth = $self->{'_handle'}->prepare($sql);
  my $result = $sth->execute();

  return $result;
}

sub insert_user {
  my ($self, %params) = @_;
  my $name = $params{name};
  my $email = $params{email};
  my $data = $params{data};
  warn "INSERTING: " . $name;
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
  warn "INSERTING: " . $name;
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
  warn "SQL\n$sql";
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
  my $sth = $self->{'_handle'}->prepare($sql);
  my $result = $sth->execute();
}

sub groups_for_type {
  my ($self, $type) = @_;

  warn "FINDING GROUPS FOR TYPE: $type";

  my $sql = qq(
    SELECT 
           webgroup.webgroup_id,
           webgroup.name,
           webgroup.type,
           webgroup.status,
           webgroup.created_by,
           webgroup.modified_by,
           UNIX_TIMESTAMP(webgroup.created_at),
           UNIX_TIMESTAMP(webgroup.modified_at)
    FROM group_member 
    LEFT JOIN webgroup
    ON (group_member.webgroup_id = webgroup.webgroup_id)
     WHERE webgroup.type = '$type';
  );

  my $R = $self->{'_handle'}->selectall_arrayref($sql);
  my $results = [];
  if ($R->[0]) {
    my @records = @{$R};  
    foreach my $record (@records) {
      my $details = {
           'id'           => $record->[0],
           'name'         => $record->[1],
           'type'         => $record->[2],
           'status'       => $record->[3],
           'created_by'   => $record->[4],
           'modified_by'  => $record->[5],
           'created_at'   => $record->[6],
           'modified_at'  => $record->[7],
         };
      push @{ $results }, $details;
    }
  }

  return $results;
}

sub groups_for_user_id {
  my ($self, $user_id) = @_;
  #  SELECT group_member.level,
  #         group_member.status,
  warn "FINDING GROUPS FOR USER ID: $user_id";
  my $sql = qq(
    SELECT 
           webgroup.webgroup_id,
           webgroup.name,
           webgroup.type,
           webgroup.status,
           webgroup.created_by,
           webgroup.modified_by,
           UNIX_TIMESTAMP(webgroup.created_at),
           UNIX_TIMESTAMP(webgroup.modified_at)
    FROM group_member 
    LEFT JOIN webgroup
    ON (group_member.webgroup_id = webgroup.webgroup_id)
     WHERE group_member.user_id = $user_id;
  );

  my $R = $self->{'_handle'}->selectall_arrayref($sql);
  my $results = [];
  if ($R->[0]) {
    my @records = @{$R};  
    foreach my $record (@records) {
      my $details = {
           'id'           => $record->[0],
           'name'         => $record->[1],
           'type'         => $record->[2],
           'status'       => $record->[3],
           'created_by'   => $record->[4],
           'modified_by'  => $record->[5],
           'created_at'   => $record->[6],
           'modified_at'  => $record->[7],
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

__END__
# EnsEMBL module for EnsEMBL::Web::DBSQL::UserDB
# Begat by James Smith <js5@sanger.ac.uk>
# User Account methods by Anne Parker <ap5@sanger.ac.uk>

=head1 NAME

EnsEMBL::Web::DBSQL::UserDB - connects to the user database

=head1 SYNOPSIS

=head2 General

Functions on the user database

=head2 connect

=head1 RELATED MODULES

See also: EnsEMBL::Web::SpeciesDefs.pm

=head1 FEED_BACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
EnsEMBL modules. Send your comments and suggestions to one of the
EnsEMBL mailing lists.  Your participation is much appreciated.

  http://www.ensembl.org/Dev/Lists - About the mailing lists

=head2 Reporting Bugs

