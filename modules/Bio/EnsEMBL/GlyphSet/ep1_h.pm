package Bio::EnsEMBL::GlyphSet::ep1_h;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub squish { return 1; }
sub my_label { return "Ecore (Human)"; }

sub my_description { return "IPI Human proteins<br />&nbsp;compared with Exofish"; }

sub my_helplink { return "markers"; }

sub features {
    my ($self) = @_;

    return $self->{'container'}->get_all_SimpleFeatures('ep1_h', 0);
}

sub href {
    my ($self, $f ) = @_;
    return $self->ID_URL( 'TETRAODON_ECORE', $f->display_id );
}

sub zmenu {
    my ($self, $f ) = @_;
    
    my $score = $f->score();
my ($start,$end) = $self->slice2sr( $f->start, $f->end );

    return {
        'caption'                                     => 'Ecore (Human proteins)',
        $f->display_id,                                       => $self->href($f),
        "01:Score: $score"                            => '',
        "02:bp: $start-$end"                          => ''
    };
}
1;
