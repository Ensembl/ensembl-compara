=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::DBSQL::ConfigAdaptor;

use strict;

use Data::Dumper;
use DBI;
use Digest::MD5 qw(md5_hex);
use HTML::Entities qw(encode_entities decode_entities);

use EnsEMBL::Web::Controller;

my $DBH; # package database handle for persistence

sub new {
  my ($class, $hub) = @_;
  my $species_defs  = $hub->species_defs;
  my $user          = $hub->user;
  my $self          = {
    hub        => $hub,
    session_id => $hub->session->session_id,
    user_id    => $user ? $user->id : undef,
    group_ids  => [ $user ? map($_->group_id, $user->get_groups) : (), @{$species_defs->ENSEMBL_DEFAULT_USER_GROUPS || []} ], 
    servername => $species_defs->ENSEMBL_SERVERNAME,
    site_type  => $species_defs->ENSEMBL_SITETYPE,
    version    => $species_defs->ENSEMBL_VERSION,
    cache_tags => [],
  };
  
  bless $self, $class;
  
  $self->dbh;
  
  return $self;
}

sub hub          { return $_[0]{'hub'};        }
sub user_id      { return $_[0]{'user_id'};    }
sub servername   { return $_[0]{'servername'}; }
sub site_type    { return $_[0]{'site_type'};  }
sub version      { return $_[0]{'version'};    }
sub cache_tags   { return $_[0]{'cache_tags'}; }
sub group_ids    { return $_[0]{'group_ids'};  }
sub admin_groups { return $_[0]{'admin_groups'} ||= { map { $_->group_id => $_ } $_[0]->hub->user->find_admin_groups }; }
sub session_id   { return $_[0]{'session_id'}   ||= $_[0]->hub->session->session_id; }

sub dbh {
  return $DBH if $DBH and $DBH->ping;
  
  my $self = shift;
  my $sd   = $self->hub->species_defs;

  # try and get user db connection. If it fails the use backup port
  eval {
    $DBH = DBI->connect(sprintf('DBI:mysql:database=%s;host=%s;port=%s', $sd->ENSEMBL_USERDB_NAME, $sd->ENSEMBL_USERDB_HOST, $sd->ENSEMBL_USERDB_PORT),        $sd->ENSEMBL_USERDB_USER, $sd->ENSEMBL_USERDB_PASS) ||
           DBI->connect(sprintf('DBI:mysql:database=%s;host=%s;port=%s', $sd->ENSEMBL_USERDB_NAME, $sd->ENSEMBL_USERDB_HOST, $sd->ENSEMBL_USERDB_PORT_BACKUP), $sd->ENSEMBL_USERDB_USER, $sd->ENSEMBL_USERDB_PASS);
  };
  
  EnsEMBL::Web::Controller->disconnect_on_request_finish($DBH);
  
  return $DBH || undef;
}

sub record_type_query {
  my $self   = shift;
  my @ids    = grep $_, $self->session_id, $self->user_id;
  my @groups = @{$self->group_ids};
  my $where  = '(cd.record_type = "session" AND cd.record_type_id = ?)';
     $where .= qq{ OR (cd.record_type = "user" AND cd.record_type_id = ?)} if scalar @ids == 2;
     $where .= sprintf qq{ OR (cd.record_type = "group" AND cd.record_type_id IN (%s))}, join ',', map '?', @groups if scalar @groups;
     $where  = "($where) AND cd.site_type = ?";
  
  return ($where, @ids, @groups, $self->site_type);
}

sub all_configs {
  my $self = shift;
  
  if (!$self->{'all_configs'}) {
    $self->{'all_configs'} = $self->filtered_configs;
    
    #my @A = keys %{$self->{'all_configs'}};
    #warn "@@@ ALL CONFIGS @A";
    #use Data::Dumper; warn Dumper($self->{'all_configs'}{$A[0]}{'data'});
    
    foreach (values %{$self->{'all_configs'}}) {
      $_->{'raw_data'} = $_->{'data'};
      $_->{'data'}     = eval($_->{'data'}) || {};
      $self->{'active_config'}{$_->{'record_type'}}{$_->{'type'}}{$_->{'code'}} ||= $_->{'record_id'} if $_->{'active'} eq 'y';
    }
  }
  
  return $self->{'all_configs'};
}

