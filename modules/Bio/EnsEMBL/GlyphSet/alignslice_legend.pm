package Bio::EnsEMBL::GlyphSet::alignslice_legend;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet::legend);

sub _init {
  my $self = shift;
  
  my $config   = $self->{'config'};
  my $features = $config->{'alignslice_legend'};
  
  return unless $features;

  $self->init_legend(2);
  
  foreach (sort { $features->{$a}->{'priority'} <=> $features->{$b}->{'priority'} } keys %$features) {
    $self->add_to_legend({
      legend => $features->{$_}{'legend'},
      colour => $_,
      style  => 'triangle',
    });
  }
}

1;
        
