package Bio::EnsEMBL::GlyphSet::polyA_site;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "PolyA sites"; }

sub my_helplink { return "markers"; }

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_SimpleFeatures('polyA_site', 0);
}

sub zmenu {
  my ($self, $f ) = @_;
  
  my $score = $f->score();
  my $start = $self->{'container'}->chr_start() + $f->start() - 1;
  my $end   = $self->{'container'}->chr_start() + $f->end() - 1;

  return {
        'caption' => 'polyA site',
        "01:Score: $score" => '',
        "02:bp: $start-$end" => ''
    };
}
1;
