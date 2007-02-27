package EnsEMBL::Web::ScriptConfig::sequencealignview;

use strict;

sub init {
  my ($script_config) = @_;

  $script_config->_set_defaults(qw(
    flank5_display          600
    flank3_display          600 
    exon_display            core
    exon_ori                all
    snp_display             on
    line_numbering          slice 
    display_width           60
    conservation            all
    codons_display          off
    title_display           off
  ));
  $script_config->storable = 1;
}
1;
