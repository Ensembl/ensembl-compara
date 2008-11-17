package EnsEMBL::Web::Object::UserData;
                                                                                   
use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Object);

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Text::FeatureParser;
use EnsEMBL::Web::Data::Record::Upload;
use Bio::EnsEMBL::Utils::Exception qw(try catch);
use Bio::EnsEMBL::ExternalData::DAS::SourceParser; # for contacting DAS servers
use EnsEMBL::Web::File::Text;
use Data::Dumper;
use Digest::MD5 qw(md5_hex);
                                                                                   

my $DEFAULT_CS = 'DnaAlignFeature';

sub data        : lvalue { $_[0]->{'_data'}; }
sub data_type   : lvalue {  my ($self, $p) = @_; if ($p) {$_[0]->{'_data_type'} = $p} return $_[0]->{'_data_type' }; }

sub caption           {
  my $self = shift;
  return 'Custom Data';
}

sub short_caption {
  my $self = shift;
  return 'Data Management';
}

sub counts {
  my $self = shift;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my $counts = {};
  return $counts;
}


#---------------------------------- userdata DB functionality ----------------------------------

sub save_to_db {
  my $self = shift;
  my %args = @_;

  my $tmpdata  = $self->get_session->get_data(%args);
  my $assembly = $tmpdata->{assembly};

  ## TODO: proper error exceptions !!!!!
  my $file    = new EnsEMBL::Web::File::Text($self->species_defs, $tmpdata->{'filename'});
  my $data    = $file->retrieve
    or die "Can't get data out of the file $tmpdata->{'filename'}";
  my $format  = $tmpdata->{'format'};
  my $report;

  my $parser = EnsEMBL::Web::Text::FeatureParser->new();
  $parser->init($data);
  $parser->parse($data, $format);

  my $config = {
    action   => 'new', # or append
    species  => $tmpdata->{species},
    assembly => $tmpdata->{assembly},
  };

  if (my $user = $ENSEMBL_WEB_REGISTRY->get_user) {
    $config->{id} = $user->id;
    $config->{track_type} = 'user';
  } else {
    $config->{id} = $self->session->get_session_id;
    $config->{track_type} = 'session';
  }
  $config->{'file_format'} = $format; 
  my (@analyses, @messages, @errors);
  my @tracks = $parser->get_all_tracks;
  push @errors, 'Sorry, we couldn\'t parse your data.' unless @tracks;
  
  foreach my $track (@tracks) {
    push @errors, 'Sorry, we couldn\'t parse your data.' unless keys %$track;
    foreach my $key (keys %$track) {
      my $track_report = $self->_store_user_track($config, $track->{$key});
      push @analyses, $track_report->{'logic_name'} if $track_report->{'logic_name'};
      push @messages, $track_report->{'feedback'} if $track_report->{'feedback'};
      push @errors, $track_report->{'error'} if $track_report->{'error'};
    }
  }


  $report->{'browser_switches'} = $parser->{'browser_switches'};
  $report->{'analyses'} = \@analyses if @analyses;
  $report->{'feedback'} = \@messages if @messages;
  $report->{'errors'}   = \@errors   if @errors;
  return $report;
}

sub move_to_user {
  my $self = shift;
  my %args = (
    type => 'tmp',
    @_,
  );

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my $data = $self->get_session->get_data(%args);
  my $record;
  
  $record = $user->add_to_uploads($data)
    if $args{type} eq 'upload';

  $record = $user->add_to_urls($data)
    if $args{type} eq 'url';

  if ($record) {
    $self->get_session->purge_data(%args);
    return $record;
  }
  
  return undef;
}

sub store_data {
  ## Parse file and save to genus_species_userdata
  my $self = shift;
  my %args = @_;

  my $tmp_data = $self->get_session->get_data(%args);
  $tmp_data->{'name'} = $self->param('name') if $self->param('name');

  my $report = $self->save_to_db(%args);
  unless ($report->{'errors'}) {

    ## Delete cached file
    my $file = new EnsEMBL::Web::File::Text(
      $self->species_defs,
      $tmp_data->{'filename'},
    );
    $file->delete;

    ## logic names
    my $analyses = $report->{'analyses'};
    my @logic_names = ref($analyses) eq 'ARRAY' ? @$analyses : ($analyses);

    if (my $user = $ENSEMBL_WEB_REGISTRY->get_user) {
      if (my $upload = $user->add_to_uploads(
                        %$tmp_data,
                        type     => 'upload',
                        filename => '',
                        analyses => join(', ', @logic_names),
                        browser_switches => $report->{'browser_switches'}||{}
                      ))  {
                            $self->get_session->purge_data(%args);
                            return $upload->id;
                      }
      warn 'ERROR: Can not save user record.';
      return undef;
    } else {
      if (my $upload = $self->get_session->add_data(
                         %$tmp_data,
                         type     => 'upload',
                         filename => '',
                         analyses => join(', ', @logic_names),
                         browser_switches => $report->{'browser_switches'}||{}
                       )) {
                            $self->get_session->purge_data(%args);
                            return $upload->{code};
                       }
      warn 'ERROR: Can not save session record.';
      return undef;
    }
  }

  warn Dumper($report->{'errors'}) if $report->{'errors'};
  return undef;
}
  
