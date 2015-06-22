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

my $DBH_SESSION; # package database handle for persistence
my $DBH_USER;

sub new {
  my ($class, $hub) = @_;
  my $species_defs  = $hub->species_defs;
  my $user          = $hub->user;
  my $self          = {
    hub        => $hub,
    session_id => $hub->session->create_session_id,
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
sub session_id   { return $_[0]{'session_id'}   ||= $_[0]->hub->session->create_session_id; }

sub dbh {
  my $self = shift;
  my $dbhs = {};

  for (qw(session user)) {
    my $method    = "_dbh_$_";
    my $dbh       = $self->$method or next;
    $dbhs->{$_}   = $dbh;
  }

  return keys %$dbhs ? $dbhs : undef;
}

sub _dbh_session {
  return $DBH_SESSION if $DBH_SESSION and $DBH_SESSION->ping;

  my $self  = shift;
  my $db    = $self->hub->species_defs->session_db;

  # try and get session db connection
  eval {
    $DBH_SESSION = DBI->connect(sprintf('DBI:mysql:database=%s;host=%s;port=%s', $db->{'NAME'}, $db->{'HOST'}, $db->{'PORT'}), $db->{'USER'}, $db->{'PASS'});
  };

  EnsEMBL::Web::Controller->disconnect_on_request_finish($DBH_SESSION);

  return $DBH_SESSION || undef;
}

sub _dbh_user {
  return $DBH_USER if $DBH_USER and $DBH_USER->ping;

  my $self  = shift;
  my $hub   = $self->hub;

  return unless $hub->users_available;

  my $db = $hub->species_defs->accounts_db;

  # try and get accounts db connection
  eval {
    $DBH_USER = DBI->connect(sprintf('DBI:mysql:database=%s;host=%s;port=%s', $db->{'NAME'}, $db->{'HOST'}, $db->{'PORT'}), $db->{'USER'}, $db->{'PASS'});
  };

  EnsEMBL::Web::Controller->disconnect_on_request_finish($DBH_USER);

  return $DBH_USER || undef;
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

    foreach (keys %{$self->{'all_configs'}}) {
      my $config = $self->{'all_configs'}{$_};
      $config->{'raw_data'} = $config->{'data'};
      $config->{'data'}     = eval($config->{'data'}) || {};
      $self->{'active_config'}{$config->{'record_type'}}{$config->{'type'}}{$config->{'code'}} ||= $_ if $config->{'active'} eq 'y';
    }
  }
  
  return $self->{'all_configs'};
}

sub filtered_configs {
  my ($self, $filter) = @_;
  my ($where, @args)  = $self->record_type_query;

  my $dbh = $self->dbh or return {};

  foreach (sort keys %{$filter || {}}) {
    if (ref $filter->{$_} eq 'ARRAY') {
      $where .= sprintf " AND $_ IN (%s)", join ',', map '?', @{$filter->{$_}};
      push @args, @{$filter->{$_}};
    } else {
      $where .= " AND $_ = ?";
      push @args, $filter->{$_};
    }
  }

  my $configs = {};

  for (keys %$dbh) {
    for (@{$dbh->{$_}->selectall_arrayref("SELECT * FROM configuration_details cd, configuration_record cr WHERE cd.record_id = cr.record_id AND $where", { Slice => {} }, @args)}) {
      $_->{'config_key'}  = get_config_key($_->{'record_type'}, $_->{'record_id'});
      $_->{'link_key'}    = get_config_key($_->{'record_type'}, $_->{'link_id'}) if $_->{'link_id'};
      $configs->{$_->{'config_key'}} = $_;
    }
  }

  return $configs;
}

sub active_config {
  my ($self, $type, $code, $record_type) = @_;
  $self->all_configs unless $self->{'all_configs'};

  return $self->{'active_config'}{$record_type || ($self->user_id ? 'user' : 'session')}{$type}{$code};
}

sub get_config {
  my $self        = shift;
  my $config_key  = $self->active_config(@_);
  my $config      = $config_key ? $self->all_configs->{$config_key} : undef;

  # If there is no user record, but there is a session record, move the session record to the user account.
  # This means that users retain their settings when logging in after making a configuration
  if (!$config && $self->user_id) {
    $config_key = $self->active_config(@_, 'session');

    if ($config_key) {
      $self->save_to_user($config_key);
      $config_key = $self->active_config(@_);
      $config = $self->all_configs->{$config_key};
    }
  }
  
  $self->set_cache_tags($config);
  
  return $config->{'data'};
}

sub serialize_data {
  my ($self, $data) = @_;
  return Data::Dumper->new([ $data ])->Indent(0)->Sortkeys(1)->Terse(1)->Useqq(1)->Maxdepth(0)->Dump;
}

sub set_config {
  my ($self, %args) = @_;
  my $config_key = $args{'record_id'} ? get_config_key($args{'record_type'}, $args{'record_id'}) : $self->active_config($args{'type'}, $args{'code'});

  $args{'config_key'} = $config_key;

  ($config_key) = $self->save_config(%args);
  
  return $config_key;
}

sub save_config {
  my ($self, %args) = @_;

  my $config_key = $args{'config_key'};

  my ($saved, $deleted, $data);
  
  if (scalar keys %{$args{'data'} || {}}) {
    $data = $args{'data'};
  } else {
    delete $args{'data'};
  }
  
  if ($data) {
    $saved = $config_key ? $self->set_data($config_key, $data) : $self->new_config(%args, data => $data);
  } elsif ($config_key) {
    ($deleted) = $self->delete_config($config_key, $args{'record_type'} ne 'session' ? $self->active_config($args{'type'}, $args{'code'}, 'session') : ());
  }
  
  return ($saved, $deleted);
}

sub new_config {
  ## @return Config key string for the newly created config record
  my ($self, %args) = @_;

  return unless $args{'type'} && $args{'code'};

  my $dbh = $self->dbh or return;
     $dbh = $dbh->{$args{'record_type'} eq 'session' ? 'session' : 'user'} or return;

  return unless $dbh->do(
    'INSERT INTO configuration_details (record_type, record_type_id, is_set, name, description, servername, site_type, release_number) VALUES (?, ?, "n", ?, ?, ?, ?, ?)', {},
    map(encode_entities($args{$_}) || '', qw(record_type record_type_id name description)), $self->servername, $self->site_type, $self->version
  );
  
  my $record_id = $dbh->last_insert_id(undef, undef, 'configuration_details', 'record_id');
  my $data      = ref $args{'data'} ? $self->serialize_data($args{'data'}) : $args{'data'};
  my $set_ids   = delete $args{'set_ids'};
  
  return unless $dbh->do('INSERT INTO configuration_record VALUES (?, ?, ?, ?, NULL, ?, ?, now(), now())', {}, $record_id, $args{'type'}, $args{'code'}, $args{'active'} || '', $args{'link_code'}, $data || '');

  my $config_key = get_config_key($args{'record_type'}, $record_id);

  $self->update_set_record($config_key, $set_ids) if $set_ids && scalar @$set_ids;

  $self->all_configs->{$config_key} = {
    config_key  => $config_key,
    record_id   => $record_id,
    %args
  };

  $self->all_configs->{$config_key}{'link_key'} = get_config_key($args{'record_type'}, $args{'link_id'}) if $args{'link_id'};
  $self->all_configs->{$config_key}{'data'}     = eval($args{'data'}) || {} unless ref $args{'data'};
  $self->all_configs->{$config_key}{'raw_data'} = $data;

  $self->{'active_config'}{$args{'record_type'}}{$args{'type'}}{$args{'code'}} = $config_key if $args{'active'};

  return $config_key;
}

sub link_configs {
  my ($self, @links) = @_;
  my $db_type = get_db_type(map { $_->{'id'} || () } @links);
  my $dbh     = $self->dbh or return;
     $dbh     = $dbh->{$db_type} or return;
  
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
    if ($_->[0]{'id'} && ($configs->{$_->[0]{'id'}}{'link_key'} != $_->[1]{'id'} || $configs->{$_->[0]{'id'}}{'link_code'} ne $_->[1]{'code'})) {
      $sth->execute(get_db_id($_->[1]{'id'}), $_->[1]{'code'}, get_db_id($_->[0]{'id'}));
      $configs->{$_->[0]{'id'}}{'link_id'}   = get_db_id($_->[1]{'id'});
      $configs->{$_->[0]{'id'}}{'link_key'}  = $_->[1]{'id'};
      $configs->{$_->[0]{'id'}}{'link_code'} = $_->[1]{'code'};
    }
  }
}

