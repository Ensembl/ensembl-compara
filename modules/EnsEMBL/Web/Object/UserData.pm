=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
use Bio::EnsEMBL::ExternalData::DAS::SourceParser qw($GENOMIC_REGEX);

use EnsEMBL::Web::Cache;
use EnsEMBL::Web::DASConfig;
use EnsEMBL::Web::Data::Session;
use EnsEMBL::Web::Document::Table;
use EnsEMBL::Web::Text::Feature::VEP_OUTPUT;
use EnsEMBL::Web::Text::FeatureParser;
use EnsEMBL::Web::TmpFile::Text;
use EnsEMBL::Web::Tools::Misc qw(get_url_filesize);

use base qw(EnsEMBL::Web::Object);

my $DEFAULT_CS = 'DnaAlignFeature';

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

#---------------------------------- userdata DB functionality ----------------------------------

sub save_to_db {
  my ($self, $share, %args) = @_;
  my $hub      = $self->hub;
  my $session  = $hub->session;
  my $user     = $hub->user;
  my $tmpdata  = $session->get_data(%args);
  my $assembly = $tmpdata->{'assembly'};
  my $file     = EnsEMBL::Web::TmpFile::Text->new(filename => $tmpdata->{'filename'}); ## TODO: proper error exceptions !!!!!
  
  return unless $file->exists;
  
  my $data   = $file->retrieve or die "Can't get data out of the file $tmpdata->{'filename'}";
  my $format = $tmpdata->{'format'};
  my $parser = EnsEMBL::Web::Text::FeatureParser->new($self->species_defs);
  my (@analyses, @messages, @errors);
  
  my $config = {
    action             => 'new', # or append
    species            => $tmpdata->{'species'},
    assembly           => $tmpdata->{'assembly'},
    default_track_name => $tmpdata->{'name'},
    file_format        => $format
  };
  
  if ($user && !$share) {
    $config->{'id'}         = $user->id;
    $config->{'track_type'} = 'user';
  } else {
    $config->{'id'}         = $session->session_id;
    $config->{'track_type'} = 'session';
  }
  
  $parser->parse($data, $format);
  
  my @tracks = $parser->get_all_tracks;
  
  push @errors, "Sorry, we couldn't parse your data." unless @tracks;
  
  foreach my $track (@tracks) {
    push @errors, "Sorry, we couldn't parse your data." unless keys %$track;
    
    foreach my $key (keys %$track) {
      my $track_report = $self->_store_user_track($config, $track->{$key});
      
      push @analyses, $track_report->{'logic_name'} if $track_report->{'logic_name'};
      push @messages, $track_report->{'feedback'}   if $track_report->{'feedback'};
      push @errors,   $track_report->{'error'}      if $track_report->{'error'};
    }
  }

  my $report = { browser_switches => $parser->{'browser_switches'} };
  
  $report->{'analyses'} = \@analyses if scalar @analyses;
  $report->{'feedback'} = \@messages if scalar @messages;
  $report->{'errors'}   = \@errors   if scalar @errors;
  
  return $report;
}

sub move_to_user {
  my $self = shift;
  my %args = (
    type => 'upload',
    @_,
  );

  my $hub     = $self->hub;
  my $user    = $hub->user;
  my $session = $hub->session;

  my $data = $session->get_data(%args);
  my $record;
  
  $record = $user->add_to_uploads($data)
    if $args{'type'} eq 'upload';

  $record = $user->add_to_urls($data)
    if $args{'type'} eq 'url';

  if ($record) {
    $session->purge_data(%args);
    return $record;
  }
  
  return undef;
}

sub store_data {
  ## Parse file and save to genus_species_userdata
  my $self     = shift;
  my %args     = @_;
  my $share    = delete $args{'share'};
  my $hub      = $self->hub;
  my $user     = $hub->user;
  my $session  = $hub->session;
  my $tmp_data = $session->get_data(%args);
  
  $tmp_data->{'name'} = $hub->param('name') if $hub->param('name');
  
  my $report = $tmp_data->{'analyses'} ? $tmp_data : $self->save_to_db($share, %args);
  
  if ($report->{'errors'}) {
    warn Dumper($report->{'errors'});
    return undef;
  }
  
  EnsEMBL::Web::TmpFile::Text->new(filename => $tmp_data->{'filename'})->delete if $tmp_data->{'filename'}; ## Delete cached file
  
  ## logic names
  my $analyses    = $report->{'analyses'};
  my @logic_names = ref $analyses eq 'ARRAY' ? @$analyses : ($analyses);
  my $session_id  = $session->session_id;    
  
  if ($user && !$share) {
    my $upload = $user->add_to_uploads(
      %$tmp_data,
      type             => 'upload',
      filename         => '',
      analyses         => join(', ', @logic_names),
      browser_switches => $report->{'browser_switches'} || {}
    );
    
    if ($upload) {
      $session->purge_data(%args);
      
      # uploaded track keys change when saved, so update configurations accordingly
      $self->update_configs([ "upload_$args{'code'}" ], \@logic_names) if $args{'type'} eq 'upload';
      
      return $upload->id;
    }
    
    warn 'ERROR: Can not save user record.';
    
    return undef;
  } else {
    $session->set_data(
      %$tmp_data,
      %args,
      filename         => '',
      analyses         => join(', ', @logic_names),
      browser_switches => $report->{'browser_switches'} || {},
    );
    
    $self->update_configs([ "upload_$args{'code'}" ], \@logic_names) if $args{'type'} eq 'upload';
    
    return $args{'code'};
  }
}
  