sub filtered_configs {
  my ($self, $filter) = @_;
  my ($where, @args)  = $self->record_type_query;
  my $dbh = $self->dbh || return {};
  
  foreach (sort keys %{$filter || {}}) {
    if (ref $filter->{$_} eq 'ARRAY') {
      $where .= sprintf " AND $_ IN (%s)", join ',', map '?', @{$filter->{$_}};
      push @args, @{$filter->{$_}};
    } else {
      $where .= " AND $_ = ?";
      push @args, $filter->{$_};
    }
  }
  
  return $dbh->selectall_hashref("SELECT * FROM configuration_details cd, configuration_record cr WHERE cd.record_id = cr.record_id AND $where", 'record_id', {}, @args);
}

sub active_config {
  my ($self, $type, $code, $record_type) = @_;
  $self->all_configs unless $self->{'all_configs'};
  #my @A = keys %{$self->{'active_config'}};
  #warn ">>> @A";
  return $self->{'active_config'}{$record_type || ($self->user_id ? 'user' : 'session')}{$type}{$code};
}

sub get_config {
  my $self   = shift;
  my $config = $self->all_configs->{$self->active_config(@_)};
  #use Data::Dumper;
  #use Carp qw(cluck);
  #cluck ">>> GOT CONFIG ".Dumper($config->{'data'});
  
  # If there is no user record, but there is a session record, move the session record to the user account.
  # This means that users retain their settings when logging in after making a configuration
  if (!$config && $self->user_id) {
    my $record_id = $self->active_config(@_, 'session');
    
    if ($record_id) {
      $self->save_to_user($record_id);
      $config = $self->all_configs->{$record_id};
    }
  }
  
  $self->set_cache_tags($config);
  
  return $config->{'data'};
}

sub serialize_data {
  my ($self, $data) = @_;
  return Data::Dumper->new([ $data ])->Indent(0)->Sortkeys(1)->Terse(1)->Dump;
}

sub set_config {
  my ($self, %args) = @_;
  $args{'record_id'} ||= $self->active_config($args{'type'}, $args{'code'});
  
  my ($record_id) = $self->save_config(%args);
  
  return $record_id;
}

sub save_config {
  my ($self, %args) = @_;
  my $record_id = $args{'record_id'};
  my ($saved, $deleted, $data);
  
  if (scalar keys %{$args{'data'}}) {
    $data = $args{'data'};
  } else {
    delete $args{'data'};
  }
  
  if ($data) {
    $saved = $record_id ? $self->set_data($record_id, $data) : $self->new_config(%args, data => $data);
  } elsif ($record_id) {
    ($deleted) = $self->delete_config($record_id, $args{'record_type'} eq 'user' ? $self->active_config($args{'type'}, $args{'code'}, 'session') : ());
  }
  
  return ($saved, $deleted);
}

sub new_config {
  my ($self, %args) = @_;
  my $dbh = $self->dbh || return;
  
  return unless $args{'type'} && $args{'code'};
  
  return unless $dbh->do(
    'INSERT INTO configuration_details (record_type, record_type_id, is_set, name, description, servername, site_type, release_number) VALUES (?, ?, "n", ?, ?, ?, ?, ?)', {},
    map(encode_entities($args{$_}) || '', qw(record_type record_type_id name description)), $self->servername, $self->site_type, $self->version
  );
  
  my $record_id = $dbh->last_insert_id(undef, undef, 'configuration_details', 'record_id');
  my $data      = ref $args{'data'} ? $self->serialize_data($args{'data'}) : $args{'data'};
  my $set_ids   = delete $args{'set_ids'};
  
  return unless $dbh->do('INSERT INTO configuration_record VALUES (?, ?, ?, ?, NULL, ?, ?, now(), now())', {}, $record_id, $args{'type'}, $args{'code'}, $args{'active'} || '', $args{'link_code'}, $data || '');
  
  $self->update_set_record($record_id, $set_ids) if $set_ids && scalar @$set_ids;
  
  $self->all_configs->{$record_id} = {
    record_id => $record_id,
    %args
  };
  
  $self->all_configs->{$record_id}{'data'}     = eval($args{'data'}) || {} unless ref $args{'data'};
  $self->all_configs->{$record_id}{'raw_data'} = $data;
  
  $self->{'active_config'}{$args{'record_type'}}{$args{'type'}}{$args{'code'}} = $record_id if $args{'active'};
  
  return $record_id;
}

