package EnsEMBL::Web::ScriptConfig::geneseqalignview;

=head1 NAME

EnsEMBL::Web::ScriptConfig::geneseqalignview;

=head1 SYNOPSIS

The object handles the config of geneseqalignview script

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 CONTACT

Eugene Kulesha - ek3@sanger.ac.uk

=cut

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
    display_width 120
    conservation  all
    codons_display off
    title_display off
    RGselect   NONE
    ms_1 off
    ms_2 off
  ));
}
1;
