package EnsEMBL::Web::Proxiable;

### NAME: Proxiable.pm
### Base class for data objects and factories

### PLUGGABLE: No - but part of Proxy plugin infrastructure

### STATUS: At Risk
### * duplicates Resource/Hub functionality 
### * multiple methods of plugin-handling are confusing!

### DESCRIPTION
### A Proxiable object contains both the data object (either
### an Object or a Factory) and all the 'connections' (db handles, 
### cgi parameters, web session, etc) needed to support 
### manipulation of that data

use strict;
use warnings;
no warnings 'uninitialized';

use URI::Escape qw(uri_escape);

use EnsEMBL::Web::DBSQL::DBConnection;
use EnsEMBL::Web::ExtURL;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Problem;

use base qw(EnsEMBL::Web::Root);

sub new {
  my ($class, $data) = @_;
  
  $data->{'_type'}     ||= $ENV{'ENSEMBL_TYPE'};
  $data->{'_action'}   ||= $ENV{'ENSEMBL_ACTION'};
  $data->{'_function'} ||= $ENV{'ENSEMBL_FUNCTION'}; 
  $data->{'_species'}  ||= $ENV{'ENSEMBL_SPECIES'};
  $data->{'timer'}     ||= $ENSEMBL_WEB_REGISTRY->timer;

  my $self = { data => $data };
  bless $self, $class;
  return $self; 
}

sub __data            { return $_[0]->{'data'}; }
sub __objecttype      { return $_[0]->{'data'}{'_objecttype'}; }
sub referer           { return $_[0]->hub->referer; }
sub apache_handle     { return $_[0]->{'data'}{'_apache_handle'}; }
sub hub               { return $_[0]->{'data'}{'_hub'}; }
sub type              { return $_[0]->{'data'}{'_type'}; }
sub action            { return $_[0]->{'data'}{'_action'};  }
sub function          { return $_[0]->{'data'}{'_function'};  }
sub script            { return $_[0]->{'data'}{'_script'};  }
sub species           { return $_[0]->{'data'}{'_species'}; }
sub species_defs      { return $_[0]->{'data'}{'_species_defs'} ||= $ENSEMBL_WEB_REGISTRY->species_defs; }
sub DBConnection      { return $_[0]->{'data'}{'_databases'}    ||= new EnsEMBL::Web::DBSQL::DBConnection($_[0]->species, $_[0]->species_defs); }
sub ExtURL            { return $_[0]->{'data'}{'_ext_url_'}     ||= new EnsEMBL::Web::ExtURL($_[0]->species, $_[0]->species_defs); } # Handling ExtURLs
sub session           { return $_[0]->{'session'} ||= $ENSEMBL_WEB_REGISTRY->get_session; }
sub get_session       { return $_[0]->{'session'} ||  $ENSEMBL_WEB_REGISTRY->get_session; }
sub user              { return defined $_[0]->{'user'} ? $_[0]->{'user'} : ($_[0]->{'user'} = $ENSEMBL_WEB_REGISTRY->get_user || 0); }
sub delete_param      { my $self = shift; $self->{'data'}{'_input'}->delete(@_); }
sub get_databases     { my $self = shift; $self->DBConnection->get_databases(@_); }
sub databases_species { my $self = shift; $self->DBConnection->get_databases_species(@_); }
sub species_path      { my $self = shift; $self->species_defs->species_path(@_); }

sub table_info {
  my $self = shift;
  return $self->species_defs->table_info( @_ );
}

sub _url { return shift->hub->url(@_); }  #same as the _url in hub

sub timer_push {
  my $self = shift;
  
  return unless ref $self->{'data'}{'timer'} eq 'EnsEMBL::Web::Timer';
  return $self->{'data'}{'timer'}->push(@_);
}

sub input { 
  my $self = shift;
  $self->{'data'}{'_input'} = shift if @_;
  return $self->{'data'}{'_input'};
}

sub _sanitize {
  my $T = shift;
  $T =~ s/<script(.*?)>/[script$1]/igsm;
  $T =~ s/\s+on(\w+)\s*=/ on_$1=/igsm;
  return $T;
}

# Does an ordinary redirect
sub redirect {
  my ($self, $url) = @_;
  $self->{'data'}{'_input'}->redirect($url);
}

sub param {
  my $self = shift;
  
  if (@_) { 
    my @T = map { _sanitize($_) } $self->{'data'}{'_input'}->param(@_);
    return wantarray ? @T : $T[0] if @T;
    my $view_config = $self->viewconfig;
    
    if ($view_config) {
      $view_config->set(@_) if @_ > 1;
      my @val = $view_config->get(@_);
      return wantarray ? @val : $val[0];
    }
    
    return wantarray ? () : undef;
  } else {
    my @params = map { _sanitize($_) } $self->{'data'}{'_input'}->param;
    my $view_config = $self->viewconfig;
    push @params, $view_config->options if $view_config;
    my %params = map { $_, 1 } @params; # Remove duplicates
    
    return keys %params;
  }
}

sub input_param  {
  my $self = shift;
  return _sanitize($self->{'data'}{'_input'}->param(@_));
}

sub multi_params {
  my $self = shift;
  my $realign = shift;
  
  my $input = $self->{'data'}{'_input'};
  
  my %params = defined $realign ? 
    map { $_ => $input->param($_) } grep { $realign ? /^([srg]\d*|pop\d+|align)$/ && !/^[rg]$realign$/ : /^(s\d+|r|pop\d+|align)$/ && $input->param($_) } $input->param :
    map { $_ => $input->param($_) } grep { /^([srg]\d*|pop\d+|align)$/ && $input->param($_) } $input->param;
  
  return \%params;
}

# Determines the species for userdata pages (mandatory, since userdata databases are species-specific)
sub data_species {
  my $self = shift;
  my $species = $self->species;
  $species = $self->species_defs->ENSEMBL_PRIMARY_SPECIES if !$species || $species eq 'common';
  return $species;
}

sub database {
  my $self = shift;
  
  if ($_[0] =~ /compara/) {
    return Bio::EnsEMBL::Registry->get_DBAdaptor('multi', $_[0]);
  } else {
    return $self->DBConnection->get_DBAdaptor(@_);
  }
}

sub get_imageconfig  {
  my $self = shift;
  return $self->hub->get_imageconfig(@_);
}

sub get_ExtURL {
  my $self = shift;
  my $new_url = $self->ExtURL || return;
  return $new_url->get_url(@_);
}

sub get_ExtURL_link {
  my $self = shift;
  my $text = shift;
  my $url = $self->get_ExtURL(@_);
  return $url ? qq(<a href="$url">$text</a>) : $text;
}

1;

