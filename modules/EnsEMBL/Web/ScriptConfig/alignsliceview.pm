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

opt_align_1 on
    opt_1_Bos_taurus on
    opt_1_Canis_familiaris on
    opt_1_Homo_sapiens on
    opt_1_Macaca_mulatta on
    opt_1_Mus_musculus on
    opt_1_Pan_troglodytes on
    opt_1_Rattus_norvegicus on

opt_align_2 off
    opt_2_Bos_taurus on
    opt_2_Canis_familiaris on
    opt_2_Homo_sapiens on
    opt_2_Macaca_mulatta on
    opt_2_Mus_musculus on
    opt_2_Pan_troglodytes on
    opt_2_Rattus_norvegicus on
    opt_2_Gallus_gallus on
    opt_2_Monodelphis_domestica on

    opt_align_214 on
opt_214_Homo_sapiens on
opt_214_Macaca_mulatta on
opt_214_Pan_troglodytes on

    opt_align_192 off
opt_192_Homo_sapiens on
opt_192_Bos_taurus on
opt_192_Canis_familiaris on
opt_192_Mus_musculus on
opt_192_Rattus_norvegicus on

    opt_align_193 off
opt_193_Homo_sapiens on
opt_193_Bos_taurus on
opt_193_Canis_familiaris on
opt_193_Gallus_gallus on
opt_193_Mus_musculus on
opt_193_Monodelphis_domestica on
opt_193_Rattus_norvegicus on

    opt_align_171 off
    opt_align_172 off
    opt_align_173 off
    opt_align_174 off
    opt_align_191 off
    opt_align_194 off
    opt_align_195 off
    opt_align_213 off
  ));
}
1;
