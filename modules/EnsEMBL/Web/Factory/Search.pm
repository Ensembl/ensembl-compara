package EnsEMBL::Web::Factory::Search;

use strict;

use EnsEMBL::Web::Proxy::Factory;
use EnsEMBL::Web::Proxy::Object;
use base qw(EnsEMBL::Web::Factory);

use Data::Dumper;
$Data::Dumper::Maxdepth = 2;

sub createObjects { 
  my $self       = shift;
  my $indexer  = $self->species_defs->ENSEMBL_TEXT_INDEXER || 'Exalead';

  ### Parse parameters to get index names
  my $idx      = $self->param('type') || $self->param('idx') || 'all';

  ### Parse parameters to get Species names
  my @species  = $self->param('species') || $self->species;
     @species  = @{$self->species_defs->ENSEMBL_SPECIES} if $species[0] =~ /^all$/i ;
  my $real_factory = EnsEMBL::Web::Proxy::Factory->new( "Search::$indexer", $self->__data );
  $self->__data->{'factory'}  = $real_factory;
  if( $real_factory->can( 'generic_search' ) ) {
    $self->DataObjects( $real_factory->_search_all( $idx, \@species ) );
  } else {
    my $method = "search_".uc( $idx );
    if( $real_factory->can( $method ) ) {
      foreach( @species ) {
        $self->DataObjects( $real_factory->$method( [$_] ) );  
      }
    } elsif( $real_factory->can( '_search_species' ) ) {
      foreach( @species ) {
        $self->DataObjects( $real_factory->_search_species( [$_] ) );  
      }
    } else {
      $self->problem( 'fatal', qq(Do not know how to search the index "$idx"),
        qq(I do not recognise the type of feature you are searching for.)
      );
    }
  }
}

1;
