package EnsEMBL::Web::Factory::News;

### Factory for creating News objects

use strict;

use EnsEMBL::Web::Data::Species;
use EnsEMBL::Web::Data::Release;

use base qw(EnsEMBL::Web::Factory);

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

  my %species    = map { $_->id => $_->name } EnsEMBL::Web::Data::Species->search({}, {order_by => 'name'});
  my @categories = EnsEMBL::Web::Data::NewsCategory->search({}, {order_by => 'priority'});
  my @releases   = EnsEMBL::Web::Data::Release->search({}, { order_by => 'release_id DESC' });

  $self->DataObjects($self->new_object(
    'News', {
      'release_id'  => $release_id,
      'releases'    => \@releases,
      'species'     => \%species,
      'categories'  => \@categories,
    }, $self->__data
  ) ); 
}

1;
