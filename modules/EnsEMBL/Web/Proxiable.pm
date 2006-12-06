package EnsEMBL::Web::Proxiable;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Apache::Handlers;
use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::User;
use EnsEMBL::Web::ExtURL;
use EnsEMBL::Web::UserConfigAdaptor;
use EnsEMBL::Web::ScriptConfigAdaptor;
use EnsEMBL::Web::Document::DropDown::MenuContainer;
use EnsEMBL::Web::Root;
use EnsEMBL::Web::DBSQL::DBConnection;
use EnsEMBL::Web::DBSQL::UserDB;

our @ISA = qw( EnsEMBL::Web::Root );

sub new {
  my( $class, $data ) = @_;
  my $self = { 'data' => $data };
  bless $self, $class;
  return $self; 
}

sub __data { return $_[0]{'data'}; }
sub input { 
  my $self = shift;
  $self->{'data'}{'_input'} = shift if @_;
  return $self->{'data'}{'_input'};
}

sub param {
  my $self = shift;
  if( @_ ){ 
    my @T = $self->{'data'}{'_input'}->param(@_);
    if( @T ) {
      return wantarray ? @T : $T[0];
    }
    my $wsc = $self->get_scriptconfig( );
    if( $wsc ) {
      if( @_ > 1 ) { $wsc->set(@_); }
      my $val = $wsc->get(@_);
      my @val = ref($val) eq 'ARRAY' ? @$val : ($val);
      return wantarray ? @val : $val[0];
    }
    return wantarray ? () : undef;
  } else {
    my @params = $self->{'data'}{'_input'}->param();
    my $wsc    = $self->get_scriptconfig( );
    push @params, $wsc->options() if $wsc;
    my %params = map { $_,1 } @params;
    return keys %params;
  }
}

sub input_param  { my $self = shift; return $self->{'data'}{'_input'}->param(@_); }
sub delete_param { my $self = shift; $self->{'data'}{'_input'}->delete(@_); }
sub script       { return $_[0]{'data'}{'_script'}; }
sub species      { return $_[0]{'data'}{'_species'}; }

sub fix_session {
### Fix the session back to the database - if a session object has been created
### calls store on... this will check whether (a) there are any saveable
### scriptconfigs AND (b) if any of the saveable scriptconfigs have been altered
  my( $self, $r ) = @_;
warn "FIX SESSION...............................";
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
sub database {      my $self = shift; $self->DBConnection->get_DBAdaptor( @_ ); }
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

sub user { $_[0]{'data'}{'_user'}         ||= EnsEMBL::Web::User->new(); }
sub species_defs    { $_[0]{'data'}{'_species_defs'} ||= EnsEMBL::Web::SpeciesDefs->new(); }
sub web_user_db { $_[0]{'data'}{'_web_user_db'}  ||= EnsEMBL::Web::DBSQL::UserDB->new( $_[0]->apache_handle ); }
sub apache_handle { $_[0]{'data'}{'_apache_handle'}; }

sub get_userconfig  {
### Returns the named (or one based on script) {{EnsEMBL::Web::UserConfig}} object
  my( $self, $key ) = @_;
  my $session = $self->get_session || return;
warn "JS5 GUC $key";
  return $session->getImageConfig( $key ); ## No second parameter - this isn't cached!!
}

sub user_config_hash {
### Retuns a copy of the script config stored in the database with the given key
  my $self = shift;
  my $key  = shift;
  my $type = shift || $key;
  my $session = $self->get_session;
warn "JS5 UCH $key $type";
  return $session ? $session->getImageConfig( $type, $key ) : undef; ## {'user_configs'}{$key} ||= $self->get_userconfig( $type );
}

sub get_scriptconfig {
### Returns the named (or one based on script) {{EnsEMBL::Web::ScriptConfig}} object
  my( $self, $key ) = @_;
  $key = $self->script unless defined $key;
  my $session = $self->get_session;
  return $session ? $session->getScriptConfig( $key ) : undef;
}

sub attach_image_config {
  my( $self, $key, $image_key ) = @_;
  my $session = $self->get_session;
  return $session ? $session->attachImageConfig( $key, $image_key ) : undef;
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
  my $URL = $self->get_ExtURL(@_);
  return $URL ? qq(<a href="$URL">$text</a>) : $text;
}

sub new_menu_container {
  my($self, %params ) = @_;

#  foreach my $p (sort keys %params) {
#      warn ("$p => $params{$p}");
#  }

  my %N = (
    'species'      => $self->species,
    'script'       => $self->script,
    'scriptconfig' => $self->get_scriptconfig,
    'width'        => $self->param('image_width'),
    'object'       => $self
  );

  $N{'location'} = $self->location if $self->can('location');
  $N{'panel'}    = $params{'panel'}    || $params{'configname'} || $N{'script'};
  $N{'fields'}   = $params{'fields'}   || ( $self->can('generate_query_hash') ? $self->generate_query_hash : {} );
  if( $params{'configname'} ) {
    warn ".. $params{'configname'}";
    $N{'config'}   = $self->user_config_hash( $params{'configname'} );
    $N{'config'}->set_species( $self->species );
  }
  $N{'configs'}  = $params{'configs'};

  my $mc = EnsEMBL::Web::Document::DropDown::MenuContainer->new(%N);

  foreach( @{$params{'leftmenus'} ||[]} ) { $mc->add_left_menu( $_); }
  foreach( @{$params{'rightmenus'}||[]} ) { $mc->add_right_menu($_); }
  $mc->{'config'}->{'missing_tracks'} = $mc->{'missing_tracks'};
  return $mc;
}

1;

