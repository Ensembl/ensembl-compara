package EnsEMBL::Web::ImageConfig::alignsliceviewbottom;

=head1 NAME

EnsEMBL::Web::ImageConfig::alignsliceviewbottom;

=head1 SYNOPSIS

alignsliceviewbottom.pm manages a user-defined settings in alignsliceview.

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 CONTACT

Eugene Kulesha - ek3@sanger.ac.uk

=cut

use strict;
no strict 'refs';
use EnsEMBL::Web::ImageConfig;
use vars qw(@ISA);
my $reg = "Bio::EnsEMBL::Registry";
@ISA = qw(EnsEMBL::Web::ImageConfig);

sub TRIM   { return sub { return $_[0]=~/(^[^\.]+)\./ ? $1 : $_[0] }; }

sub init {
  my ($self ) = @_;
  $self->{'_das_offset'} = '5800';

  $self->{'_userdatatype_ID'} = 190;
  $self->{'_add_labels'} = 'yes';
  $self->{'_transcript_names_'} = 'yes';
  $self->{'general'}->{'alignsliceviewbottom'} = {
    '_artefacts' => [
## The following are the extra fugu bits... 
## Only features whose key is in this array gets displayed as a track....
       qw( repeat_lite ),
       qw( constrained_elements alignment variation stranded_contig ruler alignscalebar),
    ],
    '_options'  => [qw(on pos col hi low dep str src known unknown ext)],
    '_names'   => {
      'on'    => 'activate',
      'pos'   => 'position',
      'col'   => 'colour',
      'dep'   => 'depth',
      'str'   => 'strand',
      'hi'    => 'highlight colour',
      'src'   => 'source',
      'known'   => 'known colour',
      'unknown' => 'unknown colour',
      'ext'   => 'external colour',
    },
    '_settings' => {
## Image size configuration...
      'spritelib' => { 'default' => $self->{'species_defs'}->ENSEMBL_SERVERROOT.'/htdocs/img/sprites' },
      'width'         => 700,
      'spacing'       => 1,
      'margin'        => 2,
      'intercontainer' => 1,
      'label_width'   => 100,
      'button_width'  => 8,
      'show_buttons'  => 'yes',
      'show_labels'   => 'yes',
## Parameters for "zoomed in display"
      'squished_features' => 'yes', 
      'zoom_zoom_gifs'     => {
        zoom1   =>  150,   zoom2   =>  200,
        zoom3   =>  300,  zoom4   =>  500,
        zoom5   =>  750,  zoom6   => 1000
      },
      'align_zoom_gifs'     => {
        zoom1   =>  25,   zoom2 =>  50,
        zoom3   =>  75,   zoom4 => 100,  
	zoom5   =>  125,  zoom6 => 150
      },
      'show_zoom_aligncontigview' => 'yes',
      'zoom_width' => 100,
      
      'URL'       => '',
      'show_aligncontigview' => 'yes',
      'name'      => qq(AlignSliceView Detailed Window),
## Other stuff...
      'draw_red_box'  => 'no',
      'default_vc_size' => 100000,
      'main_vc_width'   => 100000,
      'imagemap'    => 1,
      'opt_pdf' => 0, 'opt_svg' => 0, 'opt_postscript' => 0,
      'opt_lines'      => 1,
      'opt_empty_tracks' => 0,
      'opt_show_bumped' => 0,
      'opt_daswarn'    => 0,
      'opt_zmenus'     => 1,
      'opt_zclick'     => 1,
      'opt_halfheight'     => 0,
      'opt_shortlabels'     => 0,
      'bgcolor'     => 'background1',
      'bgcolour1'     => 'background2',
      'bgcolour2'     => 'background3',
      'zoom_gifs'     => {
        zoom1   =>  1000,   zoom2   =>  5000,   zoom3   =>  10000,  zoom4   =>  50000,
        zoom5   =>  100000, zoom6   =>  200000, zoom7   =>  500000, zoom8   =>  1000000
      },
      'navigation_options' => [ '5mb', '2mb', '1mb', 'window', 'half', 'zoom' ],
      'features' => [
         # 'name'          => 'caption'       
## SIMPLE FEATURES ##
         [ 'variation'       => 'SNPs'  ],
      ],
      'compara' => [ ],
      'options' => [
         # 'name'            => 'caption'
         [ 'stranded_contig' => 'Contigs'       ],
         [ 'opt_lines'       => 'Show register lines' ],
         [ 'opt_empty_tracks' => 'Show empty tracks' ],
         [ 'opt_zmenus'      => 'Show popup menus'  ],
         [ 'opt_zclick'      => '... popup on click'  ],
         [ 'opt_halfheight'  => 'Half-height glyphs'  ],
         [ 'opt_show_bumped' => 'Show # bumped glyphs'  ],
         [ 'info'            => 'Information track' ],
      ],
      'menus' => [ qw( features compara repeats options jumpto export resize )]
    },

## Stranded contig is the central track so should always have pos set to 0...
  
    'stranded_contig' => {
      'on'  => "on",
      'navigation' => 'on',
      'pos' => '0',
    },

## Blast and SSAHA tracks displayed if linked to from Blast/SSAHA...
## These get put beside the central track and so are numbered 4 and 6

    'blast_new' => {
      'on'  => "off",
      'pos' => '7',
      'col' => 'red',
      'dep' => '6',
      'str' => 'b',
      'force_cigar' => 'yes',
    },
  
    'blast' => {
      'on'  => "on",
      'pos' => '5',
      'col' => 'red',
      'str' => 'b',
    },
  
    'ssaha' => {
      'on'  => "on",
      'pos' => '6',
      'col' => 'red',
      'str' => 'b',
    },

    'variation' => {
      'on'  => "off",
      'bump_width' => 0,
      'dep' => 0.1,
      'pos' => '4523',
      'str' => 'r',
      'col' => 'blue',
      'colours' => {$self->{'_colourmap'}->colourSet('variation')},
      'available'=> 'databases DATABASE_VARIATION', 
    },


## Repeats 
    'codonseq' => {
      'on'      => "off",
      'pos'       => '4',
      'str'       => 'b',
      'bump_width'   => 0,
      'lab'       => 'black',
      'dep'       => 3,
      'colours'     => {
# hydrophobic
'A' => 'darkseagreen1',  # Alanine
'G' => 'mediumseagreen',  # Glycine
'I' => 'greenyellow',  # Isoleucine
'L' => 'olivedrab1',  # Leucine
'M' => 'green',  # Methionine
'P' => 'springgreen1',  # Proline
'V' => 'darkseagreen3',  # Valine
# large hydrophobic
'F' => 'paleturquoise',  # Phenylalanine
'H' => 'darkturquoise',  # Histidine
'W' => 'skyblue',  # Tryptophan
'Y' => 'lightskyblue',  # Tyrosine
# Cysteine
'C' => 'khaki',  # Cysteine
# Negative charge
'D' => 'gold',  # Aspartic Acid
'E' => 'darkgoldenrod1',  # Glutamic Acid
# Positive charge
'K' => 'lightcoral',  # Lysine
'R' => 'rosybrown',  # Arginine
# Polar 
'N' => 'plum2',  # Asparagine
'Q' => 'thistle1',  # Glutamine
'S' => 'mediumpurple1',  # Serine
'T' => 'mediumorchid1',  # Threonine
# Stop codon...
'*' => 'red',  # Stop
    },
      'navigation'  => 'on',
      'navigation_threshold' => '0',
      'threshold'   => '0.5',
    }, 
    'assemblyexception' => {
      'on'      => "on",
      'pos'       => '8498932',
      'str'       => 'x',
      'lab'       => 'black',
      'navigation'  => 'on',
    },

    'sequence' => {
      'on'      => "off",
      'pos'       => '3',
      'str'       => 'f',
      'lab'       => 'black',
      'colours'     => {
         'G' => 'lightgoldenrod1',
         'T' => 'lightpink2',
         'C' => 'lightsteelblue',
         'A' => 'lightgreen',
      },
      'navigation'  => 'on',
      'navigation_threshold' => '0',
      'threshold'   => '0.2',
    }, 

    'alignment' => {
	'on'      => "off",
	'pos'       => '300',
	'str'       => 'f',
	'lab'       => 'black',
	'colours' => {$self->{'_colourmap'}->colourSet('alignment')},
	'base_colours'     => {
	    'G' => 'lightgoldenrod1',
	    'T' => 'lightpink2',
	    'C' => 'lightsteelblue',
	    'A' => 'lightgreen',
	},
	'navigation'  => 'on',
	'navigation_threshold' => '0',
	'threshold'   => '0.2',
    }, 

    'repeat_lite' => {
      'on'      => "off",
      'pos'       => '5000',
      'str'       => 'r',
      'col'       => 'gray50',
      'navigation'  => 'on',
      'navigation_threshold' => '2000',
      'threshold'   => '2000',
    }, 
    'urlfeature' => {
      'on'      => "on",
      'pos'       => '7099',
      'str'       => 'b',
      'col'       => 'red',
      'force_cigar' => 'yes',
      'dep'       => 6,
      'navigation'  => 'on',
      'navigation_threshold' => '2000',
      'threshold'   => '2000',
    }, 
    'sub_repeat' => {
      'on'      => "on",
      'pos'       => '5010',
      'str'       => 'r',
      'col'       => 'gray50',
      'navigation'  => 'on',
      'navigation_threshold' => '2000',
      'threshold'   => '2000',
    }, 
## The measurement decorations    
    'ruler' => {
      'on'      => "on",
      'pos'       => '6990',
      'col'       => 'black',
      'str' => 'f'
    },
    'scalebar' => {
      'on'      => "off",
      'pos'       => '7010',
      'col'       => 'black',
      'max_division'  => '12',
      'label'     => '',
      'str'       => 'b',
      'subdivs'     => 'on',
      'abbrev'    => 'on',
      'navigation'  => 'on'
    },
    'alignscalebar' => {
      'on'      => "on",
      'pos'       => '7010',
      'col'       => 'black',
      'max_division'  => '12',
      'label'     => '',
      'str'       => 'b',
      'subdivs'     => 'on',
      'abbrev'    => 'on',
      'navigation'  => 'on'
    },

    'assembly_contig' => {
      'on'      => "on",
      'pos'       => '8030',
      'colours'     => {
        'col1'      => 'contigblue1',
        'col2'      => 'contigblue2',
        'lab1'      => 'white',
        'lab2'      => 'white',
      },
      'str'       => 'r',
      'dep'       => '0',
      'available'   => 'features mapset_assembly', 
    },
    
## and legend....    
    'gene_legend' => {
      'on'      => "off",
      'str'       => 'r',
      'pos'       => '9999',
    },
    'snp_legend' => {
      'on'      => "off",
      'str'       => 'r',
      'type'      => 'square',
      'pos'       => '10000',
      'available'   => 'database_tables EMSEMBL_LITE.snp'
    },
    'missing' => {
      'on'      => "off",
      'str'       => 'r',
      'pos'       => '10001',
    },
    'info' => {
      'on'      => "off",
      'str'       => 'r',
      'pos'       => '10003',
    },
    'mod' => {
      'on'      => "off",
      'str'       => 'f',
      'pos'       => '10002',
    },
    'preliminary' => {
      'on'      => "off",
      'str'       => 'f',
      'pos'       => '1',
    },

    'quote' => {
      'on' => 'off',
      'str' => 'r',
      'pos' => 1.1e9
    },
  };


  my $species = $ENV{ENSEMBL_SPECIES};

  my %alignments = $self->{'species_defs'}->multiX('ALIGNMENTS');

  foreach my $id (
		  sort { 10 * ($alignments{$a}->{'type'} cmp $alignments{$b}->{'type'}) + ($a <=> $b) }
		  grep { $alignments{$_}->{'species'}->{$species} } 
		  keys (%alignments)) {

      my $label = $alignments{$id}->{'name'};
      my @species = grep {$_ ne $species} sort keys %{$alignments{$id}->{'species'}};

      $label = $species[0] if ( scalar(@species) == 1);
      my $KEY = lc($species)."_compara_$id";

      $self->{'general'}->{'alignsliceviewbottom'}{$KEY} = {
	  'species'  => $species,
	  'on'       => 'off',
	  'label'    => $label
      };
  
      push @{ $self->{'general'}->{'alignsliceviewbottom'}{ '_artefacts'} }, $KEY;
      push @{ $self->{'general'}->{'alignsliceviewbottom'}{'_settings'}{'aligncompara'} },  [ $KEY , $label ];

  }



  %alignments = $self->{'species_defs'}->multiX('CONSTRAINED_ELEMENTS');
  foreach my $id (
		  sort { 10 * ($alignments{$a}->{'type'} cmp $alignments{$b}->{'type'}) + ($a <=> $b) }
		  grep { $alignments{$_}->{'species'}->{$species} } 
		  keys (%alignments)) {


      my @species = grep {$_ ne $species} sort keys %{$alignments{$id}->{'species'}};

      next if ( scalar(@species) == 1);
      my $label = $alignments{$id}->{'name'};
      my $short = "constrain elem";
      my $color = "pink4";
      my $available = "constrained_element $id";

      $self->{'general'}->{'alignsliceviewbottom'}{'constrained_elements'} = {
        'glyphset' => 'multiple_alignment',
        'species'  => $species,
        'compact'  => 1,
        'dep'      => 6,
        'pos'      => 3300,
        'col'      => $color,
        'str'      => 'f',
        'available'=> $available,
        'method'   => $alignments{$id}->{'type'},
	'method_id' => $id,
        'label'    => $short,
        'title'    => $label,
      };
#       push @{ $self->{'general'}->{'contigviewbottom'}{ '_artefacts'} }, $KEY;
#       push @{ $self->{'general'}->{'contigviewbottom'}{'_settings'}{'compara'} },  [ $KEY , $METHOD->[3] ];
  }
 
  $self->ADD_ALL_TRANSCRIPTS( 0 );
#  my $POS = $self->ADD_ALL_AS_TRANSCRIPTS( 0 );
}


1;
