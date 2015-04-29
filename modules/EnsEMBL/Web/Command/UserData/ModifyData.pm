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

package EnsEMBL::Web::Command::UserData::ModifyData;

use strict;

use Digest::MD5 qw(md5_hex);

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $hub  = $self->hub;
  my $func = $hub->function;
  my $rtn  = $self->$func();
  
  if (ref $rtn eq 'HASH') {
    $self->ajax_redirect($hub->url({
      action   => 'ManageData',
      function => undef,
      __clear  => 1,
      %$rtn,
    }));
  } else {
    print $rtn;
  }
}

sub save_upload {
  my $self       = shift;
  my $url_params = { reload => 1 };

  if (!$self->object->store_data(type => 'upload', code => $self->hub->param('code'))) {
    $url_params->{'filter_module'} = 'UserData';
    $url_params->{'filter_code'}   = 'no_file';
  }
  
  return $url_params;
}

sub save_remote { # TODO: move logic to object
  my $self = shift;
  my $hub  = $self->hub;
  my $user = $hub->user;
  
  return unless $user;
  
  my $session     = $hub->session;
  my @das_sources = grep $_, $hub->param('dsn');
  my @codes       = grep $_, $hub->param('code');
  my $error       = 0;
  my $url_params  = {};

  if (scalar @das_sources) { ## Save any DAS data
    my $all_das = $session->get_all_das;
    
    foreach my $logic_name (@das_sources) {
      $error = 1 unless $user->add_das($all_das->{$logic_name});
    }
    
    $session->save_das; # Just need to save the session to remove the source - it knows it has changed
  } elsif (scalar @codes) { ## Save any URL data
    foreach my $code (@codes) {
      my $url = $session->get_data(type => 'url', code => $code);
      
      if ($user->add_to_urls($url)) {
        $session->purge_data(type => 'url', code => $code);
      } else {
        warn "failed to save url ($url->{'format'}) data: $code";
        $error = 1;
      }     
    }
  }
  
  if ($error) {
    $url_params->{'action'}        = 'ShowRemote';
    $url_params->{'filter_module'} = 'UserData';
    $url_params->{'filter_code'}   = scalar @das_sources ? 'no_das' : 'no_url';
  }
  
  return $url_params; 
}

sub delete_upload {
  my $self = shift;
  
  $self->object->delete_upload;
  
  return { action => $self->hub->param('goto') || 'ManageData', reload => 1 };
}

sub delete_remote {
  my $self = shift;
  
  $self->object->delete_remote;
  
  return { reload => 1 };
}

sub rename_session_record {
  my $self = shift;
  my $hub  = $self->hub;
  my $name = $hub->param('value');
  
  $hub->session->set_data(type => $hub->param('source'), code => $hub->param('code'), name => $name) if $name;
  
  return 'reload';
}

sub rename_user_record {
  my $self  = shift;
  my $hub   = $self->hub;
  my $user  = $hub->user;
  my $name  = $hub->param('value');

  if ($name) {
    my ($id, $checksum) = split '-', $hub->param('id');
    my $record = $user->get_record($id);
    
    if ($checksum eq md5_hex($record->code)) {
      $record->name($name);
      $record->save(user => $user->rose_object);
    }
  }

  return 'reload';
}

1;
