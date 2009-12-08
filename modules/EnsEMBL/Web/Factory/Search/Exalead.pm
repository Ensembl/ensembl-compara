package EnsEMBL::Web::Factory::Search::Exalead;

use strict;

use ExaLead;

use EnsEMBL::Web::Proxy::Object;

use base qw(EnsEMBL::Web::Factory);

sub generic_search {
  my $self = shift;
}

sub _search_all {
  my $self = shift;
  my $idx = shift;
  my $species = shift;
  my $exalead = new ExaLead;
  $exalead->engineURL = $self->species_defs->ENSEMBL_SEARCH_URL;
  $exalead->__timeout = 30;
  $exalead->rootURL   = $self->species_path . '/search';
  ( my $SPECIES   = $self->species ) =~ s/_/ /g;
  my $source = "Top/Source/".$self->species_defs->ENSEMBL_EXALEAD_SITE_INDEX;
  
  my $not_fresh = $self->param;
  if (@$species) {
    $self->param('species',@$species);
  }

  if( $not_fresh ) {
    if( $self->param('q') ) {
      $self->param('_q',$self->param('q'));
      my $CAT = '';
      my $CAT2 = '';
      if( $self->param('species') && lc($self->param('species')) ne 'all' ) {
	$CAT = "Top/Species/".$self->param('species');
	if ( $self->param('idx') && lc($self->param('idx')) ne 'all' ) {
	  $CAT .= '/'.$self->param('idx');
	  $CAT2 = "Top/Feature type/".$self->param('idx').'/'.$self->param('species');
	}
      }
      elsif( $self->param('idx') && lc($self->param('idx')) ne 'all' ) {
	$CAT = "Top/Feature type/".$self->param('idx');
      }
      if( $CAT ) {
	$CAT =~ s/_/ /g;
	if( $CAT2 ) {
	  $CAT2 =~ s/_/ /g;
	  $self->param('_q', $self->param('_q').qq( corporate/tree:"$CAT" corporate/tree:"$CAT2" corporate/tree:"$source") );
	} else {
	  $self->param('_q', $self->param('_q').qq( corporate/tree:"$CAT" corporate/tree:"$source"));
	}
      }
      else {
	$self->param('_q', $self->param('_q').qq( corporate/tree:"$source"));
      }
    } elsif( $self->param('_q') ){
      $self->param('_q', $self->param('_q').qq( corporate/tree:"$source")) unless $self->param('_q') =~/ corporate\/tree:"$source"/;
    }
    $exalead->parse( $self->{'data'}{'_input'} );
  }
  
  if ($exalead->__error || $exalead->__status eq 'failure') {
    $self->problem( 'Fatal',
        'Search Engine Error',
        $self->_help("Sorry, the search engine failed, or found too many results. Please try another search.") );
    warn '!!! EXALEAD FAILURE: '.$exalead->__error;
    return ;
  }
  
  return EnsEMBL::Web::Proxy::Object->new( 'Search', $exalead, $self->__data );
}


1;
