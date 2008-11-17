package EnsEMBL::Web::Data::Session;

## This module represents objects from session_record table,
## It also provides some other functions to deal with sessions database
## like create_session_id (see below)

use strict;
use warnings;
no warnings 'uninitialized';
use base qw(EnsEMBL::Web::Data);

use EnsEMBL::Web::DBSQL::UserDBConnection (__PACKAGE__->species_defs);
use HTTP::Date qw(str2time time2iso);

__PACKAGE__->table('session_record');
__PACKAGE__->set_primary_key('session_record_id');

__PACKAGE__->add_queriable_fields(
  session_id   => 'int',
  type         => 'tinytext',
  code         => 'tinytext',
  data         => 'text',
  created_at   => 'datetime',
  modified_at  => 'datetime',
  valid_thru   => 'datetime', ## Default - 0 = unlimited
);

__PACKAGE__->columns(TEMP => qw/as_string/);

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

__PACKAGE__->add_trigger(select => sub {$_[0]->withdraw_data});
__PACKAGE__->add_trigger(before_create => \&fertilize_data);
__PACKAGE__->add_trigger(before_update => \&fertilize_data);

sub set_config {
  my $class = shift;
  my %args  = @_;
  my $data  = delete $args{data};
  
  my $config = $class->retrieve(%args);

  if ($config) {
    $config->data($data);
    return $config->save;
  } else {
    return $class->insert({
      %args,
      data  => $data,
    });
  }
}

sub get_config {
  my $class = shift;
  my %args  = @_;

  $class->propagate_cache_tags(%args);

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



##
## Share session record
##
sub share {
  my $self = shift;
  my %args = @_;

  my $share = __PACKAGE__->insert({
     session_id   => $self->create_session_id,
     type         => $self->type,
     code         => $self->code,
     data         => $self->data,
     valid_thru   => time2iso(time + 60*60*24*3),
  });
  
  $share->data->{share_id} = $share->id;
  $share->save;

  return $share;
}

###################################################################################################
##
## Data fields stuff
##
###################################################################################################

sub withdraw_data {
  my $self = shift;

  $self->as_string($self->data);
  $self->_attribute_store(data => $self->SUPER::withdraw_data);
}

sub fertilize_data {
  my $self = shift;
  
  $self->_attribute_set(data => $self->dump_data($self->data));
}


###################################################################################################
##
## Cache stuff
##
###################################################################################################

sub invalidate_cache {
  my $self  = shift;
  my $cache = shift;
  
  $self->SUPER::invalidate_cache(
    $cache,
    'session_id['.$self->session_id.']',
    'type['.$self->type.']',
    'code['.$self->code.']',
  );
}

sub propagate_cache_tags {
  my $class = shift;
  my %args = @_;

  my @tags;
  while (my ($key, $value) = each %args) {
    push @tags, $key.'['.$value.']' if $key && $value;
  }
  
  $class->SUPER::propagate_cache_tags(@tags);
}

1;
