package Bio::EnsEMBL::GlyphSet::fg_methylation_legend;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet::legend);

sub _init {
  my $self = shift;

  return unless $self->{'legend'}{[split '::', ref $self]->[-1]};
  
  $self->init_legend(2);

  $self->add_to_legend({
    legend => '% methylated reads',
    colour => [qw(yellow green blue)],
  }); 
}

1;
