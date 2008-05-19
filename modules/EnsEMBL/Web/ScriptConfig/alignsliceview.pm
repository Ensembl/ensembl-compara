package EnsEMBL::Web::ScriptConfig::alignsliceview;

=head1 NAME

EnsEMBL::Web::ScriptConfig::alignsliceview;

=head1 SYNOPSIS

The object handles the config of alignsliceview script

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 CONTACT

Eugene Kulesha - ek3@sanger.ac.uk

=cut

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
    image_width    800
    context    100000

    opt_align_291 off
opt_291_Homo_sapiens on
opt_291_Pan_troglodytes on
opt_291_Macaca_mulatta on
opt_291_Bos_taurus on
opt_291_Canis_familiaris on
opt_291_Mus_musculus on
opt_291_Rattus_norvegicus on

    opt_align_292 off
opt_292_Homo_sapiens on
opt_292_Pan_troglodytes on
opt_292_Macaca_mulatta on
opt_292_Bos_taurus on
opt_292_Canis_familiaris on
opt_292_Gallus_gallus on
opt_292_Mus_musculus on
opt_292_Monodelphis_domestica on
opt_292_Ornithorhynchus_anatinus on
opt_292_Rattus_norvegicus on

    opt_align_294 off
opt_294_Homo_sapiens on
opt_294_Pan_troglodytes on
opt_294_Macaca_mulatta on
opt_294_Bos_taurus on
opt_294_Canis_familiaris on
opt_294_Gallus_gallus on
opt_294_Mus_musculus on
opt_294_Monodelphis_domestica on
opt_294_Ornithorhynchus_anatinus on
opt_294_Rattus_norvegicus on

opt_292_constrained_elem on
opt_292_conservation_score on
 ),
  map {( "opt_align_$_" => "off")} (4,93,154..400)
  );
  $script_config->storable = 1;
  $script_config->add_image_configs({qw(
    alignsliceviewbottom nodas
  )});
}

1;