sub delete_upload {
  my $self = shift;

  my $type = $self->param('type');
  my $code = $self->param('code');
  my $id   = $self->param('id');
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  
  if ($type eq 'upload') { 
    my $upload = $self->get_session->get_data(type => $type, code => $code);
    if ($code eq 'tmp') {
      EnsEMBL::Web::File::Text->new($self->species_defs, $upload->{'filename'})->delete;
    } else {
      my @analyses = split(', ', $upload->{analyses});
      $self->_delete_datasource($upload->{species}, $_) for @analyses;
    }    
    $self->get_session->purge_data(type => $type, code => $code);
  } elsif($id && $user) {
    my ($upload) = $user->uploads($id);
    if ($upload) {
      my @analyses = split(', ', $upload->analyses);
      $self->_delete_datasource($upload->species, $_) for @analyses;
      $upload->delete;
    }
  }
}

sub delete_remote {
  my $self = shift;

  my $type = $self->param('type');
  my $code = $self->param('code');
  my $id   = $self->param('id');
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  
  if ($type eq 'url') { 
    $self->get_session->purge_data(type => $type, code => $code);
  }
  elsif ($self->param('logic_name')) {
    my $temp_das = $self->get_session->get_all_das;
    if ($temp_das) {
      my $das = $temp_das->{$self->param('logic_name')};
      $das->mark_deleted() if $das;
      $self->get_session->save_das();
    }
  } 
  elsif ($id && $user) {
    if ($type eq 'das') {
      my ($das) = $user->dases($id);
      if ($das) {
        $das->delete;
      }
    }
    else { 
      my ($url) = $user->urls($id);
      if ($url) {
        $url->delete;
      }
    }
  }
}


sub _store_user_track {
  my ($self, $config, $track) = @_;
  my $report;

  if (my $current_species = $config->{'species'}) {
    my $action = $config->{action} || 'error';
    if( my $track_name = $track->{config}->{name} || 'Default' ) {

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

  my $datasource = new Bio::EnsEMBL::Analysis(
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
  warn "SOURCE $datasource";
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
	  my $feat = new Bio::EnsEMBL::ProteinFeature(
              -translation_id => $object_id,
              -start      => $s,
              -end        => $e,
              -strand     => $f->strand,
              -hseqname   => $f->id,
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
          my($s,$e) = $f->rawstart<$f->rawend?($f->rawstart,$f->rawend):($f->rawend,$f->rawstart);
	  my $feat = new Bio::EnsEMBL::DnaDnaAlignFeature(
                  -slice        => $slice,
                  -start        => $s,
                  -end          => $e,
                  -strand       => $f->strand,
                  -hseqname     => $f->id,
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


#---------------------------------- DAS functionality ----------------------------------

sub get_das_servers {
### Returns a hash ref of pre-configured DAS servers
  my $self = shift;
  
  my @domains = ();
  my @urls    = ();

  my $reg_url = $self->species_defs->get_config('MULTI', 'DAS_REGISTRY_URL');
  my $reg_name = $self->species_defs->get_config('MULTI', 'DAS_REGISTRY_NAME') || $reg_url;

  push( @domains, {'name'  => $reg_name, 'value' => $reg_url} );
  my @extras = @{$self->species_defs->get_config('MULTI', 'ENSEMBL_DAS_SERVERS')};
  foreach my $e (@extras) {
    push( @domains, {'name' => $e, 'value' => $e} );
  }
  #push( @domains, {'name' => $self->param('preconf_das'), 'value' => $self->param('preconf_das')} );

  # Ensure servers are proper URLs, and omit duplicate domains
  my %known_domains = ();
  foreach my $server (@domains) {
    my $url = $server->{'value'};
    next unless $url;
    next if $known_domains{$url};
    $known_domains{$url}++;
    $url = "http://$url" if ($url !~ m!^\w+://!);
    $url .= "/das" if ($url !~ /\/das1?$/);
    $server->{'name'}  = $url if ( $server->{'name'} eq $server->{'value'});
    $server->{'value'} = $url;
  }

  return @domains;
}

# Returns an arrayref of DAS sources for the selected server and species
sub get_das_server_dsns {
  my ($self, @logic) = @_;
  
  my $server  = $self->_das_server_param();
  my $species = $ENV{ENSEMBL_SPECIES};
  if ($species eq 'common') {
    $species = $self->species_defs->ENSEMBL_PRIMARY_SPECIES;
  }

  my $name    = $self->param('das_name_filter');
  @logic      = grep { $_ } @logic;
  my $sources;
  
  try {
    my $parser = Bio::EnsEMBL::ExternalData::DAS::SourceParser->new(
      -location => $server,
      -timeout  => $self->species_defs->ENSEMBL_DAS_TIMEOUT,
      -proxy    => $self->species_defs->ENSEMBL_WWW_PROXY,
      -noproxy  => $self->species_defs->ENSEMBL_NO_PROXY,
    );
    
    $sources = $parser->fetch_Sources(
      -species    => $species || undef,
      -name       => $name    || undef,
      -logic_name => scalar @logic ? \@logic : undef,
    );
    
    if (!$sources || !scalar @{ $sources }) {
      $sources = "No DAS sources found for $server";
    }
    
  } catch {
    warn $_;
    if ($_ =~ /MSG:/) {
      ($sources) = $_ =~ m/MSG: (.*)$/m;
    } else {
      $sources = $_;
    }
  };
  
  return $sources;
}

sub _das_server_param {
  my $self = shift;
  
  for my $key ( 'other_das', 'preconf_das' ) {
    
    # Get and "fix" the server URL
    my $server = $self->param( $key ) || next;
    
    if ($server !~ /^\w+\:/) {
      $server = "http://$server";
    }
    if ($server =~ /^http/) {
      $server =~ s|/*$||;
      if ($server !~ m{/das1?$}) {
        $server = "$server/das";
      }
    }
    $self->param( $key, $server );
    return $server;
    
  }
  
  return undef;
}


1;
