# $Id$

package EnsEMBL::Web::DBSQL::ConfigAdaptor;

use strict;

use Data::Dumper;
use DBI;
use Digest::MD5 qw(md5_hex);
use HTML::Entities qw(encode_entities);

my $DBH; # package database handle for persistence

sub new {
  my ($class, $hub) = @_;
  my $species_defs  = $hub->species_defs;
  my $self          = {
    hub        => $hub,
    session_id => $hub->session->session_id,
    user_id    => $hub->user ? $hub->user->id : undef,
    servername => $species_defs->ENSEMBL_SERVERNAME,
    version    => $species_defs->ENSEMBL_VERSION,
    cache_tags => [],
  };
  
  dbh($species_defs);
  
  bless $self, $class;
  
  return $self;
}

sub hub        { return $_[0]{'hub'};        }
sub session_id { return $_[0]{'session_id'}; }
sub user_id    { return $_[0]{'user_id'};    }
sub servername { return $_[0]{'servername'}; }
sub version    { return $_[0]{'version'};    }
sub cache_tags { return $_[0]{'cache_tags'}; }

sub dbh {
  my $species_defs = shift;
  
  return $DBH ||= DBI->connect(sprintf(
    'DBI:mysql:database=%s;host=%s;port=%s',
    $species_defs->ENSEMBL_USERDB_NAME,
    $species_defs->ENSEMBL_USERDB_HOST,
    $species_defs->ENSEMBL_USERDB_PORT
  ), $species_defs->ENSEMBL_USERDB_USER, $species_defs->ENSEMBL_USERDB_PASS);
}

sub record_type_query {
  my $self = shift;
  my @args  = grep $_, $self->session_id, $self->user_id;
  my $where = 'cd.record_type = "session" AND cd.record_type_id = ?';
     $where = qq{(($where) OR (cd.record_type = "user" AND cd.record_type_id = ?))} if scalar @args == 2;
  
  return ($where, @args);
}

sub all_configs {
  my $self = shift;
  
  if (!$self->{'all_configs'}) {
    $self->{'all_configs'} = $self->filtered_configs;
    
    # Prioritize user records over session records when setting active config
    # If both a user and session record are active and the user logs in, the user record will be the one used, and the session record will be ignored
    foreach (sort {($b->{'record_type'} eq 'user') <=> ($a->{'record_type'} eq 'user')} values %{$self->{'all_configs'}}) {
      $_->{'raw_data'} = $_->{'data'};
      $_->{'data'}     = eval($_->{'data'}) || {};
      $self->{'active_config'}{$_->{'type'}}{$_->{'code'}} ||= $_->{'record_id'} if $_->{'active'} eq 'y';
    }
  }
  
  return $self->{'all_configs'};
}

sub filtered_configs {
  my ($self, $filter) = @_;
  my ($where, @args)  = $self->record_type_query;
  
  foreach (sort keys %{$filter || {}}) {
    if (ref $filter->{$_} eq 'ARRAY') {
      $where .= sprintf " AND $_ IN (%s)", join ',', map '?', @{$filter->{$_}};
      push @args, @{$filter->{$_}};
    } else {
      $where .= " AND $_ = ?";
      push @args, $filter->{$_};
    }
  }
  
  return $self->dbh->selectall_hashref("SELECT * FROM configuration_details cd, configuration_record cr WHERE cd.record_id = cr.record_id AND $where", 'record_id', {}, @args);
}

sub active_config {
  my ($self, $type, $code) = @_;
  $self->all_configs unless $self->{'all_configs'};
  return $self->{'active_config'}{$type}{$code};
}

sub get_config {
  my $self   = shift;
  my $config = $self->all_configs->{$self->active_config(@_)};
  
  $self->set_cache_tags($config);
  
  return $config->{'data'};
}

sub serialize_data {
  my ($self, $data) = @_;
  
  local $Data::Dumper::Indent   = 0;
  local $Data::Dumper::SortKeys = 1;
  (my $data_string = Dumper $data) =~ s/^\$VAR1 = //;
  
  return $data_string;
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
    ($deleted) = $self->delete_config($record_id);
  }
  
  return ($saved, $deleted);
}

