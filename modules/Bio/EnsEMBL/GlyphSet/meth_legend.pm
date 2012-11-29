package Bio::EnsEMBL::GlyphSet::meth_legend;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet::legend);

sub _init {
  my $self = shift;

  return unless $self->{'config'}{'_meth_legend'};
  $self->init_legend(2);

  $self->add_to_legend({
      colour => [qw(yellow green blue)],
      legend => "% methylated reads",
  }); 
}

1;
