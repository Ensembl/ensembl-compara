package EnsEMBL::Web::Factory::Help;

use strict;

use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Proxy::Object;
use EnsEMBL::Web::DBSQL::HelpAdaptor;
our @ISA = qw(EnsEMBL::Web::Factory);

sub help_adaptor {
  my $self = shift;
  unless( $self->__data->{'help_db'} ) {
    my $DB = $self->species_defs->databases->{'ENSEMBL_WEBSITE'};
    unless( $DB ) {
      $self->problem( 'Fatal', 'Help Database', 'Do not know how to connect to help database');
      return undef;
    }
    $self->__data->{'help_db'} ||= EnsEMBL::Web::DBSQL::HelpAdaptor->new( $DB );
  } 
  return $self->__data->{'help_db'};
}

sub createObjects { 
  my $self        = shift;
  my $keywords    = $self->param( 'kw' );
  my $ids         = $self->param( 'ids' );
  my $movie_id    = $self->param( 'movie' );

  my $results    = [];
  my $index = [];

  ## we only want live entries for the public pages
  my $status = $self->script =~ /view$|Online/ ? 'live' : '';

  ## Help schema switch
  my $modular = $self->species_defs->ENSEMBL_MODULAR_HELP;
  my ($method_se, $method_kw, $method_id, $index);

  if ($modular) {
    $method_se = 'fetch_article_by_keyword';
    $method_kw = 'fetch_scores_by_string';
    $method_id = 'fetch_summaries_by_scores';
    $index     = 'fetch_article_index';
  }
  else {
    $method_se = 'fetch_all_by_keyword';
    $method_kw = 'fetch_all_by_string';
    $method_id = 'fetch_all_by_scores';
    $index     = 'fetch_index_list';
  }

  ## get list of help articles by appropriate method
  if( $self->param('se') ) {
    $results = $self->help_adaptor->$method_se( $keywords );
  } 
  elsif ($self->param('kw')) {
    $results = $self->help_adaptor->$method_kw( $keywords );
  }
  elsif ( $self->param('results')) {
    ## messy, but makes sure we get the results in order!
    my $ids = [];
    my @articles = split('_', $self->param('results'));
    foreach my $article (@articles) {
      my @bits = split('-', $article);
      push(@$ids, {'id'=>$bits[0], 'score'=>$bits[1]});
    }
    $results = $self->help_adaptor->$method_id( $ids );
  }
  $index = $self->help_adaptor->$index($status);
  my $glossary    = $self->help_adaptor->fetch_glossary($status);

  ## get Flash movie info; 
  my ($movie, $movie_list);  
  if ($movie_id) {
    $movie = $self->help_adaptor->fetch_movie_by_id($movie_id);
  }
  else {
    $movie_list = $self->help_adaptor->fetch_movies($status);
  }

  $self->DataObjects( new EnsEMBL::Web::Proxy::Object(
    'Help', {
      'results'     => $results,
      'index'       => $index,
      'glossary'    => $glossary,
      'movie_list'  => $movie_list,
      'movie'       => $movie,
    }, $self->__data
  ) ); 
}

1;