sub link_configs_by_keys {
  my ($self, @config_keys) = @_;
  
  return unless scalar @config_keys == 2;
  
  my $dbh   = $self->dbh or return;
     $dbh   = $dbh->{get_db_type($config_keys[0])} or return;
  my @ids   = map get_db_id($_), @config_keys;
  my $query = 'UPDATE configuration_record SET link_id = ? WHERE record_id = ?';
  my $sth   = $dbh->prepare($query);
  
  $sth->execute(@ids);
  $sth->execute(reverse @ids);
}

sub set_data {
  my ($self, $config_key, $data) = @_;
  my $dbh        = $self->dbh or return;
     $dbh        = $dbh->{get_db_type($config_key)} or return;
  my $config     = $self->all_configs->{$config_key};
  my $serialized = ref $data ? $self->serialize_data($data) : $data;
  
  if ($serialized ne $config->{'raw_data'}) {
    $dbh->do('UPDATE configuration_record SET modified_at = now(), data = ? WHERE record_id = ?', {}, $serialized, get_db_id($config_key));
    
    $config->{'data'}     = ref $data ? $data : eval($data) || {};
    $config->{'raw_data'} = $serialized;
  }
  
  $self->set_cache_tags($config);
  
  return $config_key;
}

sub delete_config {
  my ($self, @config_keys) = @_;
  my $dbh     = $self->dbh or return ();
  my $configs = $self->all_configs;
  my @deleted;
  
  foreach my $config_key (grep $configs->{$_}, @config_keys) {
    my $db_type   = get_db_type($config_key);
    my $record_id = get_db_id($config_key);

    next unless $dbh->{$db_type};

    $dbh->{$db_type}->do('DELETE FROM configuration_details WHERE record_id = ?', {}, $record_id);
    $dbh->{$db_type}->do('DELETE FROM configuration_record  WHERE record_id = ?', {}, $record_id);
    
    if ($configs->{$config_key}{'link_id'}) {
      $dbh->{$db_type}->do('UPDATE configuration_record SET link_id = NULL WHERE record_id = ?', {}, $configs->{$config_key}{'link_id'});
      $configs->{get_config_key($configs->{$config_key}{'record_type'}, $configs->{$config_key}{'link_id'})}->{'link_id'} = undef;
    }
    
    delete $configs->{$config_key};
    
    push @deleted, $config_key;
  }
  
  $self->delete_records_from_sets(undef, @deleted) if scalar @deleted;
  
  return @deleted;
}

