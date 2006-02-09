package EnsEMBL::Web::UserConfig::TSV_sampletranscript;
use strict;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
  my ($self) = @_;
  $self->{'_userdatatype_ID'} = 36;
  $self->{'_transcript_names_'} = 'yes';
  $self->{'_add_labels' }  = 1;

  $self->{'general'}->{'TSV_sampletranscript'} = {
    '_artefacts' => [qw(coverage_top TSV_transcript TSV_snps cxoverage_bottom)],#GSV_pfam GSV_prints GSV_prosite GSV_pfscan)],
    '_options'  => [qw(pos col known unknown)],
    '_settings' => {
      'opt_pdf' => 0, 'opt_svg' => 0, 'opt_postscript' => 0,
      'opt_zclick'     => 1,
      'show_labels' => 'no',
      'context'   => 100,
      'width'   => 900,
      'bgcolor'   => 'background1',
      'bgcolour1' => 'background1',
      'bgcolour2' => 'background1',

      'validation' => [
        [ 'opt_freq'       => 'By frequency' ],
        [ 'opt_cluster'    => 'By cluster' ],
        [ 'opt_doublehit'  => 'By doublehit' ],
        [ 'opt_submitter'  => 'By submitter' ],
        [ 'opt_hapmap'     => 'Hapmap' ],
        [ 'opt_noinfo'     => 'No information' ],
      ],
      'classes' => [
        [ 'opt_in-del'   => 'In-dels' ],
        [ 'opt_snp'      => 'SNPs' ],
        [ 'opt_mixed'    => 'Mixed variations' ],
        [ 'opt_microsat' => 'Micro-satellite repeats' ],
        [ 'opt_named'    => 'Named variations' ],
        [ 'opt_mnp'      => 'MNPs' ],
        [ 'opt_het'      => 'Hetrozygous variations' ],
        [ 'opt_'         => 'Unclassified' ],
      ],
      'types' => [
        [ 'opt_stop_lost',            => 'Stop lost' ],
        [ 'opt_stop_gained',          => 'Stop gained' ],
        [ 'opt_frameshift_coding'     => 'Coding variations' ],
        [ 'opt_non_synonymous_coding' => 'Non-synonymous SNPs' ],
        [ 'opt_essential_splice_site' => 'Essential splice site' ],
        [ 'opt_splice_site'           => 'Splice site' ],
        [ 'opt_regulatory_region',    => 'Regulatory region variations' ],
        [ 'opt_synonymous_coding'     => 'Synonymous SNPs' ],
        [ 'opt_5prime_utr'            => "5' UTR variations" ],
        [ 'opt_3prime_utr'            => "3' UTR variations" ],
        [ 'opt_downstream'            => 'Downstream variations' ],
        [ 'opt_upstream'              => 'Upstream variations' ],
        [ 'opt_intronic'              => 'Intronic variations' ],
        [ 'opt_intergenic'            => 'Intergenic variations' ],
      ],
      'features' => [
      #  [ 'GSV_pfam'    => 'Pfam domains' ],
      #  [ 'GSV_prints'  => 'Prints domains' ],
      #  [ 'GSV_prosite' => 'Prosite domains' ],
      #  [ 'GSV_pfscan'  => 'PFScan domains' ],
      ],
      'snphelp' => [
        [ 'transcriptsnpview'  => 'TranscriptSNPView' ],
      ],
    },
    'coverage_top' => {
      'on'          => "on",
      'pos'         => '120',
      'str'         => 'r',
      'type'        => 'top',
      'glyphset'    => 'coverage'
    },
    'TSV_transcript' => {
      'on'          => "on",
      'pos'         => '100',
      'str'         => 'b',
      'src'         => 'all', # 'ens' or 'all'
      'colours' => {$self->{'_colourmap'}->colourSet( 'all_genes' )} ,
    },
    'TSV_snps' => {
      'on'          => "on",
      'pos'         => '200',
      'str'         => 'r',
      'colours'=>{$self->{'_colourmap'}->colourSet('variation')},
    },
    'coverage_bottom' => {
      'on'          => "on",
      'pos'         => '950',
      'str'         => 'r',
      'type'        => 'bottom',
      'glyphset'    => 'coverage'
     },
#     'GSV_pfam' => {
#       'on'          => "on",
#       'pos'         => '300',
#       'str'         => 'r',
#       'col'         => 'violet3'
#     },
#     'GSV_prints' => {
#       'on'          => "on",
#       'pos'         => '301',
#       'str'         => 'r',
#       'col'         => 'violet3'
#     },
#     'GSV_prosite' => {
#       'on'          => "on",
#       'pos'         => '302',
#       'str'         => 'r',
#       'col'         => 'violet3'
#     },
#     'GSV_pfscan' => {
#       'on'          => "on",
#       'pos'         => '303',
#       'str'         => 'r',
#       'col'         => 'violet3'
#    },
 };
} 
1;
