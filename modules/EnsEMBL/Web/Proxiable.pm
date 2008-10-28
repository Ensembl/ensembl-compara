package EnsEMBL::Web::Proxiable;

use strict;
use warnings;
no warnings "uninitialized";
use base qw( EnsEMBL::Web::Root );

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::ExtURL;
use EnsEMBL::Web::ExtIndex;
use EnsEMBL::Web::Root;
use EnsEMBL::Web::DBSQL::DBConnection;
use CGI qw(escape escapeHTML);


sub table_info {
  my $self = shift;
  return $self->species_defs->table_info( @_ );
}

sub _url {
  my $self = shift;
  my $params  = shift || {};
  die "Not a hashref while calling _url ($params @_)" unless ref($params) eq 'HASH';
  my $species = exists( $params->{'species'} ) ? $params->{'species'} : $self->species;
  my $type    = exists( $params->{'type'}    ) ? $params->{'type'}    : $self->type;
  my $action  = exists( $params->{'action'}  ) ? $params->{'action'}  : $self->action;
  my $fn      = exists( $params->{'function'}) ? $params->{'function'} :
                    ( $action eq $self->action ? $self->function      : undef );

  my %pars = %{$self->core_objects->{'parameters'}};
  if( $params->{'__clear'} ) {
    %pars = ();
    delete $params->{'__clear'};
  }
  delete $pars{'t'}  if $params->{'pt'};
  delete $pars{'pt'} if $params->{'t'};
  delete $pars{'t'}  if $params->{'g'} && $params->{'g'} ne $pars{'g'};

  foreach( keys %$params ) {
    next if $_ =~ /^(species|type|action|function)$/;
    if( defined( $params->{$_} ) ) {
      $pars{$_} = $params->{$_};
    } else {
      delete $pars{$_};
    }
  }
  my $URL = sprintf '/%s/%s/%s', $species, $type, $action.( $fn ? "/$fn" : '' );
  my $join = '?';
## Sort the keys so that the URL is the same for a given set of parameters...
  my $flag = shift;
  if( $flag ) {
    return [$URL, \%pars];
  } 
  foreach ( sort keys %pars ) {
    next unless defined $pars{$_};
    $URL .= sprintf '%s%s=%s', $join, escape($_), $self->hack_escape($pars{$_}) ;
    $join = ';';
  }

  return $URL;
}

sub hack_escape {
  my( $self, $s ) = @_;
  (my $t = escape($s)) =~ s/%3A/:/;
  return $t;
}

sub new {
  my( $class, $data ) = @_;
  my $self = { 'data' => $data };
  bless $self, $class;
  return $self; 
}

sub timer_push {
  my $self = shift;
  return $self->{'data'}{'timer'}->push(@_);
}

sub __data { return $_[0]{'data'}; }
sub input { 
  my $self = shift;
  $self->{'data'}{'_input'} = shift if @_;
  return $self->{'data'}{'_input'};
}

sub core_objects {
  my $self = shift;
  return $self->{'data'}{'_core_objects'};
}

sub _sanitize {
  my $T = shift;
  $T =~ s/<script(.*?)>/[script$1]/igsm;
  $T =~ s/\s*on(\w+)\s*=/ on_$1=/igsm;
  return $T;
}

sub param {
  my $self = shift;
  if( @_ ){ 
    my @T =  map { _sanitize($_) } $self->{'data'}{'_input'}->param(@_);
    if( @T ) {
      return wantarray ? @T : $T[0];
    }
    my $wsc = $self->get_viewconfig( );
    if( $wsc ) {
      if( @_ > 1 ) { $wsc->set(@_); }
      my @val = $wsc->get(@_);
      return wantarray ? @val : $val[0];
    }
    return wantarray ? () : undef;
  } else {
    my @params = map { _sanitize($_) } $self->{'data'}{'_input'}->param();
    my $wsc    = $self->get_viewconfig( ); 
    push @params, $wsc->options() if $wsc;
    my %params = map { $_,1 } @params;
    return keys %params;
  }
}

sub input_param  {
  my $self = shift;
  return _sanitize( $self->{'data'}{'_input'}->param(@_) );
}

sub delete_param { my $self = shift; $self->{'data'}{'_input'}->delete(@_); }
sub type         { return $_[0]{'data'}{'_type'};    }
sub action       { return $_[0]{'data'}{'_action'};  }
sub function     { return $_[0]{'data'}{'_function'};  }
sub script       { return $_[0]{'data'}{'_script'};  }
sub species      { return $_[0]{'data'}{'_species'}; }

sub fix_session {
### Fix the session back to the database - if a session object has been created
### calls store on... this will check whether (a) there are any saveable
### viewconfigs AND (b) if any of the saveable viewconfigs have been altered
  my( $self, $r ) = @_;
return;
  my $session = $self->get_session;
  $session->store($self->apache_handle) if $session;
}