sub update_active {
  my ($self, $config_key) = @_;
  my $configs = $self->all_configs;
  my (@new_config_keys, $sth);
  
  foreach my $config (map $configs->{$_} || (), $config_key, get_config_key($configs->{$config_key}{'record_type'}, $configs->{$config_key}{'link_id'})) {
    my $active_config_key = $self->active_config($config->{'type'}, $config->{'code'});
    
    if ($active_config_key) {
      # set the active config's data to be the selected config's data.
      push @new_config_keys, $self->set_data($active_config_key, $config->{'data'});
      $self->delete_config(get_config_key($configs->{$active_config_key}{'record_type'}, $configs->{$active_config_key}{'link_id'})) if $configs->{$active_config_key}{'link_id'} && !$config->{'link_id'};
    } else {
      # clone the selected config's record, but change record_type and record_type_id if it belongs to a group
      my %record_type;
      
      if ($config->{'record_type'} eq 'group') {
        my $user_id = $self->user_id;
        
        $record_type{'record_type'}    = $user_id ? 'user' : 'session';
        $record_type{'record_type_id'} = $user_id || $self->session_id;
      }
      
      push @new_config_keys, $self->new_config(%$config, %record_type, data => $config->{'data'}, active => 'y', name => '', description => '');
      $self->delete_config($self->active_config($config->{'type'} eq 'view_config' ? 'image_config' : 'view_config', $config->{'link_code'})) if $config->{'link_code'} && !$config->{'link_id'};
    }
    
    $self->set_cache_tags($config);
  }
  
  $self->link_configs_by_keys(@new_config_keys);
  
  return scalar @new_config_keys;
}

