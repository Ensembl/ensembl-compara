package Bio::EnsEMBL::GlyphSet::P_variation_legend;

use strict;

use Bio::EnsEMBL::Variation::Utils::Constants;

use base qw(Bio::EnsEMBL::GlyphSet::legend);

sub _init {
  my $self = shift;
  
  my $config   = $self->{'config'};
  my $features = $config->{'P_variation_legend'};
  
  return unless $features;
 
  $self->init_legend(4);
 
  my %labels   = map { $_->SO_term => [ $_->rank, $_->label ] } values %Bio::EnsEMBL::Variation::Utils::Constants::OVERLAP_CONSEQUENCES;
  
  $labels{'Insert'} = [ 9e9,     'Insert' ];
  $labels{'Delete'} = [ 9e9 + 1, 'Delete' ];
 
  foreach (sort { $labels{$a}[0] <=> $labels{$b}[0] } keys %$features) {
    my $text   = $labels{$_}[1];
    
    if ($features->{$_}{'shape'} eq 'Triangle') {
      $self->add_to_legend({
        legend => $text,
        style  => 'triangle',
        direction => $text eq 'Insert'?'down':'up',
        border => 'black',
        width => 5,
        height => 5,
      });
    } else {
      $self->add_to_legend({
        legend => $text,
        colour => $features->{$_}{'colour'},
        width  => 4,
        height => 4,
      });
    }
  }
}

1;
        
