package Bio::EnsEMBL::GlyphSet::gap;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "Gaps" };

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_MiscFeatures( 'gap' );
}

sub colour {
  my( $self, $f ) = @_;
  my %colours = ( 'END' => 'black', 'contig' => 'grey50', 'clone' => 'grey75', 'superctg' => 'black', 'scaffold' => 'black' );
  return $colours{ $f->get_attribute('name') };
}

sub zmenu {
  my( $self, $f ) = @_;
  return {
     'caption' => $f->get_attribute('name')." gap",
     "Location: ".$f->seq_start.' - '.$f->seq_end => '',
  };
}

1;
