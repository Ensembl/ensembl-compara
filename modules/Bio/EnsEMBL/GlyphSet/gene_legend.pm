package Bio::EnsEMBL::GlyphSet::gene_legend;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet::legend);

sub _init {
  my $self = shift;
  
  return unless $self->strand == -1;

  my $config    = $self->{'config'};
  return unless $config->{'legend_features'};
  my %features = %{$config->{'legend_features'}};
  return unless %features;

  $self->init_legend(2);
  
  foreach my $type (sort { $features{$a}{'priority'} <=> $features{$b}{'priority'} } keys %features) {
    my $join    = $type eq 'joins';
    my @colours = $join ? map { $_, $features{$type}{'legend'}{$_} } sort keys %{$features{$type}{'legend'}} : @{$features{$type}{'legend'}};
  
    $self->newline(1);  
    while (my ($legend, $colour) = splice @colours, 0, 2) {
      $self->add_to_legend({
        legend => $legend,
        colour => $colour,
        style  => ($type eq 'joins')?'line':'box',
      });
    }
  }
}

1;
        
