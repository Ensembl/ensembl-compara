package Bio::EnsEMBL::GlyphSet::trna;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "tRNAs"; }

sub squish { 1; }
sub features {
  my ($self) = @_;
  return 
    $self->{'container'}->get_all_SimpleFeatures('tRNAscan',25);
}

sub href {
    my ($self, $f ) = @_;
    return undef;
}

sub zmenu {
    my ($self, $f ) = @_;

    my $score = $f->score();
    my $start = $self->{'container'}->start() + $f->start() -1;
    my $end = $self->{'container'}->start() + $f->end() - 1;

    return {
        'caption'                                     => 'tRNA',
        "01:Score: $score"                            => '',
        "02:bp: $start-$end"                          => ''
    };
}
1;
