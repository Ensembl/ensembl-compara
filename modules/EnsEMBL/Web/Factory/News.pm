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

## identify which item and/or release we're talking about
  my $id              = $self->param( 'id' ) || $self->param('news_item_id');
  my $current_release = $self->species_defs->ENSEMBL_VERSION;
  my $release_id      = $self->param( 'rel' ) || $self->param('release_id') 
                          || $current_release;

  ## also allow a generic URL for current release
  if ($release_id eq 'current') {
    $release_id = $current_release;
  }
  $release_id = '' if $release_id eq 'all';

## create some handy lookups
  my $current_spp = $self->news_adaptor->fetch_species($current_release);
  my $all_spp = $self->news_adaptor->fetch_species;
  my $all_cats = $self->news_adaptor->fetch_cats;
  my $all_rels = $self->news_adaptor->fetch_releases;

## prepare configuration for db query
  my %where = ();
  if ($self->param('news_cat_id')) {
    $where{'category'} = $self->param('news_cat_id');    
  }
  if ($release_id) {
    $where{'release'} = $release_id;    
  }

## create generic news item objects from the database
  warn "Fetching generic news";  
  my $generic_items = $self->news_adaptor->fetch_news_items(\%where, 1);

## sort out array of chosen species
  my @sp_array = ();
  if ($self->param('species')) {
    @sp_array = ($self->param('species'));
  }
  else { ## create based on name of directory
    my $sp_dir = $self->species;
    if ($sp_dir eq 'Multi') { ## make array of all species ids
      @sp_array = sort {$a <=> $b} keys %$all_spp;
    }
    else { ## look up species id from directory name
      my %rev_hash = reverse %$all_spp;
      @sp_array = ($rev_hash{$sp_dir});
    }
  }

## get valid releases    
  my $valid_rels = [];
  my $species_items = [];
  if (scalar(@sp_array) == 1 && $sp_array[0]) { ## single species
    $where{'species'} = $sp_array[0];    
    $valid_rels = $self->news_adaptor->fetch_releases({'species'=>$sp_array[0]});
  }
  else { ## in multi-species mode, all releases are valid
    $valid_rels = $self->news_adaptor->fetch_releases;
  }
        
## get valid species for the chosen release
  my $valid_spp = $self->news_adaptor->fetch_species($release_id);

## get species-specific news
  warn "Fetching species news";  
  my $species_items = $self->news_adaptor->fetch_news_items(\%where);
  
  $self->DataObjects( new EnsEMBL::Web::Proxy::Object(
    'News', {
      'releases'    => $all_rels,
      'valid_rels'  => $valid_rels,
      'all_spp'     => $all_spp,
      'valid_spp'   => $valid_spp,
      'current_spp' => $current_spp,
      'all_cats'    => $all_cats,
      'generic_items' => $generic_items,
      'species_items' => $species_items,
    }, $self->__data
  ) ); 
}

1;