sub delete_upload {
  my $self       = shift;
  my $hub        = $self->hub;
  my $code       = $hub->param('code');
  my $id         = $hub->param('id');
  my $user       = $hub->user;
  my $session    = $hub->session;
  my $session_id = $session->session_id;
  my ($owner, @track_names);
  
  if ($user && $id) {
    my $checksum;
    ($id, $checksum) = split '-', $id;
    
    my $record = $user->get_record($id);
    
    if ($record) {
      my $data = $record->data;
         $code = $data->{'code'};
      
      if ($checksum eq md5_hex($code)) {
        my @analyses = split ', ', $data->{'analyses'};
        push @track_names, @analyses;
        
        $self->_delete_datasource($data->{'species'}, $_) for @analyses;
        $record->delete;
        
        $owner = $code =~ /_$session_id$/;
      }
    }
  } else {
    my $upload = $session->get_data(type => 'upload', code => $code);
       $owner  = $code =~ /_$session_id$/;
    
    if ($upload->{'filename'}) {
      push @track_names, "upload_$code";
      EnsEMBL::Web::TmpFile::Text->new(filename => $upload->{'filename'})->delete if $owner;
    } else {
      my @analyses = split ', ', $upload->{'analyses'};
      push @track_names, @analyses;
      
      if ($owner) {
        $self->_delete_datasource($upload->{'species'}, $_) for @analyses;
      }
    }
    
    $session->purge_data(type => 'upload', code => $code);
  }
  
  # Remove all shared data with this code and source
  EnsEMBL::Web::Data::Session->search(code => $code, type => 'upload')->delete_all if $owner;
  
  $self->update_configs(\@track_names) if scalar @track_names;
}

