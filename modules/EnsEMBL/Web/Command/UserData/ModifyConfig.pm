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

package EnsEMBL::Web::Command::UserData::ModifyConfig;

use strict;

use Digest::MD5 qw(md5_hex);
use Encode      qw(decode_utf8);
use URI::Escape qw(uri_escape);

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $func = $self->hub->function;
  
  $self->$func();
}

sub edit_fields {
  return {
    name        => 1,
    description => 1,
  };
}

sub edit_details {
  my $self  = shift;
  my $hub   = $self->hub;
  my $param = $hub->param('param');
  
  return unless $self->edit_fields->{$param};
  
  print 'success' if $hub->config_adaptor->edit_details($hub->param('record_id'), $param, decode_utf8($hub->param('value')), $hub->param('is_set'));
}

sub save {
  my $self      = shift;
  my $hub       = $self->hub;
  my $then      = $hub->param('then');
  my $redirect  = $hub->param('redirect');
  my $record_id = $hub->param('record_id');
  my $func      = $hub->param('is_set') ? 'all_sets' : 'all_configs';
  my $adaptor   = $hub->config_adaptor;
  my (%save_ids, $success);
  
  $self->get_linked_configs($adaptor->$func->{$record_id}, $adaptor, \%save_ids);
  
  if (scalar keys %save_ids > 1 && !$hub->param('save_all')) {
    my ($configs, $sets) = ($adaptor->all_configs, $adaptor->all_sets);
    my %json;
    
    push @{$json{"$save_ids{$_}s"}}, $save_ids{$_} eq 'set' ? $sets->{$_}{'name'} : $configs->{$_}{'name'} for keys %save_ids;
    
    print $self->jsonify({ func => 'saveAll', %json });
    
    return;
  }
  
  if ($then) {
    return $self->ajax_redirect($hub->url({
      type      => 'Account',
      action    => 'Login',
      then      => uri_escape($hub->url({ redirect => $then, then => undef }, undef, 1)),
      modal_tab => 'modal_user_data',
      __clear   => 1,
    }), undef, undef, 'modal', 'modal_user_data');
  }
  
  $success += $adaptor->save_to_user($_, $save_ids{$_} eq 'set') for keys %save_ids;
  
  return unless $success;
  
  if ($redirect) {
    $self->ajax_redirect($redirect, undef, undef, 'modal', 'modal_user_data');
  } else {
    print $self->jsonify({ func => 'saveRecord', ids => [ keys %save_ids ] });
  }
}

sub get_linked_configs {
  my ($self, $record, $adaptor, $save_ids) = @_;
  
  return if $save_ids->{$record->{'record_id'}};
  
  $save_ids->{$record->{'record_id'}} = $record->{'is_set'} eq 'y' ? 'set' : 'config';
  
  my $sets = $adaptor->all_sets;
  
  if ($record->{'is_set'} eq 'y') {
    foreach (keys %{$record->{'records'}}) {
      $save_ids->{$_} = 'config';
      $self->get_linked_configs($sets->{$_}, $adaptor, $save_ids) for grep $_ != $record->{'record_id'}, $adaptor->record_to_sets($_);
    }
  } else {
    $self->get_linked_configs($sets->{$_}, $adaptor, $save_ids) for $adaptor->record_to_sets($record->{'record_id'});
  }
}

sub delete {
  my $self = shift;
  my $hub  = $self->hub;
  my $func = $hub->param('is_set') ? 'delete_set' : 'delete_config';
  
  print $self->jsonify({ func => 'deleteRecord' }) if $hub->config_adaptor->$func($hub->param('record_id'), $hub->param('link_id'));
}

sub activate {
  my $self = shift;
  my $hub  = $self->hub;
  my $func = $hub->param('is_set') ? 'activate_set' : 'update_active';
  
  print $self->jsonify({ func => 'activateRecord' }) if $hub->config_adaptor->$func($hub->param('record_id'));
}

sub edit_sets {
  my $self       = shift;
  my $hub        = $self->hub;
  my $record_id  = $hub->param('record_id');
  my @update_ids = $hub->param('update_id');
  my $func       = $hub->param('is_set') ? 'edit_set_records' : 'edit_record_sets';
  my $update     = $hub->config_adaptor->$func($record_id, @update_ids);
  
  print $self->jsonify({ func => 'updateTable', id => $record_id, editables => $update }) if $update;
}

sub add_set {
  my $self       = shift;
  my $hub        = $self->hub;
  my @record_ids = $hub->param('record_id');
  my $user       = $hub->user;
  my %params     = map { $_ => decode_utf8($hub->param($_)) } qw(record_type name description);
  
  if ($params{'record_type'} eq 'group' && $user) {
    my $group = decode_utf8($hub->param('group'));
    $params{'record_type_id'} = $group if $user->is_admin_of($group);
  }
  
  my $set_id = $hub->config_adaptor->create_set(
    record_type_id => $params{'record_type'} eq 'session' ? $hub->session->create_session_id : $user ? $user->id : undef,
    record_ids     => \@record_ids,
    %params
  );
  
  print $self->jsonify({ func => 'addTableRow', recordIds => [ $set_id ] }) if $set_id;
}

sub share {
  my $self    = shift;
  my $hub     = $self->hub;
  my $referer = $hub->referer;
  
  return if $referer->{'external'}; 
  
  my $is_set  = $hub->param('is_set');
  my $id      = $hub->param('record_id');
  my $func    = $is_set ? 'all_sets' : 'all_configs';
  my $adaptor = $hub->config_adaptor;
  my $record  = $self->deepcopy($adaptor->$func->{$id});
  
  return unless $record;
  
  my @groups = $hub->param('group');
  
  if ($is_set) {
    delete $record->{'records'};
  } else {
    $record->{'data'} = delete $record->{'raw_data'};
  }
  
  my $checksum = md5_hex($adaptor->serialize_data($record));
  
  if (scalar @groups) {
    my $user = $hub->user;
    
    return unless $user;
    
    my %admin_groups = map { $_->group_id => 1 } $user->find_admin_groups;
       $func         = $is_set ? 'share_set' : 'share_record';
    my @record_ids;
    
    foreach (@groups) {
      next unless $admin_groups{$_};
      
      my $record_id = $adaptor->$func($id, $checksum, $_);
      
      push @record_ids, ref $record_id eq 'ARRAY' ? @$record_id : $record_id || ();
    }
    
    print $self->jsonify({ func => 'addTableRow', recordIds => \@record_ids }) if scalar @record_ids;
  } else {
    printf '%s%sshare_ref=conf%s-%s-%s', $referer->{'absolute_url'}, $referer->{'absolute_url'} =~ /\?/ ? ';' : '?', $is_set ? 'set' : '', $id, $checksum;
  }
}

sub reset_all {
  my $self       = shift;
  my $hub        = $self->hub;
  my $adaptor    = $hub->config_adaptor;
  my $configs    = $adaptor->all_configs;
  my @config_ids = grep $configs->{$_}{'active'} eq 'y', keys %$configs;
  my @codes      = map { ($configs->{$_}{'type'} eq 'image_config' && $configs->{$_}{'link_code'} ? $configs->{$_}{'link_code'} : $configs->{$_}{'code'}) =~ s/::/_/rg } @config_ids;
  
  $adaptor->delete_config(@config_ids);
  
  print $self->jsonify({ func => 'updatePanels', codes => \@codes })
}

1;