sub link_configs {
  my ($self, @links) = @_;
  my $dbh = $self->dbh || return;
  
  if (scalar @links == 1) {
    my $active = $self->active_config(@{$links[0]{'link'}});
    push @links, { id => $active, code => $links[0]{'link'}[1] };
  }
  
  return unless scalar @links == 2;
  
  my $configs = $self->all_configs;
  
  $_->{'id'} = undef for grep !$configs->{$_->{'id'}}, @links;
  
  return unless grep $_->{'id'}, @links;
  
  my $query = 'UPDATE configuration_record SET link_id = ?, link_code = ? WHERE record_id = ?';
  my $sth   = $dbh->prepare($query);
  
  foreach ([ @links ], [ reverse @links ]) {
    if ($_->[0]{'id'} && ($configs->{$_->[0]{'id'}}{'link_id'} != $_->[1]{'id'} || $configs->{$_->[0]{'id'}}{'link_code'} ne $_->[1]{'code'})) {
      $sth->execute($_->[1]{'id'}, $_->[1]{'code'}, $_->[0]{'id'});
      $configs->{$_->[0]{'id'}}{'link_id'}   = $_->[1]{'id'};
      $configs->{$_->[0]{'id'}}{'link_code'} = $_->[1]{'code'};
    }
  }
}

sub link_configs_by_id {
  my ($self, @ids) = @_;
  
  return unless scalar @ids == 2;
  
  my $dbh   = $self->dbh || return;
  my $query = 'UPDATE configuration_record SET link_id = ? WHERE record_id = ?';
  my $sth   = $dbh->prepare($query);
  
  $sth->execute(@ids);
  $sth->execute(reverse @ids);
}

sub set_data {
  my ($self, $record_id, $data) = @_;
  my $dbh        = $self->dbh || return;
  my $config     = $self->all_configs->{$record_id};
  my $serialized = ref $data ? $self->serialize_data($data) : $data;
  
  if ($serialized ne $config->{'raw_data'}) {
    $dbh->do('UPDATE configuration_record SET modified_at = now(), data = ? WHERE record_id = ?', {}, $serialized, $record_id);
    
    $config->{'data'}     = ref $data ? $data : eval($data) || {};
    $config->{'raw_data'} = $serialized;
  }
  
  $self->set_cache_tags($self->all_configs->{$record_id});
  
  return $record_id;
}

sub delete_config {
  my ($self, @record_ids) = @_;
  my $dbh     = $self->dbh || return ();
  my $configs = $self->all_configs;
  my @deleted;
  
  foreach my $record_id (grep $configs->{$_}, @record_ids) {
    $dbh->do('DELETE FROM configuration_details WHERE record_id = ?', {}, $record_id);
    $dbh->do('DELETE FROM configuration_record  WHERE record_id = ?', {}, $record_id);
    
    if ($configs->{$record_id}{'link_id'}) {
      $dbh->do('UPDATE configuration_record SET link_id = NULL WHERE record_id = ?', {}, $configs->{$record_id}{'link_id'});
      $configs->{$configs->{$record_id}{'link_id'}}->{'link_id'} = undef;
    }
    
    delete $configs->{$record_id};
    
    push @deleted, $record_id;
  }
  
  $self->delete_records_from_sets(undef, @deleted) if scalar @deleted;
  
  return @deleted;
}

