# $Id$

package EnsEMBL::Web::Controller::AutoComplete;

### Provides JSON results for autocomplete dropdown in location navigation bar

use strict;

use EnsEMBL::Web::DBSQL::WebsiteAdaptor;
use EnsEMBL::Web::Hub;

use base qw(EnsEMBL::Web::Controller);

sub new {
  my $class = shift;
  my $self  = {};
  
  bless $self, $class;
  
  my $hub = new EnsEMBL::Web::Hub;
  my $dbh = new EnsEMBL::Web::DBSQL::WebsiteAdaptor($hub)->db;
  my $q   = $hub->param('q');
  my $all = 1;
  my $sth = $dbh->prepare(sprintf 'select display_label, stable_id, db from gene_autocomplete where species = "%s" and display_label like %s', $hub->species, $dbh->quote("$q%"));
  
  $sth->execute;
  
  my $results = $sth->fetchall_arrayref;
  
  if (scalar @$results > 10) {
    splice @$results, 10;
    $all = 0;
  }
  
  print $self->jsonify({ results => $results, all => $all });
  
  return $self;
}

1;
