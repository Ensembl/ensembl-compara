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

package EnsEMBL::Web::Controller::Share;

use strict;

use Apache2::RequestUtil;
use DBI;
use Digest::MD5    qw(md5_hex);
use HTML::Entities qw(encode_entities);
use JSON           qw(from_json);
use URI::Escape    qw(uri_escape uri_unescape);

use EnsEMBL::Web::Command::UserData::CheckShare;
use EnsEMBL::Web::Hub;

use base qw(EnsEMBL::Web::Controller);

sub new {
  my $class = shift;
  my $r     = shift || Apache2::RequestUtil->can('request') ? Apache2::RequestUtil->request : undef;
  my $args  = shift || {};
  my $hub   = EnsEMBL::Web::Hub->new({
    apache_handle  => $r,
    session_cookie => $args->{'session_cookie'},
    user_cookie    => $args->{'user_cookie'},
  });
  
  my $self = { hub => $hub };
  
  bless $self, $class;
    
  my $func = $hub->param('create') ? 'create' : 'accept';
  my $url  = $self->$func;
  
  $hub->redirect($url) if $func eq 'accept';
  
  return $self;
}

# TODO: rewrite sharing code so that it comes through here for everything (not ShareURL)

sub dbh {
  my $self = shift;
  my $sd   = $self->hub->species_defs;
  my $dbh;
  
  # try and get user db connection. If it fails the use backup port
  eval {
    $dbh = DBI->connect(sprintf('DBI:mysql:database=%s;host=%s;port=%s', $sd->ENSEMBL_USERDB_NAME, $sd->ENSEMBL_USERDB_HOST, $sd->ENSEMBL_USERDB_PORT),        $sd->ENSEMBL_USERDB_USER, $sd->ENSEMBL_USERDB_PASS) ||
           DBI->connect(sprintf('DBI:mysql:database=%s;host=%s;port=%s', $sd->ENSEMBL_USERDB_NAME, $sd->ENSEMBL_USERDB_HOST, $sd->ENSEMBL_USERDB_PORT_BACKUP), $sd->ENSEMBL_USERDB_USER, $sd->ENSEMBL_USERDB_PASS);
  };
  
  return $dbh || undef;
}

sub image_config_data {
  my ($self, $type, @species) = @_;
  
  return {} unless $type;
  
  my $hub           = $self->hub;
  my $image_config  = $hub->get_imageconfig($type);
  my $multi_species = $image_config->isa('EnsEMBL::Web::ImageConfig::MultiSpecies') && $image_config->{'all_species'};
  my @user_data;
  
  foreach my $sp (scalar @species ? @species : $hub->species) {
    my $ic = $multi_species ? $hub->get_imageconfig($type, $sp, $sp) : $image_config;
    push @user_data, $ic->get_node('user_data'), grep $_->get('datahub_menu'), @{$ic->tree->child_nodes};
  }
  
  return ($image_config, map { $_ ? $_->nodes : () } @user_data);
}

sub clean_hash {
  my ($self, $hash) = @_;
  
  foreach (grep ref $hash->{$_} eq 'HASH', keys %$hash) {
    $self->clean_hash($hash->{$_}) if scalar keys %{$hash->{$_}};
    delete $hash->{$_} unless scalar keys %{$hash->{$_}};
  }
  
  return $hash;
}

