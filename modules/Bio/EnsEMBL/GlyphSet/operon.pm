package Bio::EnsEMBL::GlyphSet::operon;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub squish {1;}

sub my_label { return "Operon"; }

sub my_helplink { return "markers"; }

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_SimpleFeatures('operon');
}

sub href {
  my ($self, $f ) = @_;
  return $self->ID_URL( 'WORMBASE_OPERON', $f->display_label );
}
sub zmenu {
  my ($self, $f ) = @_;
  
  my $score = $f->score();
my ($start,$end) = $self->slice2sr( $f->start, $f->end );

  return {
	'caption' => 'Operon',
        "00:".$f->display_label => $self->href( $f ),
        "01:Score: $score" => '',
        "02:bp: $start-$end" => '',
    };
}
1;
