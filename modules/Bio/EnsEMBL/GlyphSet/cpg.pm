package Bio::EnsEMBL::GlyphSet::cpg;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "CpG islands"; }

sub my_helplink { return "markers"; }

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_SimpleFeatures('CpG', 25);
}

sub zmenu {
  my ($self, $f ) = @_;
  
  my $score = $f->score();
my ($start,$end) = $self->slice2sr( $f->start, $f->end );

  return {
        'caption' => 'CPG data island',
        "01:Score: $score" => '',
        "02:bp: $start-$end" => ''
    };
}
1;
