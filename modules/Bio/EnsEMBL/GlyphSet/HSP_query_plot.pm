package Bio::EnsEMBL::GlyphSet::HSP_query_plot;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet::HSP_plot);

sub region {
  my ($self, $hsp) = @_;
  my $start = $hsp->start();
  my $end   = $hsp->end();
  return ($start, $end);
}

1;