sub edit_details {
  my ($self, $config_key, $type, $value, $is_set) = @_;
  my $db_type = get_db_type($config_key);
  my $dbh     = $self->dbh or return 0;
     $dbh     = $dbh->{$db_type} or return 0;
  my $all_rec = $is_set ? $self->all_sets : $self->all_configs;
  my $config  = $all_rec->{$config_key};
  my $success = 0;
  
  foreach (grep $_, $config, $all_rec->{get_config_key($db_type, $config->{'link_id'})}) {
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
  my $dbhs = $self->dbh or return {};

  if (!$self->{'all_sets'}) {
    my ($where, @args) = $self->record_type_query;

    $self->{'all_sets'} = {};

    for (keys %$dbhs) {
      my $dbh   = $dbhs->{$_};
      my $sets  = $dbh->selectall_arrayref("SELECT * FROM configuration_details cd WHERE is_set = 'y' AND $where", { Slice => {} }, @args);

      foreach my $set (@$sets) {
        my $set_key = get_config_key($set->{'record_type'}, $set->{'record_id'});

        foreach (map $_->[0], @{$dbh->selectall_arrayref('SELECT record_id FROM configuration_set WHERE set_id = ?', {}, $set->{'record_id'})}) {
          my $config_key = get_config_key($set->{'record_type'}, $_);
          $set->{'records'}{$config_key} = 1;
          $self->{'records_to_sets'}{$config_key}{$set_key} = 1;
        }

        $self->{'all_sets'}->{$set_key} = $set;
      }
    }
  }

  return $self->{'all_sets'};
}

sub record_to_sets {
  my ($self, $config_key) = @_;
  my $sets = $self->all_sets;
  return keys %{$self->{'records_to_sets'}{$config_key}};
}

sub create_set {
  # TODO
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
  my ($self, $set_key) = @_;
  my $set = $self->all_sets->{$set_key};
  
  return unless $set;
  
  my $configs = $self->all_configs;
  my %config_keys;
  
  foreach (keys %{$set->{'records'}}) {
    $config_keys{$_} = 1 unless exists $config_keys{get_config_key($configs->{$_}{'record_type'}, $configs->{$_}{'link_id'})};
  }
  
  $self->update_active($_) for keys %config_keys;
  
  return 1;
}

sub update_set_record {
  my ($self, $config_key, $set_keys) = @_;
  my $db_type = get_db_type($config_key);
  my $dbh     = $self->dbh or return [];
     $dbh     = $dbh->{$db_type} or return [];
  my $configs = $self->all_configs;
  my $sets    = $self->all_sets;
  my $code    = $configs->{$config_key}{$configs->{$config_key}{'type'} eq 'view_config' ? 'code' : 'link_code'};
  my @set_keys;
  
  foreach (grep $sets->{$_}, @$set_keys) {
    my %set_has = map { $configs->{$_}{$configs->{$_}{'type'} eq 'view_config' ? 'code' : 'link_code'} => 1 } keys %{$sets->{$_}{'records'}};
    push @set_keys, $_ unless $set_has{$code}; # Don't allow the config to be added to a set if the set already contains a config of that type and code
  }

  my $record_id = get_db_id($config_key);
  my @set_ids   = map get_db_id($_), @set_keys;

  return [] unless scalar @set_ids;
  return [] unless $dbh->do(sprintf('INSERT INTO configuration_set VALUES %s', join ', ', map '(?, ?)', @set_ids), {}, map { $_, $record_id } @set_ids);
  
  foreach (@set_keys) {
    $sets->{$_}{'records'}{$config_key}         = 1;
    $self->{'records_to_sets'}{$config_key}{$_} = 1;
  }
  
  return \@set_keys;
}

sub delete_set {
  my ($self, $set_key) = @_;
  my $dbh  = $self->dbh || return;
     $dbh  = $dbh->{get_db_type($set_key)};
  my $sets = $self->all_sets;
  
  return unless $sets->{$set_key};

  my $set_id = get_db_id($set_key);

  $dbh->do('DELETE FROM configuration_set     WHERE set_id    = ?', {}, $set_id);
  $dbh->do('DELETE FROM configuration_details WHERE record_id = ?', {}, $set_id);
  
  delete $sets->{$set_key};
  delete $_->{$set_key} for values %{$self->{'records_to_sets'}};
  
  return $set_key;
}

sub add_records_to_set {
  my ($self, $set_key, @record_keys) = @_;
  my $db_type = get_db_type($set_key);
  my $dbh     = $self->dbh or return [];
     $dbh     = $dbh->{$db_type} or return [];
  my $configs = $self->all_configs;
  my %set_has = map { $configs->{$_}{$configs->{$_}{'type'} eq 'view_config' ? 'code' : 'link_code'} => 1 } keys %{$self->{'all_sets'}{$set_key}{'records'}};
  
  # Don't allow configs to be added to a set if the set already contains a config of that type and code
  @record_keys = grep $configs->{$_} && !$set_has{$configs->{$_}{$configs->{$_}{'type'} eq 'view_config' ? 'code' : 'link_code'}}, @record_keys;

  my $set_id      = get_db_id($set_key);
  my @record_ids  = map get_db_id($_), @record_keys;

  return [] unless scalar @record_ids;
  return [] unless $dbh->do(sprintf('INSERT INTO configuration_set VALUES %s', join ', ', map '(?, ?)', @record_ids), {}, map { $set_id, $_ } @record_ids);
  
  foreach (@record_keys) {
    $self->{'all_sets'}{$set_key}{'records'}{$_} = 1;
    $self->{'records_to_sets'}{$_}{$set_key}     = 1;
  }
  
  return \@record_ids;
}

sub delete_records_from_sets {
  my ($self, $set_key, @record_keys) = @_;
  my $db_type = get_db_type($set_key);
  my $dbh     = $self->dbh or return;
     $dbh     = $dbh->{$db_type} or return;
  my $sets    = $self->all_sets;
  
  return if $set_key && !$sets->{$set_key};

  my $set_id      = get_db_id($set_key);
  my @record_ids  = map get_db_id($_), @record_keys;

  my $where   = $set_id ? q( AND set_id = ?) : '';
  my $deleted = $dbh->do(sprintf('DELETE FROM configuration_set WHERE record_id IN (%s)%s', join(',', map '?', @record_ids), $where), {}, @record_ids, $set_id);
  
  foreach my $config_key (@record_keys) {
    my @set_keys = $self->record_to_sets($config_key);
    
    delete $sets->{$_}{'records'}{$config_key} for $set_key || @set_keys;
    
    if ($set_key && scalar @set_keys > 1) {
      delete $self->{'records_to_sets'}{$config_key}{$set_key};
    } else {
      delete $self->{'records_to_sets'}{$config_key};
    }
  }
  
  return $deleted;
}

sub delete_sets_from_record {
  my ($self, $config_key, @set_keys) = @_;
  my $db_type = get_db_type($config_key);
  my $dbh     = $self->dbh or return;
     $dbh     = $dbh->{$db_type} or return;
  
  return unless $self->all_configs->{$config_key};

  my $record_id = get_db_id($config_key);
  my @set_ids   = map get_db_id($_), @set_keys;

  my $sets    = $self->all_sets;
  my $deleted = $dbh->do(sprintf('DELETE FROM configuration_set WHERE record_id = ? AND set_id IN (%s)', join(',', map '?', @set_ids)), {}, $record_id, @set_ids);
  
  foreach (@set_keys) {
    delete $sets->{$_}{'records'}{$config_key};
    delete $self->{'records_to_sets'}{$config_key}{$_};
    delete $self->{'records_to_sets'}{$config_key} unless scalar keys %{$self->{'records_to_sets'}{$config_key}};
  }
  
  return $deleted;
}

# update records for a set
sub edit_set_records {
  my ($self, $set_key, @record_keys) = @_;
  my $set = $self->all_sets->{$set_key};
  
  return unless $set;
 
  my $record_type    = $set->{'record_type'};
  my $record_type_id = $set->{'record_type_id'};
  my $configs        = $self->all_configs;
  my %record_keys    = map { $_ => 1 } @record_keys;
  my @new            = grep $record_type eq $configs->{$_}{'record_type'} && $record_type_id eq $configs->{$_}{'record_type_id'} && !$set->{'records'}{$_}, @record_keys;
  my @delete         = grep $record_type eq $configs->{$_}{'record_type'} && $record_type_id eq $configs->{$_}{'record_type_id'} && !$record_keys{$_}, keys %{$set->{'records'}};
  my $updated;
  
  $updated->{'removed'} = \@delete if scalar @delete && $self->delete_records_from_sets($set_key, @delete);
  $updated->{'added'}   = $self->add_records_to_set($set_key, @new);
  
  return $updated;
}

# update sets for a record
sub edit_record_sets {
  my ($self, $config_key, @set_keys) = @_;
  my $record = $self->all_configs->{$config_key};
  
  return unless $record;
  
  my $record_type    = $record->{'record_type'};
  my $record_type_id = $record->{'record_type_id'};
  my $sets           = $self->all_sets;
  my %existing       = map { $_ => 1 } $self->record_to_sets($config_key);
  my %set_keys       = map { $_ => 1 } @set_keys;
  my @new            = grep $record_type eq $sets->{$_}{'record_type'} && $record_type_id eq $sets->{$_}{'record_type_id'} && !$existing{$_}, @set_keys;
  my @delete         = grep $record_type eq $sets->{$_}{'record_type'} && $record_type_id eq $sets->{$_}{'record_type_id'} && !$set_keys{$_}, keys %existing;
  my $updated;
  
  $updated->{'removed'} = \@delete if scalar @delete && $self->delete_sets_from_record($config_key, @delete);
  $updated->{'added'}   = $self->update_set_record($config_key, \@new);
  
  return $updated;
}

sub save_to_user {
  my ($self, $record_key, $is_set) = @_;
  my $user_id = $self->user_id || return;
  my $dbh     = $self->dbh     || return;
  my $configs = $self->all_configs;
  my $records = $is_set ? $self->all_sets : $configs;
  my $record  = $records->{$record_key} || return;

  return unless $dbh->{'user'};
  return unless get_db_type($record_key) eq 'session';
  
  my $updated;
  my @details_to_move;

  foreach (grep $_, $record, $record->{'link_id'} && $configs->{get_config_key('session', $record->{'link_id'})}) {

    push @details_to_move, $_;

    # if it's a set, move all the records and the set itself
    if ($is_set) {
      push @details_to_move, map {( $configs->{$_}, $configs->{$_}{'link_id'} && $configs->{get_config_key($configs->{$_}{'record_type'}, $configs->{$_}{'link_id'})} )} keys %{$_->{'records'}};
    }
  }

  my %id_map;
  my @new_records;
  my @new_sets;

  # copy configuration_details and configuration_records to user db
  foreach my $old (@details_to_move) {

    my $new = { map { $_ => $old->{$_} } keys %$old };
    $new->{'record_type'}     = 'user';
    $new->{'record_type_id'}  = $user_id;
    $new->{'old_id'}          = $old->{'record_id'};

    my @columns = qw(record_type record_type_id is_set name description servername site_type release_number);

    $dbh->{'user'}->do('INSERT INTO configuration_details ('.join(', ', @columns).') VALUES ('.join(', ', map('?', @columns)).')', {}, map(encode_entities($new->{$_}) || '', @columns));

    $new->{'record_id'} = $dbh->{'user'}->last_insert_id(undef, undef, 'configuration_details', 'record_id');

    if ($new->{'is_set'} eq 'y') {
      push @new_sets, $new;
    } else {
      push @new_records, $new;

      @columns = qw(record_id type code active link_id link_code data created_at modified_at);

      $dbh->{'user'}->do('INSERT INTO configuration_record ('.join(', ', @columns).') VALUES (?, ?, ?, ?, NULL, ?, ?, now(), now())', {},
        $new->{'record_id'},
        $new->{'type'},
        $new->{'code'},
        $new->{'active'} || '',
        $new->{'link_code'},
        $new->{'raw_data'}
      );
    }

    $id_map{$old->{'record_id'}} = $new->{'record_id'};
  }

  # update link ids
  foreach my $new_record (grep $_->{'link_id'}, @new_records) {
    $new_record->{'link_id'} = $id_map{$new_record->{'link_id'}};

    $dbh->{'user'}->do('UPDATE configuration_record SET link_id = ? WHERE record_id = ?', {}, $new_record->{'link_id'}, $new_record->{'record_id'});
  }

  # add record ids for moved set
  foreach my $new_set (@new_sets) {
    my @record_ids = grep $_, map $id_map{$_}, map get_db_id($_), keys %{$new_set->{'records'}};
    $dbh->{'user'}->do(sprintf('INSERT INTO configuration_set VALUES %s', join ', ', map '(?, ?)', @record_ids), {}, map { $new_set->{'record_id'}, $_ } @record_ids);
  }

  # delete the moved rows from session db
  for (map $_->{'old_id'}, @new_records) {
    $dbh->{'session'}->do('DELETE FROM configuration_details WHERE record_id = ?', {}, $_);
    $dbh->{'session'}->do('DELETE FROM configuration_record  WHERE record_id = ?', {}, $_);
    $dbh->{'session'}->do('DELETE FROM configuration_set     WHERE record_id = ?', {}, $_);
  }
  for (map $_->{'old_id'}, @new_sets) {
    $dbh->{'session'}->do('DELETE FROM configuration_details WHERE record_id = ?', {}, $_);
    $dbh->{'session'}->do('DELETE FROM configuration_set     WHERE set_id    = ?', {}, $_);
  }

  # remove the cached configs and sets
  delete $self->{'all_configs'};
  delete $self->{'all_sets'};

  return @new_records + @new_sets; # just return the total count
}

# Share a configuration or set with another user
sub share {
  my ($self, $record_keys, $checksum, $group_id, $link_key) = @_;
  my $dbh          = $self->dbh || return [];
  my $group        = $group_id ? $self->admin_groups->{$group_id} : undef;
  my %record_types = ( session => $self->session_id, user => $self->user_id, group => $group_id );
  my $record_type  = $group ? 'group' : 'session';
  my @record_ids   = map [ get_db_type($_), get_db_id($_) ], @$record_keys;
  my @new_record_keys;

  foreach (@record_ids) {
    my ($db_type, $db_id) = @$_;
    return [] unless $dbh->{$db_type};
    my $record = $dbh->{$db_type}->selectall_hashref('SELECT * FROM configuration_details cd, configuration_record cr WHERE cd.record_id = cr.record_id AND cr.record_id = ?', 'record_id', {}, $db_id)->{$db_id};

    next unless $record;
    next if $group_id && !$group;
    next if !$group && $record_types{$record->{'record_type'}} eq $record->{'record_type_id'}; # Don't share with yourself
    next if $checksum && $self->generate_checksum($record) ne $checksum;

    my ($exists) = grep {
      !$_->{'active'}                                 &&
      $_->{'type'}        eq $record->{'type'}        &&
      $_->{'record_type'} eq $record->{'record_type'} &&
      $_->{'code'}        eq $record->{'code'}        &&
      $_->{'raw_data'}    eq $record->{'data'}        &&
      ($group ? $_->{'record_type_id'} eq $group_id : 1)
    } values %{$self->all_configs};
    
    # Don't duplicate records with the same data
    my $new_record_key = $exists ? get_config_key($_->{'record_type'}, $exists->{'record_id'}) : $self->new_config(
      %$record,
      record_type    => $record_type,
      record_type_id => $record_types{$record_type}, 
      active         => '',
      map({ $_ => decode_entities($record->{$_}) || '' } qw(name description))
    );
    
    if ($record->{'link_id'}) {
      if ($link_key) {
        $self->link_configs_by_keys($new_record_key, $link_key);
      } else {
        $self->share([ get_config_key($record->{'record_type'}, $record->{'link_id'}) ], undef, $group_id, $new_record_key);
      }
    }
    
    $self->update_active($new_record_key) unless $group;
    
    push @new_record_keys, $new_record_key;
  }
  
  return \@new_record_keys;
}

sub share_record {
  my ($self, $record_key, $checksum, $group_id) = @_;
  return $checksum ? $self->share([ $record_key ], $checksum, $group_id) : undef;
}

sub share_set {
  my ($self, $set_key, $checksum, $group_id) = @_;
  my $db_type      = get_db_type($set_key);
  my $set_id       = get_db_id($set_key);
  my $dbh          = $self->dbh or return;
     $dbh          = $dbh->{$db_type} or return;
  my $group        = $group_id ? $self->admin_groups->{$group_id} : undef;
  my %record_types = ( session => $self->session_id, user => $self->user_id, group => $group_id );
  my $record_type  = $group ? 'group' : 'session';
  
  my $session_id = $self->session_id;
  
  my $set = $dbh->selectall_hashref('SELECT * FROM configuration_details WHERE is_set = "y" AND record_id = ?', 'record_id', {}, $set_id)->{$set_id};
  
  return unless $set;
  return if $group_id && !$group;
  return if !$group && $record_types{$set->{'record_type'}} eq $set->{'record_type_id'}; # Don't share with yourself
  return unless md5_hex($self->serialize_data($set)) eq $checksum;
  
  my $record_keys = $self->share([ map get_config_key($db_type, $_->[0]), @{$dbh->selectall_arrayref('SELECT record_id FROM configuration_set WHERE set_id = ?', {}, $set_id)} ], undef, $group ? $group_id : undef);
  my $serialized  = $self->serialize_data([ sort @$record_keys ]);
  
  # Don't make a new set if one exists with the same records as the share
  foreach (values %{$self->all_sets}) {
    return get_config_key($db_type, $_->{'record_id'}) if $_->{'record_type'} eq $db_type && $self->serialize_data([ sort keys %{$_->{'records'}} ]) eq $serialized;
  }
  
  return $self->create_set(
    %$set,
    record_type    => $record_type,
    record_type_id => $record_types{$record_type},
    record_ids     => [ map get_db_id($_), @$record_keys ]
  );
}

sub generate_checksum {
  my ($self, $record) = @_;
  return md5_hex($self->serialize_data({ map {$_ => $record->{$_} || ''} qw(record_id record_type record_type_id servername site_type release_number) }));
}

sub set_cache_tags {
  my ($self, $config) = @_;
  $ENV{'CACHE_TAGS'}{$config->{'type'}} = sprintf '%s[%s]', uc($config->{'type'}), md5_hex(join '::', $config->{'code'}, $self->serialize_data($config->{'data'})) if $config;
}

# not currently used, but written in case we need it in future
sub disconnect {
  $DBH_SESSION->disconnect if $DBH_SESSION;
  $DBH_USER->disconnect if $DBH_USER;
  undef $DBH_SESSION;
  undef $DBH_USER;
}

sub get_config_key {
  my ($record_type, $record_id) = @_;
  $record_type  //= 'session';
  $record_id    //= '0';
  return join '', $record_type eq 'session' ? 's' : 'u', $record_id;
}

sub get_db_type {
  my $config_key  = shift;
  return $config_key && $config_key =~ /^(s|u)[0-9]+$/ && ($1 eq 'u' ? 'user' : 'session');
}

sub get_db_id {
  my $config_key = shift;
  return $config_key && $config_key =~ /^(s|u)([0-9]+)$/ && $2;
}

1;
