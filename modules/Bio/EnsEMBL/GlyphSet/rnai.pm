package Bio::EnsEMBL::GlyphSet::rnai;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub squish {1;}
sub my_label { return "RNAi"; }

sub my_helplink { return "markers"; }

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_SimpleFeatures('RNAi' );

}

sub href {
  my ($self, $f ) = @_;
  return $self->ID_URL( 'WORMBASE_RNAI', $f->display_label );
}

sub zmenu {
  my ($self, $f ) = @_;
  
  # warn( join '  ', map { "$_-$f->{$_}" } keys %$f );
  my $score = $f->score();
my ($start,$end) = $self->slice2sr( $f->start, $f->end );


  return {
        'caption' => 'RNAi',
        "00:".$f->display_label => $self->href( $f ),
        "01:Score: $score" => '',
        "02:bp: $start-$end" => ''
    };
}
1;
