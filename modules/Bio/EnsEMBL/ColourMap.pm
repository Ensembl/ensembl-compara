package Bio::EnsEMBL::ColourMap;
use strict;
use Sanger::Graphics::ColourMap;
use EnsWeb;
use vars qw(@ISA);
@ISA = qw(Sanger::Graphics::ColourMap);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new( @_ );
    while(my($k,$v) = each %{$EnsWeb::species_defs->ENSEMBL_COLOURS} ) {
	$self->{$k} = $v;
    }
    return $self;
}

1;
