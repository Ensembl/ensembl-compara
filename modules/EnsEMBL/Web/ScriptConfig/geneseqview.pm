package EnsEMBL::Web::ScriptConfig::geneseqview;

use strict;

sub init {
  my ($script_config) = @_;

  $script_config->_set_defaults(qw(
    flank5_display          600
    flank3_display          600 
    exon_display            core
    exon_ori                all
    snp_display             off
    line_numbering          off
    display_width 60
    conservation  all
    codons_display off
    RGselect   NONE
    ms_MLAGAN-167 off
    ms_MLAGAN-170 off
  ));
}
1;
