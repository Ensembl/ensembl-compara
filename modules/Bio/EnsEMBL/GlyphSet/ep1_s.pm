package Bio::EnsEMBL::GlyphSet::ep1_s;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub squish { return 1; }
sub my_label { return "Ecore (Mouse)"; }

sub my_description { return "IPI Mouse proteins<br />&nbsp;compared with Exofish"; }

sub my_helplink { return "markers"; }

sub features {
    my ($self) = @_;

    return $self->{'container'}->get_all_SimpleFeatures('ep1_s', 0);
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
        'caption'                                     => 'Ecore (Mouse proteins)',
        $f->display_id,                                       => $self->href($f),
        "01:Score: $score"                            => '',
        "02:bp: $start-$end"                          => ''
    };
}
1;
