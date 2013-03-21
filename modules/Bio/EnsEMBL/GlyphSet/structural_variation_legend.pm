package Bio::EnsEMBL::GlyphSet::structural_variation_legend;

use strict;

use Bio::EnsEMBL::Variation::Utils::Constants;

use base qw(Bio::EnsEMBL::GlyphSet::legend);

sub _init {
  my $self     = shift;
  my $features = $self->{'legend'}{[split '::', ref $self]->[-1]};
  
  return unless $features;
  
  my %labels = %Bio::EnsEMBL::Variation::Utils::Constants::VARIATION_CLASSES;
  
  $self->init_legend(3);
  
  foreach (sort { $labels{$a}{'display_term'} cmp $labels{$b}{'display_term'} } keys %$features) {
    $self->add_to_legend({
      legend => $labels{$_}{'display_term'},
      colour => $features->{$_},
    });
  }
}

1;
