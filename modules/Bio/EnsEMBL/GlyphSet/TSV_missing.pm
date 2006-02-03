package Bio::EnsEMBL::GlyphSet::TSV_missing;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);

sub init_label {
    return;
}

sub _init {
  my ($self) = @_;
  return unless ($self->strand() == -1);
  my $counts = $self->{'config'}->{'snp_counts'};
  return unless ref $counts eq 'ARRAY';
  
  my $text;
  if ($counts->[0]==0 ) {
    $text .= "There are no SNPs in this region";
  }
  elsif ($counts->[1] ==0 ) {
    $text .= "The options set in the drop down menu have filtered out all $counts->[0] variations in this region.";
  }
  elsif ($counts->[0] == $counts->[1] ) {
    $text .= "None of the variation is removed by the drop down menu filters";
  }
  else {
    $text .= ($counts->[0]-$counts->[1])." of the $counts->[0] variations in this region have been filtered out by the drop down menu options.";
}


    my ($w,$h)   = $self->{'config'}->texthelper()->real_px2bp($self->{'config'}->species_defs->ENSEMBL_STYLE->{'LABEL_FONT'});
    my ($w2,$h2) = $self->{'config'}->texthelper()->real_px2bp('Small');
    $self->push( new Sanger::Graphics::Glyph::Text({
        'x'         => 0.5, 
        'y'         => int( ($h2-$h)/2 ),
        'height'    => $h2,
        'font'      => $self->{'config'}->species_defs->ENSEMBL_STYLE->{'LABEL_FONT'},
        'colour'    => 'red',
        'text'      => $text,
        'absolutey' => 1,
    }) );
}

1;
        
