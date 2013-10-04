# $Id$

package EnsEMBL::Web::Command::UserConfig::ModifyConfig;

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

sub delete {
  my $self = shift;
  my $hub  = $self->hub;
  
  print 'deleteRecord' if $hub->config_adaptor->delete_config($hub->param('record_id'), $hub->param('link_id'));
}

sub activate {
  my $self = shift;
  my $hub  = $self->hub;
  
  print 'activateRecord' if $hub->config_adaptor->update_active($hub->param('record_id'));
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
    
    foreach (@groups) {
      next unless $admin_groups{$_};
      
      $adaptor->$func($id, $checksum, $_);
      
      # TODO: some feedback
    }
  } else {
    printf '%s%sshare_ref=conf%s-%s-%s', $referer->{'absolute_url'}, $referer->{'absolute_url'} =~ /\?/ ? ';' : '?', $is_set ? 'set' : '', $id, $checksum;
  }
}

sub edit_sets {
  my $self      = shift;
  my $hub       = $self->hub;
  my $record_id = $hub->param('record_id');
  my @set_ids   = $hub->param('set_id');
  
  $hub->config_adaptor->edit_record_sets($record_id, @set_ids);
  
  $self->ajax_redirect($hub->url({ action => 'ManageConfigs', function => undef, __clear => 1 }));
}

sub add_set {
  my $self       = shift;
  my $hub        = $self->hub;
  my $set_id     = $hub->param('set_id');
  my @record_ids = $hub->param('record_id');
  
  if ($set_id) {
    $hub->config_adaptor->edit_set_records($set_id, @record_ids);
  } else {
    my %params = map { $_ => decode_utf8($hub->param($_)) } qw(record_type name description);
    
    $hub->config_adaptor->create_set(
      %params,
      record_type_id => $params{'record_type'} eq 'session' ? $hub->session->create_session_id : $hub->user ? $hub->user->id : undef,
      record_ids     => \@record_ids
    );
  }
  
  $self->ajax_redirect($hub->url({ action => 'ManageSets', function => undef, __clear => 1 }));
}

sub delete_set {
  my $self = shift;
  my $hub  = $self->hub;
  
  print 'deleteRecord' if $hub->config_adaptor->delete_set($hub->param('record_id'));
}

sub activate_set {
  my $self = shift;
  my $hub  = $self->hub;
  
  print 'activateRecord' if $hub->config_adaptor->activate_set($hub->param('record_id'));
}

1;
