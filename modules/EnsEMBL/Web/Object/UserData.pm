=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Object::UserData;

### NAME: EnsEMBL::Web::Object::UserData
### Object for accessing data uploaded by the user

### PLUGGABLE: Yes, using Proxy::Object 

### STATUS: At Risk

### DESCRIPTION
### This module does not wrap around a data object, it merely
### accesses user data via the session                                                                                   
use strict;

use Data::Dumper;
use Digest::MD5 qw(md5_hex);

use Bio::EnsEMBL::StableIdHistoryTree;
use Bio::EnsEMBL::Utils::Exception qw(try catch);

use Bio::EnsEMBL::Variation::Utils::VEP qw(
  parse_line
  get_slice
  validate_vf
  get_all_consequences
  @OUTPUT_COLS
  @REG_FEAT_TYPES
  @VEP_WEB_CONFIG
);

use Bio::EnsEMBL::Variation::DBSQL::VariationFeatureAdaptor;
use Bio::EnsEMBL::Variation::DBSQL::StructuralVariationFeatureAdaptor;
use Bio::EnsEMBL::Variation::DBSQL::TranscriptVariationAdaptor;

use EnsEMBL::Web::Cache;
use EnsEMBL::Web::Data::Session;
use EnsEMBL::Web::Document::Table;
use EnsEMBL::Web::File::Utils::IO qw/delete_file/;
use EnsEMBL::Web::File::Utils::FileSystem qw/create_path copy_files/;
use EnsEMBL::Web::Utils::Encryption qw/encrypt_value/;

use base qw(EnsEMBL::Web::Object);

sub data      :lvalue { $_[0]->{'_data'}; }
sub data_type :lvalue {  my ($self, $p) = @_; if ($p) {$_[0]->{'_data_type'} = $p} return $_[0]->{'_data_type' }; }

sub caption  {
  my $self = shift;
  return 'Personal Data';
}

sub short_caption {
  my $self = shift;
  return 'Personal Data';
}

sub counts {
  my $self   = shift;
  my $user   = $self->user;
  my $counts = {};
  return $counts;
}

sub availability {
  my $self = shift;
  my $hash = $self->_availability;
  $hash->{'has_id_mapping'} = $self->table_info( $self->get_db, 'stable_id_event' )->{'rows'} ? 1 : 0;
  return $hash;
}

############### CUSTOM DATA MANAGEMENT #########################

sub rename_session_record {
  my $self = shift;
  my $hub  = $self->hub;
  my $name = $hub->param('value');

  $hub->session->set_data(type => $hub->param('source'), code => $hub->param('code'), name => $name) if $name;
  return 1;
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

  return 1;
}

sub save_upload {
## Move an uploaded file to a persistent directory
  my $self = shift;
  my $hub  = $self->hub;
  my $user = $hub->user;

  if ($user) {
    my ($old_path, $new_path) = $self->_move_to_user('upload');
    ## Now move file
    if ($old_path && $new_path) {
      ## Create path to new destination
      my $tmp_dir = $hub->species_defs->ENSEMBL_TMP_DIR;
      my @path_elements = split('/', $new_path);
      pop @path_elements;
      my $dir = join ('/', @path_elements);
      create_path($tmp_dir.'/'.$dir, {'no_exception' => 1});
      ## Set full paths
      my $copied = copy_files({$tmp_dir.'/'.$old_path => $tmp_dir.'/'.$new_path}, {'no_exception' => 1});
      if ($copied) {
        my $result = delete_file($tmp_dir.'/'.$old_path, {'nice' => 1, 'no_exception' => 1});
        if ($result->{'error'}) {
          warn "!!! ERROR ".@{$result->{'error'}};
        }
      }
    }
  }
  else {
    $self->_set_error_message('uploaded data');
  }
  return undef;
}

sub save_remote {
## Move the session record for an attached file to the user record
  my $self = shift;
  my $hub  = $self->hub;
  my $user = $hub->user;

  if ($user) {
    $self->_move_to_user('url');
  }
  else {
    $self->_set_error_message('information about your attached data');
  }
  return undef;
}

sub delete_upload {
### Delete file and session/user record for an uploaded file
  my ($self, @args) = @_;
  my $hub  = $self->hub;

  my $rel_path = $self->_delete_record('upload', @args);
  if ($rel_path) {
    ## Also remove file
    my $tmp_dir = $hub->species_defs->ENSEMBL_TMP_DIR;
    my $result = delete_file($tmp_dir.'/'.$rel_path, {'nice' => 1, 'no_exception' => 1});
    if ($result->{'error'}) {
      warn "!!! ERROR ".@{$result->{'error'}};
    }
  } 
  return undef;
}

sub delete_remote {
### Delete record for an attached file
  my ($self, @args) = @_;
  $self->_delete_record('url', @args);
  return undef;
}

sub mass_update {
### Catchall method for enable/disable/delete buttons
  my $self = shift;
  if ($self->hub->param('enable_button')) {
    $self->enable_files;
  }
  elsif ($self->hub->param('disable_button')) {
    $self->disable_files;
  }
  elsif ($self->hub->param('delete_button')) {
    $self->delete_files;
  }
}

sub delete_files {
  my $self = shift;
  my @files = $self->hub->param('files');
  #warn ">>> DELETING FILES @files";
  foreach (@files) {
    my ($source, $code, $id) = split('_', $_);
    if ($source eq 'upload') {
      #$self->delete_upload($source, $code, $id);
    }
    else {
      #$self->delete_remote($source, $code, $id);
    }
  }
}

