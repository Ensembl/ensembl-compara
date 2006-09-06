package EnsEMBL::Web::DBSQL::UserDB;
# File Apache/EnsEMBL/UserDB.pm

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

sub new {
  my $caller = shift;
  my $r = shift;
  my $class = ref($caller) || $caller;
  my $self = { '_request' => $r };
  if(defined( EnsEMBL::Web::SpeciesDefs->ENSEMBL_USERDB_NAME ) and EnsEMBL::Web::SpeciesDefs->ENSEMBL_USERDB_NAME ne '') {
    eval {
      $self->{'_handle'} =
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
    'user_id' => $record[0],
    'name'    => $record[1],
    'org'     => $record[2],
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

sub saveBookmark {
  my ($self, $record) = @_;
  return {} unless $self->{'_handle'};

  my $user_id = $$record{'user_id'};
  my $name    = $$record{'bm_name'};
  my $url     = $$record{'bm_url'};
  return {} unless ($user_id && $url);

  my $sql = qq(
    INSERT INTO bookmark 
    SET user_id = $user_id, 
        name    = "$name", 
        url     = "$url"
  );
  my $sth = $self->{'_handle'}->prepare($sql);
  my $result = $sth->execute();

  return $result;
}

sub rename_bookmark {
  my ($self, $bookmark_id, $new_name) = @_;
  my $sql = qq(
    UPDATE bookmark 
    SET name = '$new_name' 
    WHERE bm_id = $bookmark_id;
  );
  my $sth = $self->{'_handle'}->prepare($sql);
  my $result = $sth->execute();
  return $new_name;
}

sub delete_bookmark {
  my ($self, $bookmark_id) = @_;
  my $sql = qq(
    DELETE FROM bookmark 
    WHERE bm_id = $bookmark_id;
  );
  my $sth = $self->{'_handle'}->prepare($sql);
  my $result = $sth->execute();
  return "";
}

sub getBookmarksByUser {
  my ($self, $user_id) = @_;
  return [] unless $self->{'_handle'};
  return [] unless $user_id;

  my $results = [];
  my $sql = qq(
    SELECT bm_id, name, url
    FROM bookmark
    WHERE user_id = $user_id
  ); 
  my $T = $self->{'_handle'}->selectall_arrayref($sql);
  return [] unless $T;
  for (my $i=0; $i<scalar(@$T);$i++) {
    my @array = @{$T->[$i]};
    push (@$results,
      {
      'bm_id'   => $array[0],
      'bm_name' => $array[1],
      'bm_url'  => $array[2],
      }
    );
  }
  return $results;
}

sub deleteBookmarks {
  my ($self, $bookmarks) = @_;
  return 0 unless $self->{'_handle'};
  return 0 unless (ref($bookmarks) eq 'ARRAY' && scalar(@$bookmarks) > 0);
  
  foreach my $bookmark (@$bookmarks) {
    my $sql = "DELETE FROM bookmark where bm_id = $bookmark";
    my $sth = $self->{'_handle'}->prepare($sql);
    my $result = $sth->execute();
  }

  return 1;
}

sub getGroupsByUser {
  my ($self, $user_id) = @_;
  return [] unless $self->{'_handle'};
  return [] unless $user_id;

  my $results = [];
  my $sql = qq(
    SELECT g.group_id, g.name, g.title, g.blurb
    FROM webgroup g, group_member m
    WHERE g.group_id = m.group_id 
    AND m.user_id = $user_id
  ); 
  my $T = $self->{'_handle'}->selectall_arrayref($sql);
  return [] unless $T;
  for (my $i=0; $i<scalar(@$T);$i++) {
    my @array = @{$T->[$i]};
    push (@$results,
      {
      'group_id'  => $array[0],
      'name'      => $array[1],
      'title'     => $array[2],
      'blurb'     => $array[3],
      }
    );
  }
  return $results;
}

sub getGroupsByType {
  my ($self, $type) = @_;
  return [] unless $self->{'_handle'};
  return [] unless $type;

  my $results = [];
  my $sql = qq(
    SELECT group_id, name, title, blurb
    FROM webgroup
    WHERE type = "$type" 
    ORDER BY title
  ); 
  my $T = $self->{'_handle'}->selectall_arrayref($sql);
  return [] unless $T;
  for (my $i=0; $i<scalar(@$T);$i++) {
    my @array = @{$T->[$i]};
    push (@$results,
      {
      'group_id'  => $array[0],
      'name'      => $array[1],
      'title'     => $array[2],
      'blurb'     => $array[3],
      }
    );
  }
  return $results;
}

sub getAllGroups {
  my $self = shift;
  return [] unless $self->{'_handle'};

  my $results = [];
  my $sql = qq(
    SELECT group_id, name, title, blurb, type
    FROM webgroup
    ORDER BY title
  ); 
  my $T = $self->{'_handle'}->selectall_arrayref($sql);
  return [] unless $T;
  for (my $i=0; $i<scalar(@$T);$i++) {
    my @array = @{$T->[$i]};
    push (@$results,
      {
      'group_id'  => $array[0],
      'name'      => $array[1],
      'title'     => $array[2],
      'blurb'     => $array[3],
      'type'      => $array[4],
      }
    );
  }
  return $results;
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

