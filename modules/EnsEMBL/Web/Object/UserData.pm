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

package EnsEMBL::Web::Object::UserData;

### NAME: EnsEMBL::Web::Object::UserData
### Object for accessing data uploaded by the user

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

use EnsEMBL::Web::REST;
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

sub get_userdata_records {
  ## Gets session and user record objects for upload and url type
  ## @return List of hashrefs
  my $self    = shift;
  my $hub     = $self->hub;
  my $session = $hub->session;
  my $user    = $hub->user;
  my @records = map $_->get_records_data({'type' => [qw(upload url)]}), grep $_, $session, $user;

  return \@records;
}

sub flip_records {
## Set 'disconnect' flag on one or more records
  my ($self, $records, $disconnect)  = @_;
  $disconnect ||= 0;
  my $hub   = $self->hub;
  my $count = 0;

  foreach (@{$records||[]}) {
    my ($manager, $record);
    my ($type, $code, $id) = split('_', $_);
    $code .= '_'.$id;

    foreach my $m (grep $_, $hub->user, $hub->session) {
      $record = $m->get_record_data({'type' => $type, 'code' => $code});
      $manager = $m;
      last if ($record && keys %$record);
    }
    next unless ($record && keys %$record);
    $record->{'disconnected'} = $disconnect;
    $manager->set_record_data($record);
    $count++;
  }
  return $count;
}

############### methods reached directly by url mapping via ModifyData command #########################

sub md_rename_session_record {
  my $self = shift;
  my $hub  = $self->hub;
  my $name = $hub->param('value');

  $hub->session->set_record_data({type => $hub->param('source'), code => $hub->param('code'), name => $name}) if $name;
  return 1;
}

sub md_rename_user_record {
  my $self  = shift;
  my $hub   = $self->hub;
  my $user  = $hub->user;
  my $name  = $hub->param('value');

  $user->set_record_data({type => $hub->param('source'), code => $hub->param('code'), name => $name}) if $user && $name;
  return 1;
}

