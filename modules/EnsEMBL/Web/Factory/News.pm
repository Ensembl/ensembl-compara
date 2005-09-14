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
  my $current_spp = {};
  my $all_cats = [];
  my $all_rels = [];
  my $valid_rels = [];

  my $current_release =  $self->species_defs->ENSEMBL_VERSION;
  my $release_id       = $self->param( 'rel' ) || $self->param('release_id') || $current_release;

  my $id            = $self->param( 'id' ) || $self->param('news_item_id');

  # object always contains these handy lookups!
  $current_spp = $self->news_adaptor->fetch_species($current_release);
  $all_spp = $self->news_adaptor->fetch_species;
  $all_cats = $self->news_adaptor->fetch_cats;
  $all_rels = $self->news_adaptor->fetch_releases;

  # if no species chosen, set default to current directory
  my @sp_array = ();
  if ($self->param('species')) {
    @sp_array = ($self->param('species'));
  }
  elsif ($self->script ne 'newsdbview') { # hack - must be a better way!
    my $sp_name = $self->species;
    if ($sp_name eq 'Multi') {
        @sp_array = sort { $a <=> $b } keys %$all_spp;
    }
    else {
        my %rev_hash = reverse %$all_spp;
        my $sp_id = $rev_hash{$sp_name};
        @sp_array = ($sp_id);
    }
  }

  # because this object can be updated through the website, news items may
  # need to be generated either from the database or from the form parameters
  if ($self->param('update')) { # create news item hash from form

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
    my %criteria = ();
    my @order_by = ('cat_desc');
    if ($id && $self->param('action') ne 'saved') { # check we're not redirecting from a database save
        %criteria = ('item_id'=>$id);    
    }
    else {
        if ($release_id eq 'all') {
            @order_by = ('release', 'cat_desc');
        }
        else { 
            $criteria{'release'} = $release_id;
        }    
        if (scalar(@sp_array) == 1 && $sp_array[0]) {
            $criteria{'species'} = $sp_array[0];    
            # get valid releases for the chosen species
            $valid_rels = $self->news_adaptor->fetch_releases($sp_array[0]);
        }
        else {
            # in multi-species mode, all releases are valid
            $valid_rels = $self->news_adaptor->fetch_releases;
            if ($self->script ne 'newsdbview') {
                push @order_by, 'species';
            }
        }
        if ($self->param('news_cat_id')) {
            $criteria{'category'} = $self->param('news_cat_id');    
        }
    }
    my %options = ('criteria'=>\%criteria, 'order_by'=>\@order_by);
    $items = $self->news_adaptor->fetch_items(\%options);
  }
  # object also contains a list of the valid species for the chosen release
  $valid_spp = $self->news_adaptor->fetch_species($release_id);

  $self->DataObjects( new EnsEMBL::Web::Proxy::Object(
    'News', {
      'releases'    => $all_rels,
      'valid_rels'  => $valid_rels,
      'all_spp'     => $all_spp,
      'valid_spp'   => $valid_spp,
      'current_spp' => $current_spp,
      'all_cats'    => $all_cats,
      'items'       => $items,
    }, $self->__data
  ) ); 
}

1;