sub enable_files {
  my $self = shift;

}

sub disable_files {
  my $self = shift;

}

sub _set_error_message {
## Add a message to session
  my ($self, $text) = @_;
  my $hub = $self->hub;
  $hub->session->set_data(
      type     => 'message',
      code     => 'user_not_logged_in',
      message  => "Please log in (or create a user account) if you wish to save this $text.",
      function => '_error'
  );
}

sub _move_to_user {
  my ($self, $type) = @_;
  $type     ||= 'url';
  my $hub     = $self->hub;
  my $user    = $hub->user;
  return unless $user;
  my $session = $hub->session;
  my %args    = ('type' => $type, 'code' => $hub->param('code'));

  my $data = $session->get_data(%args);
  my ($old_path, $new_path);

  my $record;
  if ($type eq 'upload') {
    ## Work out where we're going to copy the file to, because we need to save this
    ## in the new user record
    $old_path     = $data->{'file'};
    my $user_id   = encrypt_value($user->id);
    ($new_path = $old_path) =~ s/session_(\d+)/user_$user_id/;
    $new_path =~ s/temporary/persistent/;
    $data->{'file'} = $new_path if $new_path;
    $record = $user->add_to_uploads($data);
  }
  else {
    $record = $user->add_to_urls($data);
  }
  
  if ($record) {
    $session->purge_data(%args);
    if ($type eq 'upload') {
      return ($old_path, $new_path); 
    }
  }
  
  return undef;
}

sub _delete_record {
  my ($self, $type, $source, $code, $id) = @_;
  my $hub       = $self->hub;

  my $source  ||= $hub->param('source');
  my $code    ||= $hub->param('code');
  my $id      ||= $hub->param('id');

  my $user        = $hub->user;
  my $session     = $hub->session;
  my $session_id  = $session->session_id;
  my ($file, $track_name);

  if ($user && $id) {
    my $checksum;
    ($id, $checksum) = split '-', $id;
    
    my $record = $user->get_record($id);
    
    if ($record) {
      my $check = $record->data->{'code'};
      
      if ($checksum eq md5_hex($check)) {
        ## Capture path to file so we can delete it
        if ($type eq 'upload') {
          $file = $record->data->{'file'};
        }
        ## Now delete record
        $track_name = "${source}_$check";
        $code       = $check;
        $record->delete;
      }
    }
  } else {
    $track_name = $type.'_'.$code;
    my $temp_data = $session->get_data(type => $type, code => $code);

    if ($type eq 'upload') {
      $file = $temp_data->{'file'};
    }

    if ($temp_data->{'format'} eq 'TRACKHUB' && $self->hub->cache) {
      # delete cached hub
      my $url = $temp_data->{'url'};
      my $key = 'trackhub_'.md5_hex($url);
      $self->hub->cache->delete($key);
    }
    $session->purge_data(type => $type, code => $code);
  }
  
  # Remove all shared data with this code and source
  EnsEMBL::Web::Data::Session->search(code => $code, type => $type)->delete_all if $code =~ /_$session_id$/;
  
  $self->update_configs([ $track_name ]) if $track_name;

  return $type eq 'url' ? undef : $file;
}
    
sub update_configs {
  my ($self, $old_tracks, $new_tracks) = @_;
  my $hub            = $self->hub;
  my $session        = $hub->session;
  my $config_adaptor = $hub->config_adaptor;
  my %valid_species  = map { $_ => 1 } $self->species_defs->valid_species;
  my $updated;
  
  foreach my $config (grep $_->{'type'} eq 'image_config', values %{$config_adaptor->all_configs}) {
    my $update;
    
    foreach my $data (scalar(grep $valid_species{$_}, keys %{$config->{'data'}}) ? values %{$config->{'data'}} : $config->{'data'}) {
      foreach my $key (@$old_tracks) {
        my $old_track = delete $data->{$key};
        
        if ($old_track) {
          $data->{$_}{'display'} = $old_track->{'display'} for @$new_tracks;
          
          foreach my $species (keys %{$data->{'track_order'} || {}}) {

            my $new_track_order = [];

            foreach my $order (@{$data->{'track_order'}{$species}}) {
              my $track_regexp = qr/^$key(\.(r|f))?$/;

              if ($order->[0] =~ $track_regexp) {
                for (@$new_tracks) {
                  push @$new_track_order, [ "$_$1", $order->[1] ];
                }
              } elsif ($order->[1] =~ $track_regexp) {
                for (reverse @$new_tracks) {
                  push @$new_track_order, [ $order->[0], "$_$1" ];
                }
              } else {
                push @$new_track_order, $order;
              }
            }

            $data->{'track_order'}{$species} = $new_track_order;
          }
          
          $update  = 1;
          $updated = 1;
        }
      }
    }
    
    $config_adaptor->set_config(%$config) if $update;
  }
  
  if ($updated) {
    my $user       = $hub->user;
    my $favourites = $session->get_data(type => 'favourite_tracks', code => 'favourite_tracks') || {};
    
    if (grep delete $favourites->{'tracks'}{$_}, @$old_tracks) {
      $favourites->{'tracks'}{$_} = 1 for @$new_tracks;
      
      if (scalar keys %{$favourites->{'tracks'}}) {
        $session->set_data(%$favourites);
      } else {
        delete $favourites->{'tracks'};
        $session->purge_data(%$favourites);
      }
      
      $user->set_favourite_tracks($favourites->{'tracks'}) if $user;
    }
  }
}

1;
