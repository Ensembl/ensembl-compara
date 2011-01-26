package EnsEMBL::Web::Factory::Search::EBeye;

use strict;

use EnsEMBL::Web::Factory;
use EBeyeSearch;
use CGI;
use Data::Dumper;
use Carp qw(cluck);

our @ISA = qw(EnsEMBL::Web::Factory);

sub generic_search {
    my $self = shift;
}

sub _search_all {
    my $self = shift;
    my $idx = shift;
    my $species = shift;
     my $ebeye = new EBeyeSearch({__hub => $self->hub});

     ( my $SPECIES   = $ENV{'ENSEMBL_SPECIES'} ) =~ s/_/ /g;
     my $q = CGI->new();
     if (@$species) {
 	$q->param('species',@$species);
     }

    eval {$ebeye->parse( $q );}; if ($@){ $self->problem( 'fatal', 'Search Engine Error', "There is a problem with the Search engine." )  ; return undef;};


    return $self->new_object( 'Search', $ebeye, $self->__data );

}


1;
