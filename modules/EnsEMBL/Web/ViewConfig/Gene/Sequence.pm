package EnsEMBL::Web::ViewConfig::geneseqview;

use strict;

sub init {
  my ($view_config) = @_;

  $view_config->_set_defaults(qw(
    flank5_display          600
    flank3_display          600 
    exon_display            core
    exon_ori                all
    snp_display             off
    line_numbering          off
  ));
  $view_config->storable = 1;
}
1;
