package Bio::EnsEMBL::GlyphSet::ex_profile;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "Exp. profile"; }

sub my_helplink { return "markers"; }

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_SimpleFeatures('Expression_profile');
}

sub href {
  my ($self, $f ) = @_;
  return $self->ID_URL( 'WORMBASE_EXPR_PROFILE', $f->display_label );
}

sub zmenu {
  my ($self, $f ) = @_;
  
  my $score = $f->score();
my ($start,$end) = $self->slice2sr( $f->start, $f->end );


  return {
        'caption' => 'Expression profile',
        "00:".$f->display_label => $self->href( $f ),
        "01:Score: $score" => '',
        "02:bp: $start-$end" => ''
    };
}
1;