sub update_active {
  my ($self, $id) = @_;
  my $configs = $self->all_configs;
  my (@new_ids, $sth);
  
  foreach my $config (map $configs->{$_} || (), $id, $configs->{$id}{'link_id'}) {
    my $active = $self->active_config($config->{'type'}, $config->{'code'});
    
    if ($active) {
      # set the active config's data to be the selected config's data.
      push @new_ids, $self->set_data($active, $config->{'data'});
      $self->delete_config($configs->{$active}{'link_id'}) if $configs->{$active}{'link_id'} && !$config->{'link_id'};
    } else {
      # clone the selected config's record, but change record_type and record_type_id if it belongs to a group
      my %record_type;
      
      if ($config->{'record_type'} eq 'group') {
        my $user_id = $self->user_id;
        
        $record_type{'record_type'}    = $user_id ? 'user' : 'session';
        $record_type{'record_type_id'} = $user_id || $self->session_id;
      }
      
      push @new_ids, $self->new_config(%$config, %record_type, data => $config->{'data'}, active => 'y', name => '', description => '');
      $self->delete_config($self->active_config($config->{'type'} eq 'view_config' ? 'image_config' : 'view_config', $config->{'link_code'})) if $config->{'link_code'} && !$config->{'link_id'};
    }
    
    $self->set_cache_tags($config);
  }
  
  $self->link_configs_by_id(@new_ids);
  
  return scalar @new_ids;
}

sub edit_details {
  my ($self, $record_id, $type, $value, $is_set) = @_;
  my $dbh     = $self->dbh || return 0;
  my $details = $is_set ? $self->all_sets : $self->all_configs;
  my $config  = $details->{$record_id};
  my $success = 0;
  
  foreach (grep $_, $config, $details->{$config->{'link_id'}}) { 
    if ($_->{$type} ne $value) {
      $dbh->do("UPDATE configuration_details SET $type = ? WHERE record_id = ?", {}, encode_entities($value), $_->{'record_id'});
      $_->{$type} = $value;
      $success    = 1;
    }
  }
  
  return $success;
}

sub all_sets {
  my $self = shift;
  my $dbh  = $self->dbh || return {};
  
  if (!$self->{'all_sets'}) {
    my ($where, @args) = $self->record_type_query;
    
    $self->{'all_sets'} = $dbh->selectall_hashref("SELECT * FROM configuration_details cd WHERE is_set = 'y' AND $where", 'record_id', {}, @args);
    
    foreach my $set (values %{$self->{'all_sets'}}) {
      foreach (map $_->[0], @{$dbh->selectall_arrayref('SELECT record_id FROM configuration_set WHERE set_id = ?', {}, $set->{'record_id'})}) {
        $set->{'records'}{$_} = 1;
        $self->{'records_to_sets'}{$_}{$set->{'record_id'}} = 1;
      }
    }
  }
  
  return $self->{'all_sets'};
}

sub record_to_sets {
  my ($self, $record_id) = @_;
  my $sets = $self->all_sets;
  return keys %{$self->{'records_to_sets'}{$record_id}};
}

sub create_set {
  my ($self, %args) = @_;
  my $dbh        = $self->dbh || return;
  my $configs    = $self->all_configs;
  my @record_ids = grep $configs->{$_}, @{$args{'record_ids'}};
  
  return unless @record_ids;
  
  $dbh->do('INSERT INTO configuration_details VALUES ("", ?, ?, "y", ?, ?, ?, ?, ?)', {}, map(encode_entities($args{$_}) || '', qw(record_type record_type_id name description)), map $self->$_, qw(servername site_type version));
  
  my $set_id = $dbh->last_insert_id(undef, undef, 'configuration_details', 'record_id');
  
  $self->all_sets->{$set_id} = {
    set_id => $set_id,
    %args
  };
  
  $self->add_records_to_set($set_id, @record_ids);
  
  return $set_id;
}

