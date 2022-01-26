=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

use Encode      qw(decode_utf8);
use URI::Escape qw(uri_escape);

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $func = sprintf 'mc_%s', $self->hub->function;

  $self->$func() if $self->can($func);
}

sub edit_fields {
  return {
    name        => 1,
    description => 1,
  };
}

sub mc_edit_details {
  my $self  = shift;
  my $hub   = $self->hub;
  my $param = $hub->param('param');
  
  return unless $self->edit_fields->{$param};
  
  print 'success' if $hub->config_adaptor->edit_details($hub->param('config_key'), $param, decode_utf8($hub->param('value')), $hub->param('is_set'));
}

sub mc_save {
  my $self        = shift;
  my $hub         = $self->hub;
  my $then        = $hub->param('then');
  my $redirect    = $hub->param('redirect');
  my $config_key  = $hub->param('config_key');
  my $func        = $hub->param('is_set') ? 'all_sets' : 'all_configs';
  my $adaptor     = $hub->config_adaptor;
  my (%save_keys, $success);

  $self->get_linked_configs($adaptor->$func->{$config_key}, $adaptor, \%save_keys);

  if (scalar keys %save_keys > 1 && !$hub->param('save_all')) {
    my ($configs, $sets) = ($adaptor->all_configs, $adaptor->all_sets);
    my %json;
    
    push @{$json{"$save_keys{$_}s"}}, $save_keys{$_} eq 'set' ? $sets->{$_}{'name'} : $configs->{$_}{'name'} for keys %save_keys;
    
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
  
  $success += $adaptor->save_to_user($_, $save_keys{$_} eq 'set') for keys %save_keys;
  
  return unless $success;
  
  if ($redirect) {
    $self->ajax_redirect($redirect, undef, undef, 'modal', 'modal_user_data');
  } else {
    print $self->jsonify({ func => 'saveRecord', ids => [ keys %save_keys ] });
  }
}

sub get_linked_configs {
  my ($self, $record, $adaptor, $save_keys) = @_;
  
  return if $save_keys->{$record->{'config_key'}};
  
  $save_keys->{$record->{'config_key'}} = $record->{'is_set'} eq 'y' ? 'set' : 'config';
  
  my $sets = $adaptor->all_sets;
  
  if ($record->{'is_set'} eq 'y') {
    foreach (keys %{$record->{'records'}}) {
      $save_keys->{$_} = 'config';
      $self->get_linked_configs($sets->{$_}, $adaptor, $save_keys) for grep $_ != $record->{'config_key'}, $adaptor->record_to_sets($_);
    }
  } else {
    $self->get_linked_configs($sets->{$_}, $adaptor, $save_keys) for $adaptor->record_to_sets($record->{'config_key'});
  }
}

sub mc_delete {
  my $self = shift;
  my $hub  = $self->hub;
  my $func = $hub->param('is_set') ? 'delete_set' : 'delete_config';
  
  print $self->jsonify({ func => 'deleteRecord' }) if $hub->config_adaptor->$func($hub->param('config_key'), $hub->param('link_key'));
}

sub mc_activate {
  my $self = shift;
  my $hub  = $self->hub;
  my $func = $hub->param('is_set') ? 'activate_set' : 'update_active';
  
  print $self->jsonify({ func => 'activateRecord' }) if $hub->config_adaptor->$func($hub->param('config_key'));
}

sub mc_edit_sets {
  my $self       = shift;
  my $hub        = $self->hub;
  my $config_key = $hub->param('config_key');
  my @update_ids = $hub->param('update_id');
  my $func       = $hub->param('is_set') ? 'edit_set_records' : 'edit_record_sets';
  my $update     = $hub->config_adaptor->$func($config_key, @update_ids);
  
  print $self->jsonify({ func => 'updateTable', id => $config_key, editables => $update }) if $update;
}

sub mc_add_set {
  my $self        = shift;
  my $hub         = $self->hub;
  my @config_keys = $hub->param('config_key');
  my $user        = $hub->user;
  my %params      = map { $_ => decode_utf8($hub->param($_)) } qw(record_type name description);
  
  if ($params{'record_type'} eq 'group' && $user) {
    my $group = decode_utf8($hub->param('group'));
    $params{'record_type_id'} = $group if $user->is_admin_of($group);
  }
  
  my $set_id = $hub->config_adaptor->create_set(
    record_type_id => $params{'record_type'} eq 'session' ? $hub->session->session_id : $user ? $user->id : undef,
    config_keys    => \@config_keys,
    %params
  );
  
  print $self->jsonify({ func => 'addTableRow', configKeys => [ $set_id ] }) if $set_id;
}

sub mc_share {
  my $self    = shift;
  my $hub     = $self->hub;
  my $referer = $hub->referer;
  
  return if $referer->{'external'}; 
  
  my $is_set  = $hub->param('is_set');
  my $id      = $hub->param('config_key');
  my $func    = $is_set ? 'all_sets' : 'all_configs';
  my $adaptor = $hub->config_adaptor;
  my $record  = $self->deepcopy($adaptor->$func->{$id});
  
  return unless $record;
  
  my @groups = $hub->param('group');

  my $checksum = $adaptor->generate_checksum($record);

  if (scalar @groups) {
    my $user = $hub->user;
    
    return unless $user;
    
    my %admin_groups = map { $_->group_id => 1 } $user->find_admin_groups;
       $func         = $is_set ? 'share_set' : 'share_record';
    my @config_keys;
    
    foreach (@groups) {
      next unless $admin_groups{$_};
      
      my $config_key = $adaptor->$func($id, $checksum, $_);
      
      push @config_keys, ref $config_key eq 'ARRAY' ? @$config_key : $config_key || ();
    }
    
    print $self->jsonify({ func => 'addTableRow', configKeys => \@config_keys }) if scalar @config_keys;
  } else {
    printf '%s%sshare_ref=conf%s-%s-%s', $referer->{'absolute_url'}, $referer->{'absolute_url'} =~ /\?/ ? ';' : '?', $is_set ? 'set' : '', $id, $checksum;
  }
}

sub mc_reset_all {
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
