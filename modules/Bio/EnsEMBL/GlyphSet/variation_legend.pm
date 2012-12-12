package Bio::EnsEMBL::GlyphSet::variation_legend;

use strict;

use Bio::EnsEMBL::Variation::Utils::Constants;

use base qw(Bio::EnsEMBL::GlyphSet::legend);

sub _init {
  my $self     = shift;
  my $features = $self->{'legend'}{[split '::', ref $self]->[-1]};
  
  return unless $features;

  my %labels = map { $_->SO_term => [ $_->rank, $_->label ] } values %Bio::EnsEMBL::Variation::Utils::Constants::OVERLAP_CONSEQUENCES;
  
  $self->init_legend(3);

  foreach (sort { $labels{$a}[0] <=> $labels{$b}[0] } keys %$features) {
    $self->add_to_legend({
      legend => $labels{$_}[1],
      colour => $features->{$_},
    });
  }
}

1;
