package Bio::EnsEMBL::GlyphSet::generic_simple;


use strict;
use base qw(Bio::EnsEMBL::GlyphSet_simple);

sub squish { return 1; }

sub my_label       { return $_[0]->my_config( 'caption'     ); }
sub my_helplink    { return $_[0]->my_config( 'helplink'    ) || 'markers' ; }
sub my_description { return $_[0]->my_config( 'description' );
sub features {
  my $self = shift;
  my $method = "get_all_".( $_->[0]->my_config('Method') || 'SimpleFeatures' );
  return $self->{'container'}->$method( $_[0]->my_config( 'key' ), $_[0]->my_config( 'threshold' ) );
}

sub href {
  my ($self, $f ) = @_;
  return undef;
}

sub zmenu {
  my ($self, $f ) = @_;
   
  my $score = $f-can('score') ? $f->score() : '';
  my ($start,$end) = $self->slice2sr( $f->start, $f->end );
  return {
    'caption'                       => $self->my_config( 'caption' ),
    "01:Score:    $score"           => '',
    "02:Location: $start-$end"      => '',
    "03:Length:   ".($end-$start+1) => ''
  };
}
1;
