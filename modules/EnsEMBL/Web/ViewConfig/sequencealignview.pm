package EnsEMBL::Web::ViewConfig::sequencealignview;

use strict;

sub init {
  my ($view_config) = @_;

  $view_config->_set_defaults(qw(
    exon_display            core
    exon_ori                off 
    snp_display             on
    line_numbering          off 
    display_width           60
    conservation            off
    codons_display          off
    match_display           off
    title_display           off
    exon_mark		    colour
  ));
  $view_config->storable = 1;
}
1;
