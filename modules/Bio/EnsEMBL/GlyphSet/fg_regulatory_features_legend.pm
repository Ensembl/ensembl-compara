package Bio::EnsEMBL::GlyphSet::fg_regulatory_features_legend;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet::legend);

sub _init {
  my $self = shift;
  
  return unless $self->{'legend'}{[split '::', ref $self]->[-1]};
  
  my %features = %{$self->my_config('colours')};
  
  return unless %features;
 
  $self->init_legend(2);
 
  my $empty = 1;
 
  foreach (sort keys %features) {
    my $legend = $self->my_colour($_, 'text'); 
    
    next if $legend =~ /unknown/i; 
    
    $self->add_to_legend({
      legend => $legend,
      colour => $self->my_colour($_),
    });
    
    $empty = 0;
  }
  
  $self->errorTrack('No Regulatory Features in this panel') if $empty;
}

1;
