package Bio::EnsEMBL::GlyphSet::cnv_probes;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label   { return 'Copy Number Variant Probes'; }
sub colour_key { return 'cnv'; }

sub features {
  my $self   = shift; 
  my $slice  = $self->{'container'};
  my $source = $self->my_config('source');

  my $var_features;
  
  if ($source =~ /^\w/) {
    $var_features = $slice->get_all_CopyNumberVariantProbeFeatures($source);
  } else {
    $var_features = $slice->get_all_CopyNumberVariantProbeFeatures;
  }
  
  return $var_features;  
}

sub href {
  my ($self, $f) = @_;
  
  my $href = $self->_url({
    type => 'StructuralVariation',
    sv   => $f->variation_name,
		svf  => $f->dbID,
    vdb  => 'variation'
  });
  
  return $href;
}

sub title {
  my ($self, $f) = @_;
  my $id     = $f->variation_name;
  my $start  = $self->{'container'}->start + $f->start -1;
  my $end    = $self->{'container'}->end + $f->end;
  my $pos    = 'Chr ' . $f->seq_region_name . ":$start-$end";
  my $source = $f->source;

  return "Copy number variation probes: $id; Source: $source; Location: $pos";
}

sub highlight {
  my ($self, $f, $composite, $pix_per_bp, $h) = @_;
  
  return unless grep $_ eq $f->variation_name, $self->highlights;
  
  # First a black box
  $self->unshift(
    $self->Rect({
      x         => $composite->x - 2 / $pix_per_bp,
      y         => $composite->y - 2, # + makes it go down
      width     => $composite->width + 4 / $pix_per_bp,
      height    => $h + 4,
      colour    => 'black',
      absolutey => 1,
    }),
		$self->Rect({ # Then a 1 pixel smaller green box
      x         => $composite->x - 1 / $pix_per_bp,
      y         => $composite->y - 1, # + makes it go down
      width     => $composite->width + 2 / $pix_per_bp,
      height    => $h + 2,
      colour    => 'green',
      absolutey => 1,
    })
  );
}

1;