sub create {
  my $self    = shift;
  my $hub     = $self->hub;
  my $referer = $hub->referer;
  
  return if $referer->{'external'}; 
  
  my $type       = $hub->type = $referer->{'ENSEMBL_TYPE'};
  my $share_type = $hub->param('share_type') || 'page';
  my $configuration;
  
  if ($share_type eq 'page') {
    $configuration = "EnsEMBL::Web::Configuration::$type";
    return unless $self->dynamic_use($configuration);
  }
  
  my $action       = $referer->{'ENSEMBL_ACTION'};
  my $function     = $referer->{'ENSEMBL_FUNCTION'};
  my @view_configs = $configuration ? map { $hub->get_viewconfig(@$_) || () } @{$configuration->new_for_components($hub, $action, $function)} : $hub->get_viewconfig($hub->function);
  my $custom_data  = uri_unescape($hub->param('custom_data'));
  my $species      = from_json($hub->param('species'));
  my $species_defs = $hub->species_defs;
  my $version      = $species_defs->ENSEMBL_VERSION;
  my $hash         = $hub->param('hash');
  my $url          = $referer->{'absolute_url'};
     $url          =~ s/www(\.ensembl\.org)/e$version$1/; # filthy hack to force correct site version usage for live ensembl website
     $url         .= "#$hash" if $hash && $url !~ /#$hash/;
  my $data         = {};
  
  foreach my $view_config (@view_configs) {
    my @species       = @{$species->{$view_config->component} || []};
    my %species_check = map { $_ => 1 } @species, $hub->species;
    my ($image_config_settings, %shared_data);
    
    if ($view_config->image_config) {
      my $allow_das = $view_config->image_config_das ne 'nodas';
      my ($image_config, @user_data) = $self->image_config_data($view_config->image_config, @species);
      
      if (scalar @user_data) {
        if ($custom_data eq 'none') {
          $image_config_settings = $image_config->share;
        } elsif ($custom_data) {
          ($image_config_settings, %shared_data) = $self->get_shared_data($image_config, $allow_das, $custom_data);
        } elsif ($self->get_custom_tracks($allow_das, \%species_check, \@user_data)) {
          return;
        }
      }
      
      $image_config_settings ||= $image_config->get_user_settings;
      
      if (scalar @species) {
        delete $image_config_settings->{$_} for grep !$species_check{$_}, keys %$image_config_settings;
      }
    }
    
    $data->{$view_config->component} = {
      view_config  => $view_config->get_user_settings,
      image_config => $image_config_settings,
      %shared_data
    };
  }
  
  $data = $self->clean_hash($data);
  
  if (scalar keys %$data) {
    $data = $self->jsonify($data);
    
    my $code = join '', md5_hex("${url}::$data"), $hub->session->session_id, $hub->user ? $hub->user->id : '';
    my $dbh  = $self->dbh;
    
    if ($dbh) {
      if (!$dbh->selectrow_array('SELECT count(*) FROM share_url WHERE code = ?', {}, $code)) {
        $dbh->do('INSERT INTO share_url VALUES (?, ?, ?, ?, ?, ?, 0, now())', {}, $code, $url, $type, join('/', grep $_, $action, $function), $data, $share_type);
      }
      
      $dbh->disconnect;
    }
    
    $url = $species_defs->ENSEMBL_BASE_URL . $hub->url({ type => 'Share', action => $code, function => undef, __clear => 1 });
  }
  
  print $self->jsonify({ url => $url });
}

sub get_custom_tracks {
  my ($self, $allow_das, $species_check, $user_data) = @_;
  my $hub        = $self->hub;
  my $session    = $hub->session;
  my $user       = $hub->user;
  my %off_tracks = map { $_->get('display') eq 'off' ? ($_->id => 1) : () } @$user_data;
  my @custom_tracks;
  
  foreach (grep $species_check->{$_->{'species'}}, map { $session->get_data(type => $_), $user ? $user->get_records($_ . 's') : () } qw(upload url)) {
    my @track_ids = split ', ', $_->{'analyses'} || "$_->{'type'}_$_->{'code'}";
    
    # don't prompt to share custom tracks which are turned off
    push @custom_tracks, [ $_->{'name'}, $_->{'record_id'} ? join '-', $_->{'record_id'}, md5_hex($_->{'code'}) : $_->{'code'} ] unless scalar @track_ids == scalar grep $off_tracks{$_}, @track_ids; 
  }
  
  if ($allow_das) {
    foreach (grep $species_check->{$_->{'coords'}[0]{'species'}}, $session->get_data(type => 'das'), $user ? $user->get_records('dases') : ()) {
      push @custom_tracks, [ "$_->{'label'} (DAS)", join ' ', uri_escape("das:$_->{'url'}/$_->{'dsn'}"), $_->{'dsn'}, $_->{'label'} ] unless $off_tracks{"das_$_->{'dsn'}"};
    }
  }
  
  if (scalar @custom_tracks) {
    print $self->jsonify({ share => \@custom_tracks });
    return 1;
  }
}