sub new_config {
  my ($self, %args) = @_;
  my $dbh = $self->dbh;
  
  $dbh->do('INSERT INTO configuration_details VALUES ("", ?, ?, "n", ?, ?, ?, ?)', {}, map(encode_entities($args{$_}) || '', qw(record_type record_type_id name description)), $self->servername, $self->version);
  
  my $record_id = $dbh->last_insert_id(undef, undef, 'configuration_details', 'record_id');
  my $data      = ref $args{'data'} ? $self->serialize_data($args{'data'}) : $args{'data'};
  my $set_ids   = delete $args{'set_ids'};
  
  $dbh->do('INSERT INTO configuration_record VALUES (?, ?, ?, ?, NULL, ?, ?, now(), now())', {}, $record_id, $args{'type'}, $args{'code'}, $args{'active'} || '', $args{'link_code'}, $data || '');
  
  $self->update_set_record($record_id, $set_ids) if $set_ids && scalar @$set_ids;
  
  $self->all_configs->{$record_id} = {
    record_id => $record_id,
    %args
  };
  
  $self->all_configs->{$record_id}{'data'}     = eval($args{'data'}) || {} unless ref $args{'data'};
  $self->all_configs->{$record_id}{'raw_data'} = $data;
  
  $self->{'active_config'}{$args{'type'}}{$args{'code'}} = $record_id if $args{'active'};
  
  return $record_id;
}

sub link_configs {
  my ($self, @links) = @_;
  
  if (scalar @links == 1) {
    my $active = $self->active_config(@{$links[0]{'link'}});
    push @links, { id => $active, code => $links[0]{'link'}[1] };
  }
  
  return unless scalar @links == 2;
  
  my $configs = $self->all_configs;
  
  $_->{'id'} = undef for grep !$configs->{$_->{'id'}}, @links;
  
  return unless grep $_->{'id'}, @links;
  
  my $query = 'UPDATE configuration_record SET link_id = ?, link_code = ? WHERE record_id = ?';
  my $sth   = $self->dbh->prepare($query);
  
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
  
  my $query = 'UPDATE configuration_record SET link_id = ? WHERE record_id = ?';
  my $sth   = $self->dbh->prepare($query);
  $sth->execute(@ids);
  $sth->execute(reverse @ids);
}

sub set_data {
  my ($self, $record_id, $data) = @_;
  my $config     = $self->all_configs->{$record_id};
  my $serialized = ref $data ? $self->serialize_data($data) : $data;
  
  if ($serialized ne $config->{'raw_data'}) {
    $self->dbh->do('UPDATE configuration_record SET modified_at = now(), data = ? WHERE record_id = ?', {}, $serialized, $record_id);
    
    $config->{'data'}     = ref $data ? $data : eval($data) || {};
    $config->{'raw_data'} = $serialized;
  }
  
  $self->set_cache_tags($self->all_configs->{$record_id});
  
  return $record_id;
}

sub delete_config {
  my ($self, @record_ids) = @_;
  my $configs = $self->all_configs;
  my $dbh     = $self->dbh;
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
      # clone the selected config's record
      push @new_ids, $self->new_config(%$config, data => $config->{'data'}, active => 'y', name => '', description => '');
      $self->delete_config($self->active_config($config->{'type'} eq 'view_config' ? 'image_config' : 'view_config', $config->{'link_code'})) if $config->{'link_code'} && !$config->{'link_id'};
    }
    
    $self->set_cache_tags($config);
  }
  
  $self->link_configs_by_id(@new_ids);
  
  return scalar @new_ids;
}

