package EnsEMBL::Web::Factory::News;

use strict;

use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Proxy::Object;
use EnsEMBL::Web::DBSQL::NewsAdaptor;
our @ISA = qw(EnsEMBL::Web::Factory);

sub news_adaptor {
  my $self = shift;
  unless( $self->__data->{'news_db'} ) {
    my $DB = $self->species_defs->databases->{'ENSEMBL_WEBSITE'};
    unless( $DB ) {
      $self->problem( 'Fatal', 'News Database', 'Do not know how to connect to news (website) database');
      return undef;
    }
    $self->__data->{'news_db'} ||= EnsEMBL::Web::DBSQL::NewsAdaptor->new( $DB );  }
  return $self->__data->{'news_db'};
}


sub createObjects { 
  my $self          = shift;

  my $items    = [];
  my $all_spp = {};
  my $valid_spp = {};
  my $all_cats = [];
  my $all_rels = [];

  my $release_id       = $self->param( 'rel' ) || $self->param('release_id') || $self->species_defs->ENSEMBL_VERSION;
  my $id            = $self->param( 'id' ) || $self->param('news_item_id');

  # object always contains these handy lookups!
  $all_spp = $self->news_adaptor->fetch_species_list;
  $all_cats = $self->news_adaptor->fetch_cat_list;
  $all_rels = $self->news_adaptor->fetch_release_list;

  # because this object can be updated through the website, news items may
  # need to be generated either from the database or from the form parameters
  if ($self->param('update')) { # create news item hash from form

    my @sp_array = ($self->param('species')); # force 'species' parameter into an array
    my $form_item = {
        'news_item_id' => $self->param('news_item_id'),
        'release_id' => $self->param('release_id'),
        'title' => $self->param('title'),
        'content' => $self->param('content'),
        'news_cat_id' => $self->param('news_cat_id'),
        'priority' => $self->param('priority'),
        'species' => \@sp_array,
        };
    push @$items, $form_item;
  }
  else { # look up from database
    if ($id && $self->param('action') ne 'saved') { # check we're not redirecting from a database save
        $items = $self->news_adaptor->fetch_by_id( $id );
    } else {
        $items = $self->news_adaptor->fetch_all_by_release( $release_id );
    }
  }
  # object also contains a list of the valid species for the chosen release
  $valid_spp = $self->news_adaptor->fetch_species_list($release_id);

  $self->DataObjects( new EnsEMBL::Web::Proxy::Object(
    'News', {
      'releases'    => $all_rels,
      'all_spp'     => $all_spp,
      'valid_spp'     => $valid_spp,
      'all_cats'     => $all_cats,
      'items'       => $items,
    }, $self->__data
  ) ); 
}

1;
