package EnsEMBL::Web::ImageConfig::MultiBottom;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);

sub mergeable_config {
  return 1;
}

sub init {
  my ($self ) = @_;

  $self->set_parameters({
    'title'             => 'Main panel',
    'show_buttons'      => 'no',   # show +/- buttons
    'button_width'      => 8,       # width of red "+/-" buttons
    'show_labels'       => 'yes',   # show track names on left-hand side
    'label_width'       => 113,     # width of labels on left-hand side
    'margin'            => 5,       # margin
    'spacing'           => 2,       # spacing

## Now let us set some of the optional parameters....
    'opt_halfheight'    => 0,    # glyphs are half-height [ probably removed when this becomes a track config ]
    'opt_lines'         => 1,    # draw registry lines
    'opt_restrict_zoom' => 1,   # when we get "zoom" working draw restriction enzyme info on it!!

    'spritelib' => { 'default' => $self->{'species_defs'}->ENSEMBL_SERVERROOT.'/htdocs/img/sprites' },
  });

## First add menus in the order you want them for this display....
  $self->create_menus(
    'sequence'        => 'Sequence',
    'marker'          => 'Markers',
    'trans_associated'=> 'Transcript Features',
    'transcript'      => 'Genes',
    'prediction'      => 'Prediction Transcripts',
    'protein_align'   => 'Protein alignments',
    'protein_feature' => 'Protein features',
    'dna_align_cdna'  => 'cDNA/mRNA alignments', # Separate menus for different cDNAs/ESTs...
    'dna_align_est'   => 'EST alignments',
    'dna_align_rna'   => 'RNA alignments',
    'dna_align_other' => 'Other DNA alignments', 
    'oligo'           => 'Oligo features',
    'ditag'           => 'Ditag features',
    'external_data'   => 'External data',
    'user_data'       => 'User attached data', # DAS/URL tracks/uploaded data/blast responses
    'simple'          => 'Simple features',
    'misc_feature'    => 'Misc. regions',
    'repeat'          => 'Repeats',
    'variation'       => 'Variation features',
    'functional'      => 'Functional genomics',
    'multiple_align'  => 'Multiple alignments',
    'pairwise_blastz' => 'BLASTZ alignments',
    'pairwise_tblat'  => 'Translated blat alignments',
    'pairwise_other'  => 'Pairwise alignment',
    'information'     => 'Information',
    'decorations'     => 'Additional decorations',
    'options'         => 'Options'
  );

## Add in additional
  $self->load_tracks;
  $self->load_configured_das;
  $self->add_track( 'sequence',    'contig',    'Contigs',             'stranded_contig', { 'display' => 'normal', 'strand' => 'f' } );
  $self->add_tracks( 'information',
    [ 'missing',   '', 'text', { 'display' => 'normal', 'strand' => 'r', 'name' => 'Disabled track summary', 'description' => 'Show counts of number of tracks turned off by the user' } ],
    [ 'info',      '', 'text', { 'display' => 'normal', 'strand' => 'r', 'name' => 'Information',            'description' => 'Details of the region shown in the image'               } ],
  );

  $self->add_tracks( 'decorations',
   [ 'ruler',     '',            'ruler',           { 'display' => 'normal',  'strand' => 'b', 'name' => 'Ruler',     'description' => 'Shows the length of the region being displayed'    } ],
   [ 'scalebar',  '',            'scalebar',        { 'display' => 'normal',  'strand' => 'b', 'name' => 'Scale bar', 'description' => 'Track ', 'menu' => 'no' } ],
   [ 'draggable', '',            'draggable',       { 'display' => 'normal',  'strand' => 'b', 'menu' => 'no'         } ],
   [ 'nav',       '',            'navigation',      { 'display' => 'normal',  'strand' => 'r', 'menu' => 'no' } ],
  );

## Finally add details of the options to the options menu...
  $self->add_options(
#    [ 'opt_empty_tracks',  'Show empty tracks?'           ],
    [ 'opt_lines',         'Show registry lines?'         ],
#    [ 'opt_restrict_zoom', 'Restriction enzymes on zoom?' ],
  );

  #use Data::Dumper; local $Data::Dumper::Indent = 1; warn Data::Dumper::Dumper( $self->tree );
}

sub mult {
  my $self = shift;
  my @species = @{$self->{'species_defs'}->ENSEMBL_SPECIES};
  my $compara = 3000;
  my @methods = (
    [ 'BLASTZ_NET'           ,'pink',  'cons',  'darkseagreen1', -20  ],
    [ 'BLASTZ_NET_TIGHT'     ,'pink3', 'high cons','darkolivegreen2', -19   ],
    [ 'BLASTZ_GROUP'         ,'pink',  'cons', 'darkseagreen1', -20  ],
    [ 'BLASTZ_GROUP_TIGHT'   ,'pink3', 'high cons','darkolivegreen2', -19   ],
    [ 'PHUSION_BLASTN'       ,'pink',  'cons', 'darkseagreen1', -20  ],
    [ 'PHUSION_BLASTN_TIGHT' ,'pink3', 'high cons','darkolivegreen2', -19   ],
    [ 'BLASTZ_RECIP_NET'     ,'pink',  'cons', 'darkseagreen1', -20  ],
    [ 'TRANSLATED_BLAT'      ,'orchid1', 'trans BLAT','chartreuse', -18 ],
  );

  foreach my $METHOD (@methods) {
    foreach my $SPECIES (@species) {
      (my $species = $SPECIES ) =~ s/_\d+//;
      (my $short = $species ) =~ s/^(\w)\w+_(\w)\w+$/$1$2/g;
      $compara++;
      my $KEY = lc($SPECIES).'_'.lc($METHOD->[0]).'_match';
      $self->{'general'}->{'MultiBottom'}{$KEY} = {
        'glyphset' => 'generic_alignment',
        'species'  => $species,
        'on'       => 'off',
        'compact'  => 'yes',
        'dep'      => 6,
        'pos'      => $compara+300,
        'col'      => $METHOD->[1],
        'join' => 0,
        'join_col' => $METHOD->[3],
        'join_z'   => $METHOD->[4],
        'str'      => 'f',
        'available'=> "multi ".$METHOD->[0]."|$species",
        'method'   => $METHOD->[0],
        'label'    => "$short $METHOD->[2]",
      };
      push @{ $self->{'general'}->{'MultiBottom'}{ '_artefacts'} }, $KEY;
    }
  }
}



1;