sub delete_remote {
  my $self       = shift;
  my $hub        = $self->hub;
  my $source     = $hub->param('source');
  my $code       = $hub->param('code');
  my $id         = $hub->param('id');
  my $user       = $hub->user;
  my $session    = $hub->session;
  my $session_id = $session->session_id;
  my $track_name;
  
  if ($user && $id) {
    my $checksum;
    ($id, $checksum) = split '-', $id;
    
    my $record = $user->get_record($id);
    
    if ($record) {
      my $check = $record->data->{$source eq 'das' ? 'logic_name' : 'code'};
      
      if ($checksum eq md5_hex($check)) {
        $track_name = "${source}_$check";
        $code       = $check unless $source eq 'das';
        $record->delete;
      }
    }
  } elsif ($source eq 'das') {
    my $temp_das = $session->get_all_das;
    my $das      = $temp_das ? $temp_das->{$code} : undef;
    
    if ($das) {
      $track_name = "das_$code";
      $das->mark_deleted;
      $session->save_das;
    }
  } else {
    $track_name = "url_$code";
    $session->purge_data(type => 'url', code => $code);
  }
  
  # Remove all shared data with this code and source
  EnsEMBL::Web::Data::Session->search(code => $code, type => 'url')->delete_all if $code =~ /_$session_id$/;
  
  $self->update_configs([ $track_name ]) if $track_name;
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

sub _store_user_track {
  my ($self, $config, $track) = @_;
  my $report;

  if (my $current_species = $config->{'species'}) {
    my $action = $config->{action} || 'error';
    if( my $track_name = $track->{config}->{name} || $config->{default_track_name} || 'Default' ) {

      my $logic_name = join '_', $config->{track_type}, $config->{id}, md5_hex($track_name);
  
      my $dbs         = EnsEMBL::Web::DBSQL::DBConnection->new( $current_species );
      my $dba         = $dbs->get_DBAdaptor('userdata');
      unless($dba) {
        $report->{'error'} = 'No user upload database for this species';
        return $report;
      }
      my $ud_adaptor  = $dba->get_adaptor( 'Analysis' );

      my $datasource = $ud_adaptor->fetch_by_logic_name($logic_name);

## Populate the $config object.....
      my %web_data = %{$track->{'config'}||{}};
      delete $web_data{ 'description' };
      delete $web_data{ 'name' };
      $web_data{'styles'} = $track->{styles};
      $config->{source_adaptor} = $ud_adaptor;
      $config->{track_name}     = $logic_name;
      $config->{track_label}    = $track_name;
      $config->{description}    = $track->{'config'}{'description'};
      $config->{web_data}       = \%web_data;
      $config->{method}         = 'upload';
      $config->{method_type}    = $config->{'file_format'};
      if ($datasource) {
        if ($action eq 'error') {
          $report->{'error'} = "$track_name : This track already exists";
        } elsif ($action eq 'overwrite') {
          $self->_delete_datasource_features($datasource);
          $self->_update_datasource($datasource, $config);
        } elsif( $action eq 'new' ) {
          my $extra = 0;
          while( 1 ) {
            $datasource = $ud_adaptor->fetch_by_logic_name(sprintf "%s_%06x", $logic_name, $extra );
            last if ! $datasource; ## This one doesn't exist so we are going to create it!
            $extra++; 
            if( $extra > 1e4 ) { # Tried 10,000 times this guy is keen!
              $report->{'error'} = "$track_name: Cannot create two many entries in analysis table with this user and name";
              return $report;
            }
          }
          $logic_name = sprintf "%s_%06x", $logic_name, $extra; 
          $config->{track_name}     = $logic_name;
          $datasource = $self->_create_datasource($config, $ud_adaptor);   
          unless ($datasource) {
            $report->{'error'} = "$track_name: Could not create datasource!";
          }
        } else { #action is append [default]....
          if ($datasource->module_version ne $config->{assembly}) {
            $report->{'error'} = sprintf "$track_name : Cannot add %s features to %s datasource",
              $config->{assembly} , $datasource->module_version;
          }
        }
      } else {
        $datasource = $self->_create_datasource($config, $ud_adaptor);

        unless ($datasource) {
          $report->{'error'} = "$track_name: Could not create datasource!";
        }
      }

      return $report unless $datasource;
      if( $track->{config}->{coordinate_system} eq 'ProteinFeature' ) {
        $self->_save_protein_features($datasource, $track->{features});
      } else {
        $self->_save_genomic_features($datasource, $track->{features});
      }
      ## Prepend track name to feedback parameter
      $report->{'feedback'} = $track_name;
      $report->{'logic_name'} = $datasource->logic_name;
    } else {
      $report->{'error_message'} = "Need a trackname!";
    }
  } else {
    $report->{'error_message'} = "Need species name";
  }
  return $report;
}

sub _create_datasource {
  my ($self, $config, $adaptor) = @_;

  my $datasource = Bio::EnsEMBL::Analysis->new(
    -logic_name     => $config->{track_name},
    -description    => $config->{description},
    -web_data       => $config->{web_data}||{},
    -display_label  => $config->{track_label} || $config->{track_name},
    -displayable    => 1,
    -module         => $config->{coordinate_system} || $DEFAULT_CS,
    -program        =>  $config->{'method'}||'upload',
    -program_version => $config->{'method_type'},
    -module_version => $config->{assembly},
  );

  $adaptor->store($datasource);
  return $datasource;
}

sub _update_datasource {
  my ($self, $datasource, $config) = @_;

  my $adaptor = $datasource->adaptor;

  $datasource->logic_name(      $config->{track_name}                          );
  $datasource->display_label(   $config->{track_label}||$config->{track_name}  );
  $datasource->description(     $config->{description}                         );
  $datasource->module(          $config->{coordinate_system} || $DEFAULT_CS    );
  $datasource->module_version(  $config->{assembly}                            );
  $datasource->web_data(        $config->{web_data}||{}                        );

  $adaptor->update($datasource);
  return $datasource;
}

sub _delete_datasource {
  my ($self, $species, $ds_name) = @_;

  my $dbs  = EnsEMBL::Web::DBSQL::DBConnection->new( $species );
  my $dba = $dbs->get_DBAdaptor('userdata');
  my $ud_adaptor  = $dba->get_adaptor( 'Analysis' );
  my $datasource = $ud_adaptor->fetch_by_logic_name($ds_name);
  my $error;
  if ($datasource && ref($datasource) =~ /Analysis/) {
    $error = $self->_delete_datasource_features($datasource);
    $ud_adaptor->remove($datasource); ## TODO: Check errors here as well?
  }
  return $error;
}

sub _delete_datasource_features {
  my ($self, $datasource) = @_;

  my $dba = $datasource->adaptor->db;
  my $source_type = $datasource->module || $DEFAULT_CS;

  if (my $feature_adaptor = $dba->get_adaptor($source_type)) { # 'DnaAlignFeature' or 'ProteinFeature'
   $feature_adaptor->remove_by_analysis_id($datasource->dbID);
   return undef;
  }
  else {
   return "Could not get $source_type adaptor";
  }
}

sub _save_protein_features {
  my ($self, $datasource, $features) = @_;

  my $uu_dba = $datasource->adaptor->db;
  my $feature_adaptor = $uu_dba->get_adaptor('ProteinFeature');

  my $current_species = $uu_dba->species;

  my $dbs  = EnsEMBL::Web::DBSQL::DBConnection->new( $current_species );
  my $core_dba = $dbs->get_DBAdaptor('core');
  my $translation_adaptor = $core_dba->get_adaptor( 'Translation' );

  my $shash;
  my @feat_array;
  my ($report, $errors, $feedback);

  foreach my $f (@$features) {
    my $seqname = $f->seqname;
    unless ($shash->{ $seqname }) {
      if (my $object =  $translation_adaptor->fetch_by_stable_id( $seqname )) {
        $shash->{ $seqname } = $object->dbID;
      }
    }
    next unless $shash->{ $seqname };

    if (my $object_id = $shash->{$seqname}) {
      eval {
          my($s,$e) = $f->rawstart<$f->rawend?($f->rawstart,$f->rawend):($f->rawend,$f->rawstart);
    my $feat = Bio::EnsEMBL::ProteinFeature->new(
              -translation_id => $object_id,
              -start      => $s,
              -end        => $e,
              -strand     => $f->strand,
              -hseqname   => ($f->id."" eq "") ? '-' : $f->id,
              -hstart     => $f->hstart,
              -hend       => $f->hend,
              -hstrand    => $f->hstrand,
              -score      => $f->score,
              -analysis   => $datasource,
              -extra_data => $f->extra_data,
        );

    push @feat_array, $feat;
      };

      if ($@) {
    push @$errors, "Invalid feature: $@.";
      }
    }
    else {
      push @$errors, "Invalid segment: $seqname.";
    }

  }

  $feature_adaptor->save(\@feat_array) if (@feat_array);
  push @$feedback, scalar(@feat_array).' saved.';
  if (my $fdiff = scalar(@$features) - scalar(@feat_array)) {
    push @$feedback, "$fdiff features ignored.";
  }

  $report->{'errors'} = $errors;
  $report->{'feedback'} = $feedback;
  return $report;
}

sub _save_genomic_features {
  my ($self, $datasource, $features) = @_;

  my $uu_dba = $datasource->adaptor->db;
  my $feature_adaptor = $uu_dba->get_adaptor('DnaAlignFeature');

  my $current_species = $uu_dba->species;

  my $dbs  = EnsEMBL::Web::DBSQL::DBConnection->new( $current_species );
  my $core_dba = $dbs->get_DBAdaptor('core');
  my $slice_adaptor = $core_dba->get_adaptor( 'Slice' );

  my $assembly = $datasource->module_version;
  my $shash;
  my @feat_array;
  my ($report, $errors, $feedback);

  foreach my $f (@$features) {
    my $seqname = $f->seqname;
    $shash->{ $seqname } ||= $slice_adaptor->fetch_by_region( undef,$seqname, undef, undef, undef, $assembly );
    if (my $slice = $shash->{$seqname}) {
      eval {
        my($s,$e) = $f->rawstart < $f->rawend ? ($f->rawstart,$f->rawend) : ($f->rawend,$f->rawstart);
        my $feat = Bio::EnsEMBL::DnaDnaAlignFeature->new(
                  -slice        => $slice,
                  -start        => $s,
                  -end          => $e,
                  -strand       => $f->strand,
                  -hseqname     => ($f->id."" eq "") ? '-' : $f->id,
                  -hstart       => $f->hstart,
                  -hend         => $f->hend,
                  -hstrand      => $f->hstrand,
                  -score        => $f->score,
                  -analysis     => $datasource,
                  -cigar_string => $f->cigar_string || ($e-$s+1).'M', #$f->{_attrs} || '1M',
                  -extra_data   => $f->extra_data,
        );
        push @feat_array, $feat;

      };
      if ($@) {
        push @$errors, "Invalid feature: $@.";
      }
    }
    else {
      push @$errors, "Invalid segment: $seqname.";
    }
  }
  $feature_adaptor->save(\@feat_array) if (@feat_array);
  push @$feedback, scalar(@feat_array).' saved.';
  if (my $fdiff = scalar(@$features) - scalar(@feat_array)) {
    push @$feedback, "$fdiff features ignored.";
  }
  $report->{'errors'} = $errors;
  $report->{'feedback'} = $feedback;
  return $report;
}

#---------------------------------- ID history functionality ---------------------------------

sub get_stable_id_history_data {
  my ($self, $file, $size_limit) = @_;
  my $data = $self->hub->fetch_userdata_by_id($file);
  my (@fs, $class, $output, %stable_ids, %unmapped);

  if (my $parser = $data->{'parser'}) { 
    foreach my $track ($parser->{'tracks'}) { 
      foreach my $type (keys %{$track}) {  
        my $features = $parser->fetch_features_by_tracktype($type);
        my $archive_id_adaptor = $self->get_adaptor('get_ArchiveStableIdAdaptor', 'core', $self->species);

        %stable_ids = ();
        my $count = 0;
        foreach (@$features) {
          next if $count >= $size_limit; 
          my $id_to_convert = $_->id;
          my $archive_id_obj = $archive_id_adaptor->fetch_by_stable_id($id_to_convert);
          unless ($archive_id_obj) { 
            $unmapped{$id_to_convert} = 1;
            next;
          }
          my $history = $archive_id_obj->get_history_tree;
          $stable_ids{$archive_id_obj->stable_id} = [$archive_id_obj->type, $history];
          $count++;
        }
      }
    }
  }
  my @data = (\%stable_ids, \%unmapped); 
  return \@data;
}

#------------------------------- Variation functionality -------------------------------
sub calculate_consequence_data {
  my ($self, $file, $size_limit) = @_;

  my $data = $self->hub->fetch_userdata_by_id($file);
  my %slice_hash;
  my %consequence_results;
  my ($f, @snp_effects, @vfs);
  my $count =0;
  my $feature_count = 0;
  my $file_count = 0;
  my $nearest;
  my %slices;
  
  # build a config hash - used by all the VEP methods
  my $vep_config = $self->configure_vep;
  
  ## Convert the SNP features into VEP_OUTPUT features
  if (my $parser = $data->{'parser'}){ 
    foreach my $track ($parser->{'tracks'}) {
      foreach my $type (keys %{$track}) { 
        my $features = $parser->fetch_features_by_tracktype($type);
        
        # include failed variations
        $vep_config->{vfa}->db->include_failed_variations(1) if defined($vep_config->{vfa}->db) && $vep_config->{vfa}->db->can('include_failed_variations');
        
        while ( $f = shift @{$features}){
          $file_count++;
          next if $feature_count >= $size_limit; # $size_limit is max number of v to process, if hit max continue counting v's in file but do not process them
          $feature_count++;
          
          # if this is a variation ID or HGVS, we can use VEP.pm method to parse into VFs
          if($f->isa('EnsEMBL::Web::Text::Feature::ID') || $f->isa('EnsEMBL::Web::Text::Feature::VEP_VCF')) {
            push @vfs, grep {&validate_vf($vep_config, $_)} @{parse_line($vep_config, $f->id)};
            next;
          }
          
          # Get Slice
          my $slice = get_slice($vep_config, $f->seqname);
          next unless defined($slice);
          
          unless ($f->can('allele_string')){
            my $html ='The uploaded data is not in the correct format.
              See <a href="/info/website/upload/index.html#Consequence">here</a> for more details.';
            my $error = 1;
            return ($html, $error);
          }
          
          # name for VF can be specified in extra column or made from location
          # and allele string if not given
          my $new_vf_name = $f->extra || $f->seqname.'_'.$f->rawstart.'_'.$f->allele_string;
          
          # Create VariationFeature
          my $vf;
          
          # sv?
          if($f->allele_string !~ /\//) {
            my $so_term;
            
            # convert to SO term
            my %terms = (
              INS  => 'insertion',
              DEL  => 'deletion',
              TDUP => 'tandem_duplication',
              DUP  => 'duplication'
            );
            
            $so_term = defined $terms{$f->allele_string} ? $terms{$f->allele_string} : $f->allele_string;
            
            $vf = Bio::EnsEMBL::Variation::StructuralVariationFeature->new_fast({
              start          => $f->rawstart,
              end            => $f->rawend,
              chr            => $f->seqname,
              slice          => $slice,
              allele_string  => $f->allele_string,
              strand         => $f->strand,
              adaptor        => $vep_config->{svfa},
              variation_name => $new_vf_name,
              class_SO_term  => $so_term,
            });
          }
          
          # normal vf
          else {
            $vf = Bio::EnsEMBL::Variation::VariationFeature->new_fast({
              start          => $f->rawstart,
              end            => $f->rawend,
              chr            => $f->seqname,
              slice          => $slice,
              allele_string  => $f->allele_string,
              strand         => $f->strand,
              map_weight     => 1,
              adaptor        => $vep_config->{vfa},
              variation_name => $new_vf_name,
            });
          }
          
          next unless &validate_vf($vep_config, $vf);
          
          push @vfs, $vf;
        }
        
        foreach my $line(@{get_all_consequences($vep_config, \@vfs)}) {
          foreach (@OUTPUT_COLS) {
            $line->{$_} = '-' unless defined($line->{$_});
          }
          
          $line->{Extra} = join ';', map { $_.'='.$line->{Extra}->{$_} } keys %{ $line->{Extra} || {} };
          
          my $snp_effect = EnsEMBL::Web::Text::Feature::VEP_OUTPUT->new([
            $line->{Uploaded_variation},
            $line->{Location},
            $line->{Allele},
            $line->{Gene},
            $line->{Feature},
            $line->{Feature_type},
            $line->{Consequence},
            $line->{cDNA_position},
            $line->{CDS_position},
            $line->{Protein_position},
            $line->{Amino_acids},
            $line->{Codons},
            $line->{Existing_variation},
            $line->{Extra},
          ]);
          
          push @snp_effects, $snp_effect;
          
          # if the array is "full" or there are no more items in @features
          if(scalar @snp_effects == 1000 || scalar @$features == 0) {
            $count++;
            next if scalar @snp_effects == 0;
            my @feature_block = @snp_effects;
            $consequence_results{$count} = \@feature_block;
            @snp_effects = ();
          }
        }
        
        if(scalar @snp_effects) {
          $count++;
          my @feature_block = @snp_effects;
          $consequence_results{$count} = \@feature_block;
          @snp_effects = ();
        }
      }
    }
    $nearest = $parser->nearest;
  }
  
  if ($file_count <= $size_limit){
    return (\%consequence_results, $nearest);
  } else {  
    return (\%consequence_results, $nearest, $file_count);
  }
}

sub consequence_data_from_file {
  my ($self, $code) = @_;
  my $results = {};

  my $data = $self->hub->get_data_from_session('upload', $code);
  if (my $parser = $data->{'parser'}){ 
    foreach my $track ($parser->{'tracks'}) {
      foreach my $type (keys %{$track}) { 
        my $vfs = $track->{$type}{'features'};
        $results->{scalar(@$vfs)} = $vfs;
      }
    }
  }
  return $results;
}

sub consequence_table {
  my ($self, $consequence_data) = @_;
  my $hub     = $self->hub;
  my $species = $hub->param('species') || $hub->species;
  my $code    = $hub->param('code');

  my %popups = (
    'var'       => 'What you input (chromosome, nucleotide position, alleles)',
    'location'  => 'Chromosome and nucleotide position in standard coordinate format (chr:nucleotide position or chr:start-end)',
    'allele'    => 'The variant allele used to calculate the consequence',
    'gene'      => 'Ensembl stable ID of the affected gene (e.g. ENSG00000187634)',
    'trans'     => 'Ensembl stable ID of the affected feature (e.g. ENST00000474461)',
    'ftype'     => 'Type of feature (i.e. Transcript, RegulatoryFeature or MotifFeature)',
    'con'       => 'Consequence type of this variant',
    'cdna_pos'  => 'Nucleotide (base pair) position in the cDNA sequence',
    'cds_pos'   => 'Nucleotide (base pair) position in the coding sequence',
    'prot_pos'  => 'Amino acid position in the protein sequence',
    'aa'        => 'All possible amino acids at the position.  This is only given if the variant affects the protein-coding sequence',
    'codons'    => 'All alternative codons at the position.  The position of the variant is highlighted as bold (HTML version) or upper case (text version)',
    'snp'       => 'Known identifiers of variants at that position',
    'extra'     => 'More information',
  );

  my $columns = [
    { key => 'var',      title =>'Uploaded Variation',   help => $popups{'var'}, align => 'center', sort => 'string'        },
    { key => 'location', title =>'Location',             help => $popups{'location'}, align => 'center', sort => 'position_html' },
    { key => 'allele',   title =>'Allele',               help => $popups{'allele'}, align => 'center', sort => 'string'        },
    { key => 'gene',     title =>'Gene',                 help => $popups{'gene'}, align => 'center', sort => 'html'          },
    { key => 'trans',    title =>'Feature',              help => $popups{'trans'}, align => 'center', sort => 'html'          },
    { key => 'ftype',    title =>'Feature type',         help => $popups{'ftype'}, align => 'center', sort => 'html'          },
    { key => 'con',      title =>'Consequence',          help => $popups{'con'}, align => 'center', sort => 'string'        },
    { key => 'cdna_pos', title =>'Position in cDNA',     help => $popups{'cdna_pos'}, align => 'center', sort => 'position'      },
    { key => 'cds_pos',  title =>'Position in CDS',      help => $popups{'cds_pos'}, align => 'center', sort => 'position'      },
    { key => 'prot_pos', title =>'Position in protein',  help => $popups{'prot_pos'}, align => 'center', sort => 'position'      },
    { key => 'aa',       title =>'Amino acid change',    help => $popups{'aa'}, align => 'center', sort => 'none'          },
    { key => 'codons',   title =>'Codon change',         help => $popups{'codons'}, align => 'center', sort => 'none'          },
    { key => 'snp',      title =>'Co-located Variation', help => $popups{'snp'}, align => 'center', sort => 'html'          },
    { key => 'extra',    title =>'Extra',                help => $popups{'extra'}, align => 'left',   sort => 'html'          },
  ];

  my @rows;

  foreach my $feature_set (keys %$consequence_data) {
    foreach my $f (@{$consequence_data->{$feature_set}}) {
      next if $f->id =~ /^Uploaded/;
      
      my $row               = {};
      my $location          = $f->location;
      my $allele            = $f->allele;
      my $url_location      = $f->seqname . ':' . ($f->rawstart - 500) . '-' . ($f->rawend + 500);
      my $uploaded_loc      = $f->id;
      my $feature_id        = $f->feature;
      my $feature_type      = $f->feature_type;
      my $gene_id           = $f->gene;
      my $consequence       = $f->consequence;
      my $cdna_pos          = $f->cdna_position;
      my $cds_pos           = $f->cds_position;
      my $prot_pos          = $f->protein_position;
      my $aa                = $f->aa_change;
      my $codons            = $f->codons;
      my $extra             = $f->extra_col;
      my $snp_id            = $f->snp;
      my $feature_string    = $feature_id;
      my $gene_string       = $gene_id;
      my $snp_string        = $snp_id;
      
      # guess core type from feature ID

      my $core_type = 'otherfeatures' unless $feature_id =~ /^ENS/ and $feature_id !~ /^ENSEST/;
      
      my $location_url = $hub->url({
        species          => $species,
        type             => 'Location',
        action           => 'View',
        r                =>  $url_location,
        contigviewbottom => "variation_feature_variation=normal,upload_$code=normal",
      });
      
      # transcript
      if ($feature_type eq 'Transcript') {
        my $feature_url = $hub->url({
          species => $species,
          type    => 'Transcript',
          action  => 'Summary',
          db      => $core_type,
          t       => $feature_id,
        });
        
        $feature_string = qq{<a href="$feature_url" rel="external">$feature_id</a>};
      }
      # reg feat
      elsif ($feature_id =~ /^ENS.{0,3}R/) {
        my $feature_url = $hub->url({
          species => $species,
          type    => 'Regulation',
          action  => 'Summary',
          rf      => $feature_id,
        });
        
        $feature_string = qq{<a href="$feature_url" rel="external">$feature_id</a>};
      }
      # gene
      elsif ($feature_id =~ /^ENS.{0,3}G/) {
        my $feature_url = $hub->url({
          species => $species,
          type    => 'Gene',
          action  => 'Summary',
          rf      => $feature_id,
        });
        
        $feature_string = qq{<a href="$feature_url" rel="external">$feature_id</a>};
      }
      else {
        $feature_string = $feature_id;
      }

      if ($gene_id ne '-') {
        my $gene_url = $hub->url({
          species => $species,
          type    => 'Gene',
          action  => 'Summary',
          db      => $core_type,
          g       => $gene_id,
        });
        
        $gene_string = qq{<a href="$gene_url" rel="external">$gene_id</a>};
      }
      
      
      $snp_string = '';
      
      if ($snp_id =~ /^\w/){
        
        foreach my $s(split /\,/, $snp_id) {
          my $snp_url =  $hub->url({
            species => $species,
            type    => 'Variation',
            action  => 'Explore',
            v       =>  $s,
          });
          
          $snp_string .= qq{<a href="$snp_url" rel="external">$s</a>,};
        }
        
        $snp_string =~ s/\,$//g;
      }
      
      $snp_string ||= '-';
      
      $consequence =~ s/\,/\,\<br\/>/g;
      
      # format extra string nicely
      $extra = join ";", map {$self->render_sift_polyphen($_); s/(\w+?=)/<b>$1<\/b>/g; $_ } split /\;/, $extra;
      $extra =~ s/;/;<br\/>/g;
      
      $extra =~ s/(ENSP\d+)/'<a href="'.$hub->url({
        species => $species,
        type    => 'Transcript',
        action  => 'ProteinSummary',
        t       =>  $feature_id,
      }).'" rel="external">'.$1.'<\/a>'/e;
      
      #$consequence = qq{<span class="hidden">$ranks{$consequence}</span>$consequence};

      $row->{'var'}      = $uploaded_loc;
      $row->{'location'} = qq{<a href="$location_url" rel="external">$location</a>};
      $row->{'allele'}   = $allele;
      $row->{'gene'}     = $gene_string;
      $row->{'trans'}    = $feature_string;
      $row->{'ftype'}    = $feature_type;
      $row->{'con'}      = $consequence;
      $row->{'cdna_pos'} = $cdna_pos;
      $row->{'cds_pos'}  = $cds_pos;
      $row->{'prot_pos'} = $prot_pos;
      $row->{'aa'}       = $aa;
      $row->{'codons'}   = $codons;
      $row->{'extra'}    = $extra || '-';
      $row->{'snp'}      = $snp_string;

      push @rows, $row;
    }
  }
  
  return EnsEMBL::Web::Document::Table->new($columns, [ sort { $a->{'var'} cmp $b->{'var'} } @rows ], { data_table => '1' });
}

#---------------------------------- DAS functionality ----------------------------------

sub get_das_servers {
### Returns a hash ref of pre-configured DAS servers
  my $self = shift;
  
  my @domains = ();
  my @urls    = ();

  my $reg_url  = $self->species_defs->get_config('MULTI', 'DAS_REGISTRY_URL');
  my $reg_name = $self->species_defs->get_config('MULTI', 'DAS_REGISTRY_NAME') || $reg_url;

  push( @domains, {'caption'  => $reg_name, 'value' => $reg_url} );
  my @extras = @{$self->species_defs->get_config('MULTI', 'ENSEMBL_DAS_SERVERS')};
  foreach my $e (@extras) {
    push( @domains, {'caption' => $e, 'value' => $e} );
  }
  #push( @domains, {'caption' => $self->param('preconf_das'), 'value' => $self->param('preconf_das')} );

  # Ensure servers are proper URLs, and omit duplicate domains
  my %known_domains = ();
  foreach my $server (@domains) {
    my $url = $server->{'value'};
    next unless $url;
    next if $known_domains{$url};
    $known_domains{$url}++;
    $url = "http://$url" if ($url !~ m!^\w+://!);
    $url .= "/das" if ($url !~ /\/das1?$/);
    $server->{'caption'} = $url if ( $server->{'caption'} eq $server->{'value'});
    $server->{'value'}   = $url;
  }

  return @domains;
}

# Returns an arrayref of DAS sources for the selected server and species
sub get_das_sources {
  #warn "!!! ATTEMPTING TO GET DAS SOURCES";
  my ($self, $server, @logic_names) = @_;
  my $clearCache = 0;
  
  my $species = $self->species;
  if ($species eq 'common') {
    $species = $self->species_defs->ENSEMBL_PRIMARY_SPECIES;
  }

  my @name  = grep { $_ } $self->param('das_name_filter');
  my $source_info = [];

  $clearCache = $self->param('das_clear_cache');

  ## First check for cached sources
  my $MEMD = EnsEMBL::Web::Cache->new;

  my $cache_key;
  if ($MEMD) {
    $cache_key = $server . '::SPECIES[' . $species . ']';

    if ($clearCache) {
      $MEMD->delete($cache_key);
    }
    my $unfiltered = $MEMD->get($cache_key) || [];
    #warn "FOUND SOURCES IN MEMORY" if scalar @$unfiltered;

    foreach my $source (@{ $unfiltered }) {
      push @$source_info, EnsEMBL::Web::DASConfig->new_from_hashref( $source );
    }
  }

  unless (scalar @$source_info) {
    #warn ">>> NO CACHED SOURCES, SO TRYING PARSER";
    ## If unavailable, parse the sources
    my $sources = [];
 
    try {
      my $parser = $self->hub->session->das_parser;

      # Fetch ALL sources and filter later in this method (better for caching)
      $sources = $parser->fetch_Sources(
        -location   => $server,
        -species    => $species || undef,
# DON'T DO IN PARSER       -name       => scalar @name  ? \@name  : undef, # label or DSN
# DON'T DO IN PARSER       -logic_name => scalar @logic_names ? \@logic_names : undef, # the URI
      ) || [];
    
      if (!scalar @{ $sources }) {
        my $filters = @name ? ' named ' . join ' or ', @name : '';
        $source_info = "No $species DAS sources$filters found for $server";
      }
    
    } catch {
      #warn $_;
      if ($_ =~ /MSG:/) {
        ($source_info) = $_ =~ m/MSG: (.*)$/m;
      } else {
        $source_info = $_;
      }
    };

    my $csa =  Bio::EnsEMBL::Registry->get_adaptor($species, "core", "CoordSystem");

    # Cache simple caches, not objects
    my $cached = [];
    foreach my $source (@{ $sources }) {
      my $no_mapping = 0;
      my %copy = %{ $source };
      my @coords = map { my %cs = %{ $_ }; \%cs } @{ $source->coord_systems || [] };

      # checking if we support mapping. Excluding sources for which we don't support mapping before filtering the results.
      # $cs - coordinate systems returned from DAS server, tmpfrom - returned by converter.
      foreach my $cs (@coords) {
        if ($cs->{name} =~ m/$GENOMIC_REGEX/i || $cs->{name} eq 'toplevel' ) {

          my $tmpfrom = $csa->fetch_by_name( $cs->{name}, $cs->{version} ) || $csa->fetch_by_name( $cs->{name} );
          if ( !$tmpfrom || ($tmpfrom->version && $tmpfrom->version ne $cs->{version})){
            $no_mapping = 1;
            last;
          }
        }
      }
      if (!$no_mapping) {
        $copy{'coords'} = \@coords;
        push @$cached, \%copy;
        push @$source_info, EnsEMBL::Web::DASConfig->new_from_hashref( $source );
      }
    }
    ## Cache them for later use
    # Only cache if more than 10 sources, so we don't confuse people in the process of setting
    # up small personal servers (by caching their results half way through their setup).
    if (scalar(@$cached) > 10) {
      $MEMD->set($cache_key, $cached, 1800, 'DSN_INFO', $species) if $MEMD;
    }
  }

  # Do filtering here rather than in das_parser so only have to cache one complete set of sources for server
  
  if (scalar(@logic_names)) {
    #print STDERR "logic_names = |" . join('|',@logic_names) . "|\n";
    @$source_info = grep { my $source = $_; grep { $source->logic_name eq $_ } @logic_names  } @$source_info;
  }
  if (scalar(@name)) {
    @$source_info = grep { my $source = $_; grep { $source->label =~ /$_/i || 
                                                   $source->logic_name =~ /$_/i || 
                                                   $source->description =~ /$_/msi || 
                                                   $source->caption =~ /$_/i } @name  } @$source_info;
  }

  #warn '>>> RETURNING '.@$source_info.' SOURCES';
  return $source_info;
}

# render a sift or polyphen prediction with colours
sub render_sift_polyphen {
  my ($self, $string) = @_;
  
  my ($type, $pred_string) = split /\=/, $string;
  
  return $string unless $type =~ /SIFT|PolyPhen|Condel/;
  
  my ($pred, $score) = split /\(|\)/, $pred_string;
  
  my %colours = (
    '-'                  => '',
    'probably_damaging'  => 'red',
    'possibly_damaging'  => 'orange',
    'benign'             => 'green',
    'unknown'            => 'blue',
    'tolerated'          => 'green',
    'deleterious'        => 'red',
    'neutral'            => 'green',
    'not_computable_was' => 'blue',
  );
  
  my $rank_str = '';
  
  if(defined($score)) {
    $rank_str = "($score)";
  }
  
  return qq{$type=<span style="color:$colours{$pred}">$pred$rank_str</span>};
}

sub configure_vep {
  my $self = shift;
  
  my %vep_config;
  
  # get user defined config from $self->param
  foreach my $param (@VEP_WEB_CONFIG) {
    my $value = $self->param($param);
    $vep_config{$param} = $value unless $value eq 'no' || $value eq '';
  }
  
  # frequency filtering
  if($vep_config{filter_common}) {
    $vep_config{check_frequency} = 1;
    
    # set defaults
    $vep_config{freq_freq}   ||= 0.01;
    $vep_config{freq_filter} ||= 'exclude';
    $vep_config{freq_pop}    ||= '1KG_ALL';
    $vep_config{freq_gt_lt}  ||= 'gt';
  }
  
  # get adaptors
  my $species = $self->param('species') || $self->species;
  
  my %species_dbs =  %{$self->species_defs->get_config($species, 'databases')};
  if (exists $species_dbs{'DATABASE_VARIATION'} ){
    $vep_config{tva} = $self->get_adaptor('get_TranscriptVariationAdaptor', 'variation', $species);
    $vep_config{vfa} = $self->get_adaptor('get_VariationFeatureAdaptor', 'variation', $species);
    $vep_config{svfa} = $self->get_adaptor('get_StructuralVariationFeatureAdaptor', 'variation', $species);
    $vep_config{va} = $self->get_adaptor('get_VariationAdaptor', 'variation', $species);
  } else  { 
    $vep_config{tva} = Bio::EnsEMBL::Variation::DBSQL::TranscriptVariationAdaptor->new_fake($species);
    $vep_config{vfa} = Bio::EnsEMBL::Variation::DBSQL::VariationFeatureAdaptor->new_fake($species);
    $vep_config{svfa} = Bio::EnsEMBL::Variation::DBSQL::StructuralVariationFeatureAdaptor->new_fake($species);
  }

  $vep_config{sa}  = $self->get_adaptor('get_SliceAdaptor', $vep_config{'core_type'}, $species);
  $vep_config{ta}  = $self->get_adaptor('get_TranscriptAdaptor', $vep_config{'core_type'}, $species);
  $vep_config{ga}  = $self->get_adaptor('get_GeneAdaptor', $vep_config{'core_type'}, $species);
  $vep_config{csa} = $self->get_adaptor('get_CoordSystemAdaptor', $vep_config{'core_type'}, $species);
  
  if(defined($vep_config{regulatory})) {
    foreach my $type(@REG_FEAT_TYPES) {
      my $adaptor = $self->get_adaptor('get_'.$type.'Adaptor', 'funcgen', $species);
      if(defined($adaptor)) {
        $vep_config{$type.'_adaptor'} = $adaptor;
      }
      else {
        delete $vep_config{regulatory};
        last;
      }
    }
  }
  
  # set some other values
  $vep_config{database}       = 1;
  $vep_config{gene}           = 1;
  $vep_config{whole_genome}   = 1;
  $vep_config{chunk_size}     = 50000;
  $vep_config{quiet}          = 1;
  $vep_config{failed}         = 0;
  $vep_config{gmaf}           = 1;
  $vep_config{check_alleles}  = 1 if $vep_config{check_existing} eq 'allele';
  $vep_config{check_existing} = 1 if defined($vep_config{check_frequency}) && exists $species_dbs{'DATABASE_VARIATION'};
  
  delete $vep_config{format} if $vep_config{format} eq 'id';
  $vep_config{format} = 'vcf' if $vep_config{format} eq 'vep_vcf';
  
  return \%vep_config;
}

sub format_coords {
  my ($self, $start, $end) = @_;
  
  if(!defined($start)) {
    return '-';
  }
  elsif(!defined($end)) {
    return $start;
  }
  elsif($start == $end) {
    return $start;
  }
  elsif($start > $end) {
    return $end.'-'.$start;
  }
  else {
    return $start.'-'.$end;
  }
}

1;