sub get_shared_data {
  my ($self, $image_config, $allow_das, $custom_data) = @_;
  my $hub     = $self->hub;
  my $session = $hub->session;
  my $user    = $hub->user;
  my $tree    = $image_config->tree;
  my (@shared_data, @shared_das, @das, @allowed);
  
  foreach (split ',', $custom_data) {
    if (/^das:(.+)/) {
      my @d = split ' ', $1, 3;
      push @shared_das, \@d;
      push @das, $d[1];
    } else {
      push @shared_data, $_;
    }
  }
  
  @shared_data = EnsEMBL::Web::Command::UserData::CheckShare->new({ hub => $hub, object => $self->new_object('UserData', {}, { _hub => $hub }) })->process(@shared_data) if scalar @shared_data;
  
  # Sharing an uploaded file will change the track ids used in the image_config, so re-apply the configuration record
  $session->apply_to_image_config($image_config);
  
  my %shared = map { $_ => 1 } @shared_data, @das;
  
  foreach (grep $shared{$_->{'user_record_id'} || $_->{'code'}}, map { $session->get_data(type => $_), $user ? $user->get_records($_ . 's') : () } qw(upload url)) {
    push @allowed, uc $_->{'format'} eq 'DATAHUB' ? $tree->clean_id($_->{'name'}) : split ', ', $_->{'analyses'} || "$_->{'type'}_$_->{'code'}";
  }
  
  push @allowed, map { $shared{$_->{'dsn'}} ? "das_$_->{'dsn'}" : () } $session->get_data(type => 'das'), $user ? $user->get_records('dases') : () if $allow_das;
  
  return (
    $image_config->share(map { $_ => 1 } @allowed),
    scalar @shared_data ? (shared_data => \@shared_data) : (),
    scalar @shared_das  ? (shared_das  => \@shared_das)  : (),
  );
}

