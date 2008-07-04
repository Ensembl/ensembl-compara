package EnsEMBL::Web::Data::Session;

## This module represents objects from session_record table,
## It also provides some other functions to deal with sessions database
## like create_session_id (see below)

use strict;
use warnings;
use HTTP::Date qw(str2time time2iso);

use base qw(EnsEMBL::Web::Data);
use EnsEMBL::Web::DBSQL::UserDBConnection (__PACKAGE__->species_defs);

__PACKAGE__->table('session_record');
__PACKAGE__->set_primary_key('session_record_id');

__PACKAGE__->add_queriable_fields(
  session_id  => 'int',
  type        => 'tinytext',
  code        => 'tinytext',
  data        => 'text',
  created_at  => 'datetime',
  modified_at => 'datetime',
);

__PACKAGE__->add_trigger(
  before_create => sub {
                     $_[0]->created_at(time2iso());
                   }
);

__PACKAGE__->add_trigger(
  before_update => sub {
                     $_[0]->modified_at(time2iso());
                   }
);

sub set_config {
  my $class = shift;
  my %args  = @_;
  my $data  = delete $args{data};
  
  my $config = $class->retrieve(%args);
  
  if ($config) {
    $config->data($data);
    $config->save;
  } else {
    $config = $class->insert({
      %args,
      data  => $data,
    });
  }
  
  return $config;
}

sub get_config {
  my $class = shift;
  my %args  = @_;
  
  return wantarray
         ? $class->search(%args)
         : $class->retrieve(%args);
}

sub reset_config {
  my $class = shift;
  $class->search(@_)->delete_all;
}

sub create_session_id {
###
  my $class = shift;
  my $dbh   = $class->db_Main;

  $dbh->do('LOCK TABLES session WRITE');
  my ($session_id) = $dbh->selectrow_array('select last_session_no from session');
  if ($session_id) {
    $dbh->do("update session set last_session_no = ?", {}, ++$session_id );
  } else {
    $session_id = 1;
    $dbh->do("insert into session set last_session_no = ?", {}, $session_id);
  }
  $dbh->do('unlock tables');
  return $session_id;
}

1;