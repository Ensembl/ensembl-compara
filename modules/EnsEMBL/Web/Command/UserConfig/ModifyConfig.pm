# $Id$

package EnsEMBL::Web::Command::UserConfig::ModifyConfig;

use strict;

use Encode qw(decode_utf8);

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