sub accept {
  my $self = shift;
  my $hub  = $self->hub;
  my $dbh  = $self->dbh;
  
  return '/' unless $dbh;
  
  my ($url, $type, $action, $data, $share_type) = $dbh->selectrow_array('SELECT url, type, action, data, share_type FROM share_url WHERE code = ?', {}, $hub->action);
  
  $dbh->do('UPDATE share_url SET used = used + 1 WHERE code = ?', {}, $hub->action) if $url;
  $dbh->disconnect;
  
  return '/' unless $url;
  
  my $configuration;
  
  if ($share_type eq 'page') {
    $configuration = "EnsEMBL::Web::Configuration::$type";
    return '/' unless $self->dynamic_use($configuration);
  }
  
  $hub->type = $type;
  $hub->param('reset', 'all');
  
  my $session      = $hub->session;
  my $user         = $hub->user;
  my %custom_data  = map { $_->{'code'} => 1 } map { $session->get_data(type => $_), $user ? $user->get_records($_ . 's') : () } qw(upload url);
  my %custom_das   = map { $_->{'dsn'}  => 1 } $session->get_data(type => 'das'), $user ? $user->get_records('dases') : ();
     $data         = from_json($data);
  my @view_configs = $configuration ? map { $hub->get_viewconfig(@$_) || () } @{$configuration->new_for_components($hub, split '/', $action, 2)} : $hub->get_viewconfig(keys %$data);
  my (@revert, $manage,%saveds);
 
  my @altered; 
  foreach my $view_config (@view_configs) {
    my $config       = $data->{$view_config->component};
    my $ic_type      = $view_config->image_config;
    ## Save current config for this component (if any)
    my @current_configs = ($hub->config_adaptor->get_config('view_config', $view_config->code),
                            $hub->config_adaptor->get_config('image_config', $ic_type));
    my $record_type_id  = $hub->user ? $hub->user->id : $session->create_session_id;

    if (scalar(@current_configs)) {
      $saveds{$view_config->component} =
        $self->save_config($view_config->code, $ic_type, (
          record_type     => 'session',
          record_type_ids => [$record_type_id],
          name            => $view_config->title . ' - '. $self->pretty_date(time, 'simple_datetime'),
          description     => 'This configuration was automatically saved when you used a URL to view a shared image. It contains your configuration before you accepted the shared image.',
        ));
    }
    
    $session->receive_shared_data(grep !$custom_data{$_}, @{$config->{'shared_data'}}) if $config->{'shared_data'};
  }
  foreach my $view_config (@view_configs) {
    my $config       = $data->{$view_config->component};
    my $ic_type      = $view_config->image_config;
    my $image_config = $ic_type ? $hub->get_imageconfig($ic_type) : undef;


    if ($config->{'shared_das'}) {
      my @das_sources;
      
      foreach (grep !$custom_das{$_}, @{$config->{'shared_das'}}) {
        my ($source, $id, $label) = @$_;
        
        push @das_sources, $label if $session->add_das_from_string($source, $ic_type, {
          display => $config->{'image_config'}{$id}{'display'} || [ map { $config->{'image_config'}{$_}{$id}{'display'} || () } keys %{$config->{'image_config'}} ]->[0]
        });
      }
      
      if (scalar @das_sources) {
        $session->add_data(
          type     => 'message',
          function => '_info',
          code     => 'das:' . md5_hex(join ',', @das_sources),
          message  => sprintf('The following DAS sources have been attached:<ul><li>%s</li></ul>', join '</li><li>', @das_sources)
        );
      }
    }
  
    $self->clean_hash($config->{'image_config'});
    
    $view_config->reset($image_config);
    
    if ($image_config && scalar keys %{$config->{'image_config'}}) {
      my @changes;
      foreach (keys %{$config->{'image_config'}}) {
        my $node = $image_config->get_node($_) or next;
        my $track_name = $node->data->{'name'} || $node->data->{'caption'};
        push @changes, $track_name if $track_name;
      }
      $image_config->set_user_settings($config->{'image_config'});
      $image_config->altered(@changes);
      push @altered, @changes;
    }
    
    if (scalar keys %{$config->{'view_config'}}) {
      $view_config->set_user_settings($config->{'view_config'});
      $view_config->altered = 1;
    }
    
    if (scalar $view_config->altered || ($image_config && $image_config->is_altered)) {
      my $saved_config = $saveds{$view_config->component};
      push @revert, [ sprintf('
        <a class="update_panel config-reset" rel="%s" href="%s">Revert to previous configuration%%s</a>',
        $view_config->component,
        $saved_config ?
          $hub->url({ type => 'UserData', action => 'ModifyConfig', function => 'activate', record_id => $saved_config->{'saved'}[0]{'value'}, __clear => 1 }) :
          $hub->url('Config', { action => $view_config->component, function => undef, reset => 'all', __clear => 1 })
      ), ' (' . $view_config->title . ')' ];
      
      if ($saved_config) {
        $manage ||= sprintf '<a class="modal_link config" rel="modal_user_data" href="%s">View saved configurations</a>', $hub->url({ type => 'UserData', action => 'ManageConfigs', function => undef, __clear => 1 });
      }
    }
  }
  
  if (scalar @revert) {
    my $tracks = join(', ', @altered);
    $session->add_data(
      type     => 'message',
      function => '_info',
      code     => 'configuration',
      order    => 101,
      message  => sprintf('
        <p>The URL you just used has changed the %s this page%s. You may want to:</p>
        <p class="tool_buttons" style="width:225px">
          %s
          %s
        </p>
      ',
      $tracks ? "following tracks: $tracks<br /> on" : 'configuration for', 
      $manage ? ', and your previous configuration has been saved' : '', join('', map { sprintf $_->[0], scalar @revert > 1 ? $_->[1] : '' } @revert), $manage)
    );
  }
  
  $session->store;
  
  return $url;
}

1;
