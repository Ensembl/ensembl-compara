package EnsEMBL::Web::UserConfig::snpview;
use strict;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
  my ($self) = @_;
  $self->{'_userdatatype_ID'} = 30;
  $self->{'_transcript_names_'} = 'yes';
  #$self->{'_no_label'} = 'true';
  $self->{'general'}->{'snpview'} = {
    '_artefacts' => [qw( 
                       stranded_contig
                       ruler
                       scalebar
                       snp_triangle_glovar
		       variation_box
                       genotyped_variation
		       ld_r2
                       ld_d_prime 
                       haplotype
                       variation_legend

                    )],
    '_options'  => [qw(pos col known unknown)],
    '_settings' => {
     'features' => [
                     [ 'variation_box'            => "SNPs"          ],
                     [ 'variation_legend'         => "SNP legend"    ],
                     [ 'genotyped_variation'      => "Genotyped SNPs"],
                     [ 'ld_r2'      => "LD (r2)"],
                     [ 'ld_d_prime' => "LD (d')"],
                    ],
      'options' => [
                    [ 'opt_empty_tracks' => 'Show empty tracks' ],
                    [ 'opt_zmenus'      => 'Show popup menus'  ],
                    [ 'opt_zclick'      => '... popup on click'  ],
                   ],
      'opt_empty_tracks' => 1,
      'opt_zmenus'     => 1,
      'opt_zclick'     => 1,
      'show_buttons'  => 'yes',
      'show_labels'      => 'yes',
      'width'     => 650,
      'bgcolor'   => 'background1',
      'bgcolour1' => 'background3',
      'bgcolour2' => 'background1',
    },
    'ruler' => {
      'on'          => "on",
      'pos'         => '1000',
      'col'         => 'black',
    },
    'stranded_contig' => {
      'on'          => "on",
      'pos'         => '0',
      'navigation'  => 'off'
    },
    'scalebar' => {
      'on'          => "on",
      'nav'         => "off",
      'pos'         => '8000',
      'col'         => 'black',
      'str'         => 'r',
      'abbrev'      => 'on',
      'navigation'  => 'off'
    },
    'snp_triangle_glovar' => {
      'on'          => "off",
      'pos'         => '4521',
      'str'         => 'r',
      'dep'         => '10',
      'col'         => 'blue',
      'track_height'=> 7,

      'hi'          => 'black',
      'colours' => {$self->{'_colourmap'}->colourSet('snp')},
      'available'=> 'database ENSEMBL_GLOVAR', 
    },

   'variation_box' => {
      'on'          => "on",
      'pos'         => '4522',
      'str'         => 'r',
      'dep'         => '10000',
      'col'         => 'blue',
      'track_label' => "Variations",
      'track_height'=> 7,
      'hi'          => 'black',
      'colours' => {$self->{'_colourmap'}->colourSet('variation')},
      'available'=> 'databases ENSEMBL_VARIATION', 
    },

    'genotyped_variation' => {
      'on'          => "on",
      'pos'         => '4523',
      'str'         => 'r',
      'dep'         => '10000',
      'col'         => 'blue',
      'track_height'=> 7,
      'compact'     => 0,
      'track_label' => "Genotyped variation",
      'hi'          => 'black',
      'colours' => {$self->{'_colourmap'}->colourSet('variation')},
      'available'=> 'databases ENSEMBL_VARIATION',
    },

    'ld_r2' => {
      'on'          => "off",
      'pos'         => '4550',
      'str'         => 'r',
      'dep'         => '10000',
      'col'         => 'blue',
      'track_height'=> 7,
      'compact'     => 0,
      'track_label' => "LD(r2) for Global Pop.",
      'hi'          => 'black',
      'key'         => 'r2',
      'glyphset'    => 'ld',
      'colours'     => {$self->{'_colourmap'}->colourSet('variation')},
      'available'   => 'databases ENSEMBL_VARIATION',
    },
    'ld_d_prime' => {
      'on'          => "off",
      'pos'         => '4555',
      'str'         => 'r',
      'dep'         => '10000',
      'col'         => 'blue',
      'track_height'=> 7,
      'compact'     => 0,
      'key'         => 'd_prime',
      'track_label' => "Linkage disequilibrium (d')" ,
      'hi'          => 'black',
      'glyphset'    => 'ld',
      'colours'     => {$self->{'_colourmap'}->colourSet('variation')},
      'available'   => 'databases ENSEMBL_VARIATION',
    },

   'haplotype' => {
      'on'          => "on",
      'pos'         => '4600',
      'str'         => 'r',
      'dep'         => 6,
      'col'         => 'darkgreen',
      'lab'         => 'black',
      'available'=> 'databases ENSEMBL_HAPLOTYPE',
    },

    'variation_legend' => {
      'on'          => "on",
      'str'         => 'r',
      'pos'         => '4525',
    },
  };

  # Make squished genes
  $self->ADD_ALL_TRANSCRIPTS(2000, compact => 1);  #first is position
}



1;
