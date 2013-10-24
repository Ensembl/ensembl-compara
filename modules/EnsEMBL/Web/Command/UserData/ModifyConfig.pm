# $Id$

package EnsEMBL::Web::Command::UserData::ModifyConfig;

use strict;

use Digest::MD5 qw(md5_hex);
use Encode      qw(decode_utf8);

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
  my $self = shift;
  my $hub  = $self->hub;
  
  print 'saveRecord' if $hub->config_adaptor->save_to_user($hub->param('record_id')); # FIXME: when saving a set, save all the configs in the set too
}

sub delete {
  my $self = shift;
  my $hub  = $self->hub;
  my $func = $hub->param('is_set') ? 'delete_set' : 'delete_config';
  
  print 'deleteRecord' if $hub->config_adaptor->$func($hub->param('record_id'), $hub->param('link_id'));
}

sub activate {
  my $self = shift;
  my $hub  = $self->hub;
  my $func = $hub->param('is_set') ? 'activate_set' : 'update_active';
  
  print 'activateRecord' if $hub->config_adaptor->$func($hub->param('record_id'));
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
  my %params     = map { $_ => decode_utf8($hub->param($_)) } qw(record_type name description);
  my $set_id     = $hub->config_adaptor->create_set(
    %params,
    record_type_id => $params{'record_type'} eq 'session' ? $hub->session->create_session_id : $hub->user ? $hub->user->id : undef,
    record_ids     => \@record_ids
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

1;
