package Bio::EnsEMBL::GlyphSet::eponine;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub squish { return 1; }
sub my_label { return "Eponine"; }

sub my_description { return "Eponine transcription<br />&nbsp;start sites"; }

sub my_helplink { return "markers"; }

sub features {
    my ($self) = @_;

    return $self->{'container'}->get_all_SimpleFeatures('Eponine', .8);
}

sub href {
    my ($self, $f ) = @_;
    return undef;
}

sub zmenu {
    my ($self, $f ) = @_;
    
    my $score = $f->score();
    my $start = $f->start() + $self->{'container'}->start() - 1;
    my $end   = $f->end()   + $self->{'container'}->start() - 1;

    return {
        'caption'                                     => 'eponine',
        "01:Score: $score"                            => '',
        "02:bp: $start-$end"                          => ''
    };
}
1;
