package Bio::EnsEMBL::GlyphSet::gap;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "Gaps" };

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_MapFrags( 'gap' );
}

sub colour {
  my( $self, $f ) = @_;
  my %colours = ( 'END' => 'black', 'contig' => 'grey50', 'clone' => 'grey75', 'superctg' => 'black' );
  return $colours{ $f->name };
}

sub zmenu {
  my( $self, $f ) = @_;
  return {
     'caption' => $f->name." gap",
     "Location: ".$f->seq_start.' - '.$f->seq_end => '',
  };
}

1;
