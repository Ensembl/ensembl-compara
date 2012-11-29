package Bio::EnsEMBL::GlyphSet::tsv_haplotype_legend;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet::legend);

sub _init {
  my ($self) = @_; 
  
  my $Config        = $self->{'config'};

  return unless $Config->{'tsv_haplotype_legend_features'}; 
  my %features = %{$Config->{'tsv_haplotype_legend_features'}};
  return unless %features;

  $self->init_legend(3);

  my $seen_any = 0;
  foreach (sort { $features{$b}->{'priority'} <=> $features{$a}->{'priority'} } keys %features) {
    $self->newline(1);
    my @colours = @{$features{$_}->{'legend'}}; 
    while( my ($legend, $colour) = splice @colours, 0, 2 ) {  
      if ($legend =~ /Label/){next;}
      my $item = {
        legend => $legend,
        colour => $colour,
        border => 'black',
      };
      if($colour eq 'stripes') {
        my $conf_colours  = $self->my_config('colours' );
        $item->{'colour'} = $conf_colours->{'same'}{'default'};
        $item->{'stripe'} = $conf_colours->{'different'}{'default'};
      }
      $self->add_to_legend($item);
      $seen_any = 1;
    }
  }

  unless( $seen_any ) {
    $self->errorTrack( "No SNPs in this panel" );
  }
}

1;
      
