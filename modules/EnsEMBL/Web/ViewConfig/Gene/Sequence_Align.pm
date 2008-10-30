package EnsEMBL::Web::ViewConfig::geneseqalignview;

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
    display_width 120
    conservation  all
    codons_display off
    title_display off
    RGselect   NONE
    ms_1 off
    ms_2 off
    ms_192 off
    ms_193 off
    ms_213 off
  ));
  $view_config->storable = 1;
}

sub form {}
1;