sub activate_set {
  my ($self, $id) = @_;
  my $set = $self->all_sets->{$id};
  
  return unless $set;
  
  my $configs = $self->all_configs;
  my %record_ids;
  
  foreach (keys %{$set->{'records'}}) {
    $record_ids{$_} = 1 unless exists $record_ids{$configs->{$_}{'link_id'}};
  }
  
  $self->update_active($_) for keys %record_ids;
  
  return 1;
}

sub update_set_record {
  my ($self, $record_id, $ids) = @_;
  my $dbh     = $self->dbh || return [];
  my $configs = $self->all_configs;
  my $sets    = $self->all_sets;
  my $code    = $configs->{$record_id}{$configs->{$record_id}{'type'} eq 'view_config' ? 'code' : 'link_code'};
  my @set_ids;
  
  foreach (grep $sets->{$_}, @$ids) {
    my %set_has = map { $configs->{$_}{$configs->{$_}{'type'} eq 'view_config' ? 'code' : 'link_code'} => 1 } keys %{$sets->{$_}{'records'}};
    push @set_ids, $_ unless $set_has{$code}; # Don't allow the config to be added to a set if the set already contains a config of that type and code
  }
  
  return [] unless scalar @set_ids;
  return [] unless $dbh->do(sprintf('INSERT INTO configuration_set VALUES %s', join ', ', map '(?, ?)', @set_ids), {}, map { $_, $record_id } @set_ids);
  
  foreach (@set_ids) {
    $sets->{$_}{'records'}{$record_id}         = 1;
    $self->{'records_to_sets'}{$record_id}{$_} = 1;
  }
  
  return \@set_ids;
}

sub delete_set {
  my ($self, $set_id) = @_;
  my $dbh  = $self->dbh || return;
  my $sets = $self->all_sets;
  
  return unless $sets->{$set_id};

  $dbh->do('DELETE FROM configuration_set     WHERE set_id    = ?', {}, $set_id);
  $dbh->do('DELETE FROM configuration_details WHERE record_id = ?', {}, $set_id);
  
  delete $sets->{$set_id};
  delete $_->{$set_id} for values %{$self->{'records_to_sets'}};
  
  return $set_id;
}

sub add_records_to_set {
  my ($self, $set_id, @record_ids) = @_;
  my $dbh     = $self->dbh || return [];
  my $configs = $self->all_configs;
  my %set_has = map { $configs->{$_}{$configs->{$_}{'type'} eq 'view_config' ? 'code' : 'link_code'} => 1 } keys %{$self->{'all_sets'}{$set_id}{'records'}};
  
  # Don't allow configs to be added to a set if the set already contains a config of that type and code
  @record_ids = grep $configs->{$_} && !$set_has{$configs->{$_}{$configs->{$_}{'type'} eq 'view_config' ? 'code' : 'link_code'}}, @record_ids;
  
  return [] unless scalar @record_ids;
  return [] unless $dbh->do(sprintf('INSERT INTO configuration_set VALUES %s', join ', ', map '(?, ?)', @record_ids), {}, map { $set_id, $_ } @record_ids);
  
  foreach (@record_ids) {
    $self->{'all_sets'}{$set_id}{'records'}{$_} = 1;
    $self->{'records_to_sets'}{$_}{$set_id}     = 1;
  }
  
  return \@record_ids;
}

sub delete_records_from_sets {
  my ($self, $set_id, @record_ids) = @_;
  my $dbh  = $self->dbh || return;
  my $sets = $self->all_sets;
  
  return if $set_id && !$sets->{$set_id};
  
  my $where   = $set_id ? ' AND set_id = ?' : '';
  my $deleted = $dbh->do(sprintf('DELETE FROM configuration_set WHERE record_id IN (%s)%s', join(',', map '?', @record_ids), $where), {}, @record_ids, $set_id);
  
  foreach my $record_id (@record_ids) {
    my @set_ids = $self->record_to_sets($record_id);
    
    delete $sets->{$_}{'records'}{$record_id} for $set_id || @set_ids;
    
    if ($set_id && scalar @set_ids > 1) {
      delete $self->{'records_to_sets'}{$record_id}{$set_id};
    } else {
      delete $self->{'records_to_sets'}{$record_id};
    }
  }
  
  return $deleted;
}