sub DBConnection {
  $_[0]->{'data'}{'_databases'} ||= EnsEMBL::Web::DBSQL::DBConnection->new( $_[0]->species, $_[0]->species_defs );
}
sub session {
  my $self = shift;
  return $self->{'session'} ||= $ENSEMBL_WEB_REGISTRY->get_session;
}

sub get_session {
  my $self = shift;
  return $self->{'session'} || $ENSEMBL_WEB_REGISTRY->get_session;
}

sub database {
  my $self = shift;
  if( $_[0]=~/compara/) {
    return Bio::EnsEMBL::Registry->get_DBAdaptor( 'multi', $_[0] );
  } else {
    return $self->DBConnection->get_DBAdaptor( @_ );
  }
}

sub get_databases { my $self = shift; $self->DBConnection->get_databases( @_ ); }
sub databases_species { my $self = shift; $self->DBConnection->get_databases_species( @_ ); }
sub has_a_problem     { my $self = shift; return scalar( @{$self->{'data'}{'_problem'}} ); }
sub has_fatal_problem { my $self = shift; return scalar( grep { $_->isFatal } @{$self->{'data'}{'_problem'}} ); }
sub has_problem_type  { my( $self,$type ) = @_; return scalar( grep { $_->get_by_type($type) } @{$self->{'data'}{'_problem'}} ); }
sub get_problem_type  { my( $self,$type ) = @_; return grep { $_->get_by_type($type) } @{$self->{'data'}{'_problem'}}; }
sub problem {
  my $self = shift;
  push @{$self->{'data'}{'_problem'}}, EnsEMBL::Web::Problem->new(@_) if @_;
  return $self->{'data'}{'_problem'};
}
sub clear_problems { $_[0]{'data'}{'_problem'} = []; }

sub user { 
 ### x
 warn "xxxxxxxxxxxxxxx DEPRECATED xxxxxxxxxxxxxxxx";
 return undef;
}

sub species_defs    { $_[0]{'data'}{'_species_defs'} ||= $ENSEMBL_WEB_REGISTRY->species_defs; }

sub web_user_db { 
  ### x
  ### Deprecated. Use UserAdaptor from the Registry instead.
  return undef;
}

sub apache_handle { $_[0]{'data'}{'_apache_handle'}; }

sub get_imageconfig  {
### Returns the named (or one based on script) {{EnsEMBL::Web::ImageConfig}} object
  my( $self, $key ) = @_;
  my $session = $self->get_session || return;
#warn "JS5 GUC $key";
  my $T = $session->getImageConfig( $key ); ## No second parameter - this isn't cached!!
  $T->_set_core( $self->core_objects );
  return $T;
}

sub image_config_hash {
### Retuns a copy of the script config stored in the database with the given key
  my $self = shift;
  my $key  = shift;
  my $type = shift || $key;
  my $session = $self->get_session;
#warn "JS5 UCH $key $type";
  return undef unless $session;
  my $T = $session->getImageConfig( $type, $key ); ## {'image_configs'}{$key} ||= $self->get_imageconfig( $type );
  return unless $T;
  $T->_set_core( $self->core_objects );
  return $T;
}

sub get_viewconfig {
### Returns the named (or one based on script) {{EnsEMBL::Web::ViewConfig}} object
  my( $self, $type, $action ) = @_;
  my $session = $self->get_session;
  return undef unless $session;
  my $T = $session->getViewConfig( $type || $self->type, $action || $self->action );
  return $T;
}

sub attach_image_config {
  my( $self, $key, $image_key ) = @_;
  my $session = $self->get_session;
  return undef unless $session;
  my $T = $session->attachImageConfig( $key, $image_key );
  $T->_set_core( $self->core_objects );
  return $T;
}

# Handling ExtURLs
sub ExtURL { return $_[0]{'data'}{'_ext_url_'} ||= EnsEMBL::Web::ExtURL->new( $_[0]->species, $_[0]->species_defs ); }

sub get_ExtURL      {
  my $self = shift;
  my $new_url = $self->ExtURL || return;
  return $new_url->get_url( @_ );
}

sub get_ExtURL_link {
  my $self = shift;
  my $text = shift;
  my $URL = CGI::escapeHTML( $self->get_ExtURL(@_) );
  return $URL ? qq(<a href="$URL">$text</a>) : $text;
}

#use PFETCH etc to get description and sequence of an external record
sub get_ext_seq{
    my ($self, $id, $ext_db) = @_;
    my $indexer = EnsEMBL::Web::ExtIndex->new( $self->species_defs );
    return unless $indexer;
    my $seq_ary;
    my %args;
    $args{'ID'} = $id;
    $args{'DB'} = $ext_db ? $ext_db : 'DEFAULT';

    eval{
	$seq_ary = $indexer->get_seq_by_id(\%args);
    };
    if ( ! $seq_ary) {
	$self->problem( 'fatal', "Unable to fetch sequence",  "The $ext_db server is unavailable $@");
	return;
    }
    else {
	my $list = join " ", @$seq_ary;
	return $list =~ /no match/i ? '' : $list ;
    }
}


1;

