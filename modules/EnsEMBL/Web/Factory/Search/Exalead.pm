package EnsEMBL::Web::Factory::Search::Exalead;

use strict;

use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Proxy::Object;
use ExaLead;
use CGI;
use Data::Dumper;
our @ISA = qw(EnsEMBL::Web::Factory);

sub createObjects {
    use Carp qw(cluck);
    cluck 'in the constructor';
    my $self       = shift;    
    ### Parse parameters to get index names
    my $idx      = $self->param('type') || $self->param('idx') || 'all';
    ### Parse parameters to get Species names
    my $species  = $self->param('species') || $self->species || 'all';
    warn "SEARCHING USING EXALEAD TO FIND $idx in $species";
}

sub generic_search {
    my $self = shift;
}

sub _search_all {
    my $self = shift;
    my $exalead = new ExaLead;
    $exalead->engineURL = $self->species_defs->ENSEMBL_SEARCH_URL; 
    $exalead->__timeout = 30;
    $exalead->rootURL   = "/$ENV{'ENSEMBL_SPECIES'}/search";
    ( my $SPECIES   = $ENV{'ENSEMBL_SPECIES'} ) =~ s/_/ /g;
    my $source = "Top/Source/".$self->species_defs->ENSEMBL_EXALEAD_SITE_INDEX;
    my $q = CGI->new();
    my $not_fresh = $q->param;
    if( $not_fresh ) {
	if( $q->param('q') ) {
	    $q->param('_q',$q->param('q'));
	    my $CAT = '';
	    my $CAT2 = '';
	    if( $q->param('species') && lc($q->param('species')) ne 'all' ) {
		$CAT = "Top/Species/".$q->param('species');
		if ( $q->param('idx') && lc($q->param('idx')) ne 'all' ) {
		    $CAT .= '/'.$q->param('idx');
		    $CAT2 = "Top/Feature type/".$q->param('idx').'/'.$q->param('species');
		}
	    } elsif( $q->param('idx') && lc($q->param('idx')) ne 'all' ) {
		$CAT = "Top/Feature type/".$q->param('idx');
	    }
	    if( $CAT ) {
		$CAT =~ s/_/ /g;
		if( $CAT2 ) {
		    $CAT2 =~ s/_/ /g;
		    $q->param('_q', $q->param('_q').qq( corporate/tree:"$CAT" corporate/tree:"$CAT2" corporate/tree:"$source") );
		} else {
		    $q->param('_q', $q->param('_q').qq( corporate/tree:"$CAT" corporate/tree:"$source"));
		}
	    } else {
		$q->param('_q', $q->param('_q').qq( corporate/tree:"$source"));
	    }
	} elsif( $q->param('_q') ){
	    $q->param('_q', $q->param('_q').qq( corporate/tree:"$source")) unless $q->param('_q') =~/ corporate\/tree:"$source"/;
	}
	$exalead->parse( $q );
    }
    return EnsEMBL::Web::Proxy::Object->new( 'Search', $exalead, $self->__data );
}


1;
