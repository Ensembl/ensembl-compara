package Bio::EnsEMBL::GlyphSet::diff_legend;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet::legend);

sub _init {
  my $self = shift;
  
  my $config    = $self->{'config'};
  return unless $config->{'_difference_legend'};
  
  my @blocks = (
    { 
      legend => 'Insert relative to reference',
      colour => '#2aa52a',
      border => 'black',
    },{
      legend => 'Delete relative to reference',
      colour => 'red',
    },{
      legend => 'Inserts grouped at this scale (zoom to resolve)',
      colour => '#2aa52a', 
      overlay => '..',
      border => 'black',
      test => '_difference_legend_dots',
    },{
      legend => 'Deletes grouped at this scale (zoom to resolve)',
      colour => '#ffdddd',
      test => '_difference_legend_pink',
    },{
      legend => 'Large insert shown truncated due to image scale or edge',
      colour => '#94d294',
      overlay => '...',
      test => '_difference_legend_el',
    },{
      legend => 'Match',
      colour => '#ddddff',
    });

  $self->init_legend(4);
  
  foreach my $b (@blocks) {
    next if $b->{'test'} and not $config->{$b->{'test'}};
    $self->add_to_legend($b);
  }
}

1;
