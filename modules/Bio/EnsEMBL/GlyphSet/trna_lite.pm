package Bio::EnsEMBL::GlyphSet::trna_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple_hash;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple_hash);

sub my_label { return "tRNAs"; }

sub features {
  my ($self) = @_;
  return 
    $self->{'container'}->get_all_SimpleFeatures_above_score('tRNAscan',25);
}

sub href {
    my ($self, $f ) = @_;
    return undef;
}

sub zmenu {
    my ($self, $f ) = @_;

    my $score = $f->score();
    my $start = $self->{'container'}->chr_start() + $f->start() -1;
    my $end = $self->{'container'}->chr_start() + $f->end() - 1;

    return {
        'caption'                                     => 'tRNA',
        "01:Score: $score"                            => '',
        "02:bp: $start-$end"                          => ''
    };
}
1;
