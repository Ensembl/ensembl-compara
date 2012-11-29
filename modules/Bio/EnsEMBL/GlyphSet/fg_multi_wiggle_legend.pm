package Bio::EnsEMBL::GlyphSet::fg_multi_wiggle_legend;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet::legend);

sub _init {
  my $self = shift;
  
  my $config = $self->{'config'};
  return unless $config->{'fg_multi_wiggle_legend'};

  my $features = $config->{'fg_multi_wiggle_legend'}->{'colours'};
  return unless $features;
 
  $self->init_legend(4);
 
  my $empty = 1;
  my $items = []; 
  foreach (sort keys %$features) {  
    $empty = 0;
    $self->add_to_legend({
      legend => $_,
      colour => $features->{$_} || 'black',
    });
  }
  
  $self->errorTrack('No Cell/Tissue regulation data in this panel') if $empty;
}

1;
