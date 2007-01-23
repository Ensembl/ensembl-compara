package EnsEMBL::Web::Factory::News;

### Factory for creating News objects

use strict;

use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Proxy::Object;
our @ISA = qw(EnsEMBL::Web::Factory);

sub createObjects {
### Creates a lightweight Proxy::Object of type News, containing some basic lists
### for use with dropdown menus - actual news items are fetched on the fly
  my $self          = shift;

  my $adaptor = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->newsAdaptor;

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

  my $species     = $adaptor->fetch_species;
  my $categories  = $adaptor->fetch_cats;
  my $releases    = $adaptor->fetch_releases;

  $self->DataObjects( new EnsEMBL::Web::Proxy::Object(
    'News', {
      'adaptor'     => $adaptor,
      'release_id'  => $release_id,
      'releases'    => $releases,
      'species'     => $species,
      'categories'  => $categories,
    }, $self->__data
  ) ); 
}

1;
