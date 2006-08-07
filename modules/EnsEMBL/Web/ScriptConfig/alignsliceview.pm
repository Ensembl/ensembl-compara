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

    opt_align_216 off
opt_216_Homo_sapiens on
opt_216_Macaca_mulatta on
opt_216_Pan_troglodytes on

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

    opt_align_4 off
    opt_align_171 off
    opt_align_172 off
    opt_align_173 off
    opt_align_174 off
    opt_align_191 off
    opt_align_194 off
    opt_align_195 off
    opt_align_196 off
    opt_align_212 off
    opt_align_215 off
    opt_align_217 off
    opt_align_218 off
    opt_align_219 off
    opt_align_220 off
    opt_align_221 off
    opt_align_222 off
  ));
}
1;