sub delete_sets_from_record {
  my ($self, $record_id, @set_ids) = @_;
  my $dbh = $self->dbh || return;
  
  return unless $self->all_configs->{$record_id};
  
  my $sets    = $self->all_sets;
  my $deleted = $dbh->do(sprintf('DELETE FROM configuration_set WHERE record_id = ? AND set_id IN (%s)', join(',', map '?', @set_ids)), {}, $record_id, @set_ids);
  
  foreach (@set_ids) {
    delete $sets->{$_}{'records'}{$record_id};
    delete $self->{'records_to_sets'}{$record_id}{$_};
    delete $self->{'records_to_sets'}{$record_id} unless scalar keys %{$self->{'records_to_sets'}{$record_id}};
  }
  
  return $deleted;
}

# update records for a set
sub edit_set_records {
  my ($self, $set_id, @record_ids) = @_;
  my $set = $self->all_sets->{$set_id};
  
  return unless $set;
 
  my $record_type    = $set->{'record_type'};
  my $record_type_id = $set->{'record_type_id'};
  my $configs        = $self->all_configs;
  my %record_ids     = map { $_ => 1 } @record_ids;
  my @new            = grep $record_type eq $configs->{$_}{'record_type'} && $record_type_id eq $configs->{$_}{'record_type_id'} && !$set->{'records'}{$_}, @record_ids;
  my @delete         = grep $record_type eq $configs->{$_}{'record_type'} && $record_type_id eq $configs->{$_}{'record_type_id'} && !$record_ids{$_}, keys %{$set->{'records'}};
  my $updated;
  
  $updated->{'removed'} = \@delete if scalar @delete && $self->delete_records_from_sets($set_id, @delete);
  $updated->{'added'}   = $self->add_records_to_set($set_id, @new);
  
  return $updated;
}

# update sets for a record
sub edit_record_sets {
  my ($self, $record_id, @set_ids) = @_;
  my $record = $self->all_configs->{$record_id};
  
  return unless $record;
  
  my $record_type    = $record->{'record_type'};
  my $record_type_id = $record->{'record_type_id'};
  my $sets           = $self->all_sets;
  my %existing       = map { $_ => 1 } $self->record_to_sets($record_id);
  my %set_ids        = map { $_ => 1 } @set_ids;
  my @new            = grep $record_type eq $sets->{$_}{'record_type'} && $record_type_id eq $sets->{$_}{'record_type_id'} && !$existing{$_}, @set_ids;
  my @delete         = grep $record_type eq $sets->{$_}{'record_type'} && $record_type_id eq $sets->{$_}{'record_type_id'} && !$set_ids{$_}, keys %existing;
  my $updated;
  
  $updated->{'removed'} = \@delete if scalar @delete && $self->delete_sets_from_record($record_id, @delete);
  $updated->{'added'}   = $self->update_set_record($record_id, \@new);
  
  return $updated;
}

sub save_to_user {
  my ($self, $record_id, $is_set) = @_;
  my $user_id = $self->user_id || return;
  my $dbh     = $self->dbh     || return;
  my $configs = $self->all_configs;
  my $records = $is_set ? $self->all_sets : $configs;
  my $record  = $records->{$record_id} || return;
  
  return unless $record->{'record_type'} eq 'session';
  
  my $updated;
  
  foreach (grep $_, $record, $configs->{$record->{'link_id'}}) {
    $updated += $dbh->do('UPDATE configuration_details SET record_type = "user", record_type_id = ? WHERE record_id = ?', {}, $user_id, $_->{'record_id'});
    $_->{'record_type'}    = 'user';
    $_->{'record_type_id'} = $user_id;
  }
  
  return $updated;
}