sub edit_details {
  my ($self, $record_id, $type, $value, $is_set) = @_;
  my $details = $is_set ? $self->all_sets : $self->all_configs;
  my $config  = $details->{$record_id};
  my $dbh     = $self->dbh;
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
  
  if (!$self->{'all_sets'}) {
    my $dbh = $self->dbh;
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
  my $configs    = $self->all_configs;
  my @record_ids = grep $configs->{$_}, @{$args{'record_ids'}};
  
  return unless @record_ids;
  
  my $dbh = $self->dbh;
  
  $dbh->do('INSERT INTO configuration_details VALUES ("", ?, ?, "y", ?, ?, ?, ?)', {}, map(encode_entities($args{$_}) || '', qw(record_type record_type_id name description)), $self->servername, $self->version);
  
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
  my $sets    = $self->all_sets;
  my @set_ids = grep $sets->{$_}, @$ids;  
  
  return unless scalar @set_ids;
   
  $self->dbh->do(sprintf('INSERT INTO configuration_set VALUES %s', join ', ', map '(?, ?)', @set_ids), {}, map { $_, $record_id } @set_ids);
  
  foreach (@set_ids) {
    $sets->{$_}{'records'}{$record_id}         = 1;
    $self->{'records_to_sets'}{$record_id}{$_} = 1;
  }
}

sub delete_set {
  my ($self, $set_id) = @_;
  my $sets = $self->all_sets;
  
  return unless $sets->{$set_id};
  
  my $dbh = $self->dbh;
  
  $dbh->do('DELETE FROM configuration_set     WHERE set_id    = ?', {}, $set_id);
  $dbh->do('DELETE FROM configuration_details WHERE record_id = ?', {}, $set_id);
  
  delete $sets->{$set_id};
  delete $_->{$set_id} for values %{$self->{'records_to_sets'}};
  
  return $set_id;
}

sub add_records_to_set {
  my ($self, $set_id, @record_ids) = @_;
  
  $self->dbh->do(sprintf('INSERT INTO configuration_set VALUES %s', join ', ', map '(?, ?)', @record_ids), {}, map { $set_id, $_ } @record_ids);
  
  foreach (@record_ids) {
    $self->{'all_sets'}{$set_id}{'records'}{$_} = 1;
    $self->{'records_to_sets'}{$_}{$set_id}     = 1;
  }
}

sub delete_records_from_sets {
  my ($self, $set_id, @record_ids) = @_;
  my $sets  = $self->all_sets;
  
  return if $set_id && !$sets->{$set_id};
  
  my $where   = $set_id ? ' AND set_id = ?' : '';
  my $deleted = $self->dbh->do(sprintf('DELETE FROM configuration_set WHERE record_id IN (%s)%s', join(',', map '?', @record_ids), $where), {}, @record_ids, $set_id);
  
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
  
  return unless $self->all_configs->{$record_id};
  
  my $sets    = $self->all_sets;
  my $deleted = $self->dbh->do(sprintf('DELETE FROM configuration_set WHERE record_id = ? AND set_id IN (%s)', join(',', map '?', @set_ids)), {}, $record_id, @set_ids);
  
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
  
  my %record_ids = map { $_ => 1 } @record_ids;
  my @new        = grep !$set->{'records'}{$_}, @record_ids;
  my @delete     = grep !$record_ids{$_}, keys %{$set->{'records'}};
  my $updated    = $self->delete_records_from_sets($set_id, @delete) if scalar @delete;
     $updated   += $self->add_records_to_set($set_id, @new)          if scalar @new;
  
  return $updated;
}

# update sets for a record
sub edit_record_sets {
  my ($self, $record_id, @set_ids) = @_;
  
  return unless $self->all_configs->{$record_id};
  
  my %existing = map { $_ => 1 } $self->record_to_sets($record_id);
  my %set_ids  = map { $_ => 1 } @set_ids;
  my @new      = grep !$existing{$_}, @set_ids;
  my @delete   = grep !$set_ids{$_}, keys %existing;
  my $updated  = $self->delete_sets_from_record($record_id, @delete) if scalar @delete;
     $updated += $self->update_set_record($record_id, \@new)         if scalar @new;
  
  return $updated;
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
