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
    $self->__data->{'news_db'} ||= EnsEMBL::Web::DBSQL::NewsAdaptor->new( $DB );
  } 
  return $self->__data->{'news_db'};
}

sub createObjects { 
  my $self          = shift;
  my $release       = $self->param( 'rel' ) || $self->species_defs->ENSEMBL_VERSION;
  my $id            = $self->param( 'id' ) || $self->param('news_item_id');
  my $edit          = $self->param( 'edit' );
  my $items    = [];
  my $rel_list = [];
  my $spp_list = [];
  my $cat_list = [];
  if ($id) {
    $items = $self->news_adaptor->fetch_by_id( $id );
  } else {
    $items = $self->news_adaptor->fetch_all_by_release( $release );
  }
  $spp_list = $self->news_adaptor->fetch_species_list($release);
  $rel_list = $self->news_adaptor->fetch_release_list;
  $cat_list = $self->news_adaptor->fetch_cat_list;

  $self->DataObjects( new EnsEMBL::Web::Proxy::Object(
    'News', {
      'releases'    => $rel_list,
      'all_spp'     => $spp_list,
      'all_cats'     => $cat_list,
      'items'       => $items,
    }, $self->__data
  ) ); 
}

1;
