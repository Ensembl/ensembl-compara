package EnsEMBL::Web::PureHub;

use strict;
use warnings;

=text

PureHub is a hub which can only be used for database and speciesdefs
access and which contains no state from the surrounding request. It
wraps DBHub, but insists that contextual state, such as species, is
always explicitly passed on each call. Sometimes this requirement means
that there isnt an exact 1-to-1 match between the APIs, but processing
is kept to the minimum.

PureHub is used in Query and for parts of code which can be made into
queries, so that the results can be built during the precache stage.

Obviously, don't access the contained _hub.

=cut

use Carp;
use EnsEMBL::Web::DBSQL::DBConnection;

sub new {
  my ($proto,$hub) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    _hub => $hub
  };
  bless $self,$class;
  return $self;
}

sub sd { return $_[0]->{'_hub'}->species_defs; }

sub get_config {
  my ($self,$species,$var) = @_;

  croak "Must specify species" unless $species;
  return $self->sd->get_config($species,$var);
}

sub multi_val {
  my ($self,$species,$type) = @_;

  croak "Must specify species" unless $species;
  return $self->sd->multi_val($species,$type);
}

sub databases {
  my ($self,$species) = @_;

  croak "Must specify species" unless $species;
  my @dbs = (keys %{$self->get_config($species,'databases')||{}},
             @{$self->multi_val($species,'compara_like_databases')||[]});
  return { map { $_ => 1 } @dbs };
}

sub database {
  my ($self,$species,$db) = @_;

  $db ||= 'core';
  if($db =~ /compara/ && !$self->sd->SINGLE_SPECIES_COMPARA) {
    $species = 'multi';
  }
  croak "No species specified getting '$db'" unless $species;
  my $dbc = EnsEMBL::Web::DBSQL::DBConnection->new($species,$self->sd);
  if($db eq 'go') {
    return $dbc->get_databases_species($species,'go')->{'go'};
  }
  return $dbc->get_DBAdaptor($db,$species);
}

sub get_adaptor {
  my ($self,$species,$db,$method) = @_;

  my $dba = $self->database($species,$db);
  return undef unless defined $dba;
  return $dba->$method();
}

sub get_query {
  my $self = shift;

  return $self->{'_hub'}->get_query(@_);
}

1;
