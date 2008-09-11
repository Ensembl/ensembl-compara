package Bio::EnsEMBL::GlyphSet::Pprotein;
use strict;
use vars qw(@ISA $SPECIES_DEFS);
use Bio::EnsEMBL::GlyphSet;
#use EnsEMBL::Web::GeneTrans::support;

@ISA = qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my ($self) = @_;
  my $db;
  my $protein    = $self->{'container'};	
  my $pep_splice = $protein->{'image_splice'};
  my $prot_id    = $protein->stable_id;

  my $x          = 0;
  my $h          = $self->my_config('height') || 4; 
  my $flip       = 0;
  my @colours    = ($self->my_colour('col1'), $self->my_config('col2'));
  my $start_phase = 1;
  if( $pep_splice ){
    for my $exon_offset (sort { $a <=> $b } keys %$pep_splice){
      my $colour = $colours[$flip];
      my $exon_id = $pep_splice->{$exon_offset}{'exon'};
      next unless $exon_id;

      $self->push( $self->Rect({
        'x'        => $x,
        'y'        => 0,
        'width'    => $exon_offset - $x,
        'height'   => $h,
        'colour'   => $colour,
        'title'    => sprintf 'Exon: %s; Start phase: %d; End phase: %d; Length: %d',
	                $exon_id, $start_phase, $pep_splice->{$exon_offset}{'phase'} +1,
			$exon_offset - $x
      }));
      $x           = $exon_offset ;
      $start_phase = ($pep_splice->{$exon_offset}{'phase'} +1) ;
      $flip        = 1-$flip;
    }
  } else {
    $self->push( $self->Rect({
      'x'        => 0,
      'y'        => 0,
      'width'    => $protein->length(),
      'height'   => $h,
      'colour'   => $colours[0],
    }));
  }
}
1;


