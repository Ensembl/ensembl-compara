# $Id$

package EnsEMBL::Web::Controller::Ajax;

### Provides JSON results for autocomplete dropdown in location navigation bar

use strict;

use EnsEMBL::Web::DBSQL::WebsiteAdaptor;
use EnsEMBL::Web::Hub;

use base qw(EnsEMBL::Web::Controller);

sub new {
  my $class = shift;
  my $r     = shift || Apache2::RequestUtil->can('request') ? Apache2::RequestUtil->request : undef;
  my $args  = shift || {};
  my $self  = {};
  
  my $hub = new EnsEMBL::Web::Hub({
    apache_handle  => $r,
    session_cookie => $args->{'session_cookie'},
    user_cookie    => $args->{'user_cookie'},
  });
  
  my $func = $hub->action;
  
  bless $self, $class;
  
  $self->$func($hub) if $self->can($func);
  
  return $self;
}

sub autocomplete {
  my ($self, $hub) = @_;
  my $cache   = $hub->cache;
  my $species = $hub->species;
  my $query   = $hub->param('q');
  my ($key, $results);
  
  if ($cache) {
    $key     = sprintf '::AUTOCOMPLETE::GENE::%s::%s::', $hub->species, $query;
    $results = $cache->get($key);
  }
  
  if (!$results) {
    my $dbh = new EnsEMBL::Web::DBSQL::WebsiteAdaptor($hub)->db;
    my $sth = $dbh->prepare(sprintf 'select display_label, stable_id, db from gene_autocomplete where species = "%s" and display_label like %s', $species, $dbh->quote("$query%"));
    
    $sth->execute;
    
    $results = $sth->fetchall_arrayref;
    $cache->set($key, $results, undef, 'AUTOCOMPLETE') if $cache;
  }
  
  print $self->jsonify($results);
}

sub track_order {
  my ($self, $hub) = @_;
  my $image_config = $hub->get_imageconfig($hub->param('image_config'));
  my $species      = $image_config->species;
  my $node         = $image_config->get_node('track_order');
  
  $node->set_user($species, { %{$node->get($species) || {}}, $hub->param('track') => $hub->param('order') });
  $image_config->altered = 1;
  $hub->session->store;
}

sub multi_species {
  my ($self, $hub) = @_;
  my %species = map { $_ => $hub->param($_) } $hub->param;
  my %args    = ( type => 'multi_species', code => 'multi_species' );
  my $session = $hub->session;
  
  if (scalar keys %species) {
    $session->set_data(%args, $hub->species => \%species);
  } else {
    my %data = %{$session->get_data(%args)};
    delete $data{$hub->species};
    
    $session->purge_data(%args);
    $session->set_data(%args, %data) if scalar grep $_ !~ /(type|code)/, keys %data;
  }
}

1;
