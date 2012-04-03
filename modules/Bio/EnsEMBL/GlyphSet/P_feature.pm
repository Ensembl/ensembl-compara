package Bio::EnsEMBL::GlyphSet::P_feature;

use strict;

use base  qw(Bio::EnsEMBL::GlyphSet);

sub colour_key { return $_[1]->analysis->logic_name; }

sub _init {
  my $self    = shift;
  my $protein = $self->{'container'};
  
  return unless $protein->dbID;
  
  my $caption   = $self->my_config('caption');
  my $h         = $self->my_config('height') || 4;
  my $y         = 0;
  my $colourmap = $self->{'config'}->colourmap;
  
  foreach my $logic_name (@{$self->my_config('logic_names') || []}) {
    my $colour;
    
    foreach my $pf (@{$protein->get_all_ProteinFeatures($logic_name)}) {
      my $x = $pf->start;
      my $w = $pf->end - $x;
      
      $self->push($self->Rect({
        x      => $x,
        y      => $y,
        width  => $w,
        height => $h,
        title  => "$caption; Position: " . $pf->start . '-' . $pf->end,
        colour => $colour ||= $self->get_colour($pf),
      }));
    }
    
    $y += $h + 2; ## slip down a line for subsequent analyses
  }
}

1;
