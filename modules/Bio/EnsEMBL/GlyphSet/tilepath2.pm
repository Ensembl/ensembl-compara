package Bio::EnsEMBL::GlyphSet::tilepath2;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet::bac_map;
@ISA = qw(Bio::EnsEMBL::GlyphSet::bac_map);

sub my_label { return "Acc clones"; }

## Retrieve all tile path clones - these are the clones in the
## subset "tilepath".

sub features {
    my ($self) = @_;
    my $container_length = $self->{'container'}->length();
    return $self->{'container'}->get_all_MiscFeatures( 'acc_bac_map' );
}

## If tile path clones are very long then we draw them as "outlines" as
## we aren't convinced on their quality...

sub colour {
    my ($self, $f ) = @_;
    $self->{'_colour_flag'} = $self->{'_colour_flag'}==1 ? 2 : 1;
    $f->{'_colour_flag'} = $self->{'colours'}{"col$self->{'_colour_flag'}"};
    return 
        $f->{'_colour_flag'},
        $self->{'colours'}{"lab$self->{'_colour_flag'}"},
        'border';
}

1;