sub md_save_upload {
## Move an uploaded file to a persistent directory
  my $self = shift;
  my $hub  = $self->hub;
  my $user = $hub->user;

  if ($user) {
    my ($old_path, $new_path) = $self->_move_to_user('upload');
    ## Now move file
    if ($old_path && $new_path) {
      ## Create path to new destination
      my $tmp_dir = $hub->species_defs->ENSEMBL_USERDATA_DIR;
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

sub md_save_remote {
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

sub md_delete_upload {
### Delete file and session/user record for an uploaded file
  my $self  = shift;
  my $hub   = $self->hub;

  my ($source, $code, $id) = @_ ? @_ : ($hub->param('source'), reverse split('-', $hub->param('id') || ''));

  my $rel_path = $self->_delete_record('upload', $source, $code, $id);
  if ($rel_path) {
    ## Also remove file
    my $tmp_dir = $hub->species_defs->ENSEMBL_USERDATA_DIR;
    my $result = delete_file($tmp_dir.'/'.$rel_path, {'nice' => 1, 'no_exception' => 1});
    if ($result->{'error'}) {
      warn "!!! ERROR ".@{$result->{'error'}};
    }
  } 
  return undef;
}

sub md_delete_trackhub {
### Delete all records for a given trackhub
  my $self  = shift;
  my $hub   = $self->hub;
  my (@th_records, $record_manager, $current_record);

  ## First get the current record 
  foreach my $manager (grep $_, $hub->user, $hub->session) {
    $current_record = $manager->get_record_data({'type' => 'url', 'code' => $hub->param('code')});
    $record_manager = $manager;
    last if ($current_record && keys %$current_record);
  }
  return unless $current_record;
  my $trackhub_url = $current_record->{'url'};
  
  ## Now get all records for this trackhub
  foreach my $record (@{$record_manager->records({'type' => 'url'})||[]}) {
    next unless $record->{'data'}{'url'} eq $trackhub_url;
    push @th_records, $record;
  }

  ## Now delete them all
  foreach (@th_records) {
    $self->_delete_record('url', undef, $_->{'code'}, $_->{'record_id'});
  }
  return undef;
}

sub md_delete_remote {
### Delete record for an attached file
  my $self  = shift;
  my $hub   = $self->hub;

  my ($source, $code, $id) = @_ ? @_ : ($hub->param('source'), reverse split('-', $hub->param('id') || ''));

  $self->_delete_record('url', $source, $code, $id);
  return undef;
}

sub md_mass_update {
### Catchall method for connect/disconnect/delete buttons
  my $self = shift;
  my $method = $self->hub->param('mu_action').'_files';
  $self->$method;
  return undef;
}

######## 

sub delete_files {
  my $self = shift;
  my @records = $self->hub->param('record');
  foreach (@records) {
    my ($source, $code, $id) = split('_', $_);
    $code .= '_'.$id;
    if ($source eq 'upload') {
      $self->md_delete_upload($source, $code, $id);
    }
    else {
      $self->md_delete_remote($source, $code, $id);
    }
  }
}

sub connect_files {
  my $self = shift;
  my @records = $self->hub->param('record');
  $self->flip_records([@records]);
}

sub disconnect_files {
  my $self = shift;
  my @records = $self->hub->param('record');
  $self->flip_records([@records], 1);
}

sub _set_error_message {
## Add a message to session
  my ($self, $text) = @_;
  my $hub = $self->hub;
  $hub->session->set_record_data({
      type     => 'message',
      code     => 'user_not_logged_in',
      message  => "Please log in (or create a user account) if you wish to save this $text.",
      function => '_error'
  });
}

sub _move_to_user {
  my ($self, $type) = @_;
  $type     ||= 'url';
  my $hub     = $self->hub;
  my $user    = $hub->user;
  return unless $user;
  my $session = $hub->session;
  my %args    = ('type' => $type, 'code' => $hub->param('code'));

  my $data = $session->get_record_data(\%args);
  my $record_id = delete $data->{'record_id'}; # otherwise it will try to update the record with the given id, which may belong to another user (and will throw an exception)
  my ($old_path, $new_path);

  return unless $record_id;

  if ($type eq 'upload') {
    ## Work out where we're going to copy the file to, because we need to save this
    ## in the new user record
    $old_path     = $data->{'file'};
    my $user_id   = encrypt_value($user->id);
    ($new_path = $old_path) =~ s/session_(\d+)/user_$user_id/;
    $new_path =~ s/temporary/persistent/;
    $data->{'file'} = $new_path if $new_path;
    ## Make a note of where the file was saved, since it can't currently
    ## be shown on other sites such as mirrors or archives
    $data->{'site'} = $hub->species_defs->ENSEMBL_SERVERNAME;
  }
  my $new_record_data = $user->set_record_data($data);

  if (keys %$new_record_data) {
    $session->set_record_data(\%args); # this will remove the session record
    if ($type eq 'upload') {
      return ($old_path, $new_path); 
    }
  }
  
  return undef;
}

sub _delete_record {
  my ($self, $type, $source, $code, $id) = @_;

  my $hub   = $self->hub;
  my $file  = '';
  $code   ||= $hub->param('code');

  foreach my $record_manager (grep $_, $hub->user, $hub->session) {
    my $data            = $record_manager->get_record_data({'type' => $type, 'code' => $code});
    my $record_id       = $data->{'record_id'};
    my $record_type_id  = $data->{'record_type_id'};

    if ($record_id && ($record_id == $id || $record_type_id == $id || $code =~ m/_$record_type_id$/)) { # code column may contain the id suffixed to it
      $file = $data->{'shared'} ? undef : $data->{'file'};
      $record_manager->delete_records({'type' => $type, 'code' => $code}); # delete record
      $record_manager->delete_records({'type' => 'userdata_upload_code', 'code' => $code}); # delete any linked userdata_upload_code record
      last;
    }
  }

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
    my $favourites = $session->get_record_data({type => 'favourite_tracks', code => 'favourite_tracks'});
    
    if (grep delete $favourites->{'tracks'}{$_}, @$old_tracks) {
      $favourites->{'tracks'}{$_} = 1 for @$new_tracks;

      delete $favourites->{'tracks'} unless keys %{$favourites->{'tracks'}};

      $session->set_record_data($favourites);

      delete $favourites->{'record_id'};
      $user->set_record_data($favourites) if $user;
    }
  }
}

######## TRACK HUB REGISTRY SEARCHES ##############

sub thr_fetch {
  my ($self, $endpoint) = @_;

  ## REST call
  my $registry = $self->hub->species_defs->TRACKHUB_REGISTRY_URL;
  my $rest = EnsEMBL::Web::REST->new($self->hub, $registry);
  return unless $rest;

  return $rest->fetch($endpoint);
}

sub thr_search {
  my ($self, $url_params) = @_;
  my $hub = $self->hub;

  ## REST call
  my $registry = $hub->species_defs->TRACKHUB_REGISTRY_URL;
  my $rest = EnsEMBL::Web::REST->new($hub, $registry);
  return unless $rest;

  my ($result, $error);
  my $endpoint = 'api/search';
  my $post_content = {'query' => $hub->param('query')};

  ## We have to rename these params within the webcode as they conflict with ours
  $post_content->{'type'}     = $hub->param('data_type');
  $post_content->{'species'}  = $hub->param('thr_species');

  ## Search by either assembly or accession, depending on config
  my $key = $hub->param('assembly_key');
  $key = 'assembly' if $key eq 'name';
  $post_content->{$key} = $hub->param('assembly_id');

  my $args = {'method' => 'post', 'content' => $post_content};
  $args->{'url_params'} = $url_params if $url_params;

  return $rest->fetch($endpoint, $args);
}

sub thr_ok_species {
### Check a roster of species against the ones in the THR
  my ($self, $thr_species, $current_species) = @_;
  my $hub = $self->hub;
  my $ok_species;

  my $sci_name        = $hub->species_defs->get_config($current_species, 'SPECIES_SCIENTIFIC_NAME');
  my $assembly_param  = 'ASSEMBLY_VERSION';
  my $assembly        = $hub->species_defs->get_config($current_species, $assembly_param);
  my $key             = 'name';

  if ($thr_species->{$sci_name}) {
    ## Check that we have the right assembly
    my $found = 0;
    ($found, $key) = $self->_find_assembly($thr_species->{$sci_name}, $assembly_param, $key, $assembly);
    if ($found) {
      $ok_species = {'thr_name' => $sci_name, 'assembly_key' => $key, 'assembly_id' => $assembly};
    }
  }
  else {
    ## No exact match, so try everything else
    $assembly_param = $hub->species_defs->get_config($current_species, 'THR_ASSEMBLY_PARAM')
                          || 'ASSEMBLY_ACCESSION';
    $key = $assembly_param eq 'ASSEMBLY_ACCESSION' ? 'accession' : 'name';

    while (my ($sp_name, $info) = each (%$thr_species)) {
      my $found = 0;
      ($found, $key) = $self->_find_assembly($info, $assembly_param, $key, $assembly);
      if ($found) {
        $ok_species = {'thr_name' => $sp_name, 'assembly_key' => $key, 'assembly_id' => $assembly};
        last;
      }
    }
  }
  return $ok_species;
}

sub _find_assembly {
  my ($self, $info, $assembly_param, $key, $assembly) = @_;
  my $found = 0;

  if ($assembly_param eq 'ASSEMBLY_ACCESSION') {
    foreach (@$info) {
      if ($_->{'accession'} eq $assembly) {
        $found = 1;
        last;
      }
    }
  }
  else {
    ## Check name and synonyms
    foreach (@$info) {
      if (lc($_->{'name'}) eq lc($assembly)) {
        $found = 1;
      }
      else {
        foreach (@{$_->{'synonyms'}||[]}) {
          if (lc($_) eq lc($assembly)) {
            $found = 1;
            $key = 'synonyms';
            last;
          }
        }
      }
      last if $found;
    }
  }
  return ($found, $key);
}

1;
