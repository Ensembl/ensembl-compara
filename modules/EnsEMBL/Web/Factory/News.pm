package EnsEMBL::Web::Factory::News;

### Factory for creating News objects

use strict;

use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Proxy::Object;
use EnsEMBL::Web::DBSQL::NewsAdaptor;
our @ISA = qw(EnsEMBL::Web::Factory);

sub news_adaptor {
### Creates a NewsAdaptor object for database access
  my $self = shift;
  unless( $self->__data->{'news_db'} ) {
    my $DB = $self->species_defs->databases->{'ENSEMBL_WEBSITE'};
    unless( $DB ) {
      $self->problem( 'Fatal', 'News Database', 'Do not know how to connect to news (website) database');
      return undef;
    }
    $self->__data->{'news_db'} ||= EnsEMBL::Web::DBSQL::NewsAdaptor->new( $DB );
  }
  return $self->__data->{'news_db'};
}


sub createObjects {
### Creates a lightweight Proxy::Object of type News, containing some basic lists
### for use with dropdown menus - actual news items are fetched on the fly
  my $self          = shift;

  ## allow a generic URL for current release
  my $current_release = $self->species_defs->ENSEMBL_VERSION;
  my $release_id      = $self->param( 'rel' ) 
                          || $self->param('release_id')
                          || $current_release;
  if ($release_id eq 'current') {
    $release_id = $current_release;
  }
  elsif ($release_id eq 'all') {
    $release_id = '';
  }

  my $species     = $self->news_adaptor->fetch_species;
  my $categories  = $self->news_adaptor->fetch_cats;
  my $releases    = $self->news_adaptor->fetch_releases;

  $self->DataObjects( new EnsEMBL::Web::Proxy::Object(
    'News', {
      'release_id'  => $release_id,
      'releases'    => $releases,
      'species'     => $species,
      'categories'  => $categories,
    }, $self->__data
  ) ); 
}

1;