# Share a configuration or set with another user
sub share {
  my ($self, $record_ids, $checksum, $group_id, $link_id) = @_;
  my $dbh          = $self->dbh || return [];
  my $group        = $group_id ? $self->admin_groups->{$group_id} : undef;
  my %record_types = ( session => $self->session_id, user => $self->user_id, group => $group_id );
  my $record_type  = $group ? 'group' : 'session';
  my @new_record_ids;
  
  foreach (@$record_ids) {
    my $record = $dbh->selectall_hashref('SELECT * FROM configuration_details cd, configuration_record cr WHERE cd.record_id = cr.record_id AND cr.record_id = ?', 'record_id', {}, $_)->{$_};
    
    next unless $record;
    next if $group_id && !$group;
    next if !$group && $record_types{$record->{'record_type'}} eq $record->{'record_type_id'}; # Don't share with yourself
    next if $checksum && md5_hex($self->serialize_data($record)) ne $checksum;
    
    my ($exists) = grep {
      !$_->{'active'}                       &&
      $_->{'type'}     eq $record->{'type'} &&
      $_->{'code'}     eq $record->{'code'} &&
      $_->{'raw_data'} eq $record->{'data'} &&
      ($group ? $_->{'record_type_id'} eq $group_id : 1)
    } values %{$self->all_configs};
    
    # Don't duplicate records with the same data
    my $new_record_id = $exists ? $exists->{'record_id'} : $self->new_config(
      %$record,
      record_type    => $record_type,
      record_type_id => $record_types{$record_type}, 
      active         => '',
      map({ $_ => decode_entities($record->{$_}) || '' } qw(name description))
    ); 
    
    if ($record->{'link_id'}) {
      if ($link_id) {
        $self->link_configs_by_id($new_record_id, $link_id);
      } else {
        $self->share([ $record->{'link_id'} ], undef, $group_id, $new_record_id);
      }
    }
    
    $self->update_active($new_record_id) unless $group;
    
    push @new_record_ids, $new_record_id;
  }
  
  return \@new_record_ids;
}

sub share_record {
  my ($self, $record_id, $checksum, $group_id) = @_;
  return $checksum ? $self->share([ $record_id ], $checksum, $group_id) : undef;
}

sub share_set {
  my ($self, $set_id, $checksum, $group_id) = @_;
  my $dbh          = $self->dbh || return;
  my $group        = $group_id ? $self->admin_groups->{$group_id} : undef;
  my %record_types = ( session => $self->session_id, user => $self->user_id, group => $group_id );
  my $record_type  = $group ? 'group' : 'session';
  
  my $session_id = $self->session_id;
  
  my $set = $dbh->selectall_hashref('SELECT * FROM configuration_details WHERE is_set = "y" AND record_id = ?', 'record_id', {}, $set_id)->{$set_id};
  
  return unless $set;
  return if $group_id && !$group;
  return if !$group && $record_types{$set->{'record_type'}} eq $set->{'record_type_id'}; # Don't share with yourself
  return unless md5_hex($self->serialize_data($set)) eq $checksum;
  
  my $record_ids = $self->share([ map $_->[0], @{$dbh->selectall_arrayref('SELECT record_id FROM configuration_set WHERE set_id = ?', {}, $set_id)} ], undef, $group ? $group_id : undef);
  my $serialized = $self->serialize_data([ sort @$record_ids ]);
  
  # Don't make a new set if one exists with the same records as the share
  foreach (values %{$self->all_sets}) {
    return $_->{'record_id'} if $self->serialize_data([ sort keys %{$_->{'records'}} ]) eq $serialized;
  }
  
  return $self->create_set(
    %$set,
    record_type    => $record_type,
    record_type_id => $record_types{$record_type},
    record_ids     => $record_ids
  );
}

sub set_cache_tags {
  my ($self, $config) = @_;
  $ENV{'CACHE_TAGS'}{$config->{'type'}} = sprintf '%s[%s]', uc($config->{'type'}), md5_hex(join '::', $config->{'code'}, $self->serialize_data($config->{'data'})) if $config;
}

# not currently used, but written in case we need it in future
sub disconnect {
  return unless $DBH;
  $DBH->disconnect;
  undef $DBH;
}

1;
