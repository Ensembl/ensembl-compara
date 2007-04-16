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
    image_width    700
    context    100000

    opt_align_259 off
opt_259_Homo_sapiens on
opt_259_Pan_troglodytes on
opt_259_Macaca_mulatta on
opt_259_Bos_taurus on
opt_259_Canis_familiaris on
opt_259_Mus_musculus on
opt_259_Rattus_norvegicus on

    opt_align_267 off
opt_267_Homo_sapiens on
opt_267_Pan_troglodytes on
opt_267_Macaca_mulatta on
opt_267_Bos_taurus on
opt_267_Canis_familiaris on
opt_267_Gallus_gallus on
opt_267_Mus_musculus on
opt_267_Monodelphis_domestica on
opt_267_Ornithorhynchus_anatinus on
opt_267_Rattus_norvegicus on

opt_268_constrained_elem on
opt_268_conservation_score on
 ),
  map {( "opt_align_$_" => "off")} (4,93,154..400)
  );
  $script_config->storable = 1;
  $script_config->add_image_configs({qw(
    alignsliceviewbottom nodas
  )});
}

1;
