#########
# HSP_plot derived class - plots hsps against query
#
package Bio::EnsEMBL::GlyphSet::HSP_query_plot;
use Bio::EnsEMBL::GlyphSet::HSP_plot;
use vars qw(@ISA);
@ISA = qw(Bio::EnsEMBL::GlyphSet::HSP_plot);

sub region {
  my ($self, $hsp) = @_;
  my $start = $hsp->start();
  my $end   = $hsp->end();
  return ($start, $end);
}

1;
