package EnsEMBL::Web::ScriptConfig::alignsliceview;

use strict;
no strict 'refs';

sub init {
  my( $script_config ) = @_;

  $script_config->_set_defaults(qw(
    panel_ideogram on
    panel_top      on
    panel_bottom   on
    panel_zoom     off
    zoom_width     100
    image_width    700
    context    100000
    opt_MLAGAN-167_Homo_sapiens on
    opt_MLAGAN-167_Canis_familiaris on
    opt_MLAGAN-167_Mus_musculus on
    opt_MLAGAN-167_Rattus_norvegicus on
    opt_MLAGAN-190_Homo_sapiens on
    opt_MLAGAN-190_Canis_familiaris on
    opt_MLAGAN-190_Mus_musculus on
    opt_MLAGAN-190_Rattus_norvegicus on
    opt_MLAGAN-190_Gallus_gallus on
    opt_MLAGAN-190_Bos_taurus on
    opt_MLAGAN-190_Monodelphis_domestica on
    opt_alignm_MLAGAN-167 on
    opt_alignm_MLAGAN-190 off
    opt_alignp_BLASTZ_NET_Homo_sapiens off
    opt_alignp_BLASTZ_NET_Canis_familiaris off
    opt_alignp_BLASTZ_NET_Mus_musculus off
    opt_alignp_BLASTZ_NET_Rattus_norvegicus off
    opt_alignp_BLASTZ_NET_Gallus_gallus off
    opt_alignp_BLASTZ_NET_Bos_taurus off
    opt_alignp_BLASTZ_NET_Pan_troglodytes off

  ));
}
1;
