package EnsEMBL::Web::ImageConfig::gene_variation;

use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;
  
  my %colours;
  $colours{$_} = $self->species_defs->colour($_) for qw(variation haplotype);
  
  $self->set_parameters({
    label_width      => 100,        # width of labels on left-hand side
    opt_halfheight   => 0,          # glyphs are half-height [ probably removed when this becomes a track config ]
    opt_empty_tracks => 0,          # include empty tracks
    colours          => \%colours,  # colour maps
  });
  
  $self->create_menus(qw(
    transcript
    variation 
    somatic 
    gsv_transcript
    other 
    gsv_domain
  ));
  
  $self->load_tracks;
  
  $self->get_node('transcript')->set('caption', 'Other genes');
  
  $self->modify_configs(
    [ 'variation', 'somatic', 'gsv_transcript', 'other' ],
    { menu => 'no' }
  );
  
  if ($self->{'code'} ne $self->{'type'}) {
    my $func = "init_$self->{'code'}";
    $self->$func if $self->can($func);
  }
}

sub init_gene {
  my $self = shift;
  
  $self->add_tracks('variation',
    [ 'snp_join',         '', 'snp_join',         { display => 'on',     strand => 'b', menu => 'no', tag => 0, colours => $self->get_parameter('colours')->{'variation'} }],
    [ 'geneexon_bgtrack', '', 'geneexon_bgtrack', { display => 'normal', strand => 'b', menu => 'no', tag => 0, colours => 'bisque', src => 'all'          }]
  );
  
  $self->add_tracks('other',
    [ 'scalebar', '', 'scalebar', { display => 'normal', strand => 'f', menu => 'no'               }],
    [ 'ruler',    '', 'ruler',    { display => 'normal', strand => 'f', menu => 'no', notext => 1  }],
    [ 'spacer',   '', 'spacer',   { display => 'normal', strand => 'r', menu => 'no', height => 52 }],
  );
  
  $self->get_node('gsv_domain')->remove;
  
  $self->modify_configs(
    [ 'variation_feature_variation' ],
    { display => 'normal', caption => 'Variations', strand => 'f' }
  );
  $self->modify_configs(
    [ 'somatic_mutation_COSMIC' ],
    { display => 'normal', caption => 'COSMIC', strand => 'f' }
  );
}


sub init_transcripts_top {
  my $self = shift;
  
  $self->add_tracks('other',
    [ 'geneexon_bgtrack', '', 'geneexon_bgtrack', { display => 'normal', strand => 'f', menu => 'no', tag => 1, colours => 'bisque', src => 'all'                         }],
    [ 'snp_join',         '', 'snp_join',         { display => 'normal', strand => 'f', menu => 'no', tag => 1, colours => $self->get_parameter('colours')->{'variation'}, context => 50 }],
  );
  
  $self->get_node($_)->remove for qw(gsv_domain transcript);
}

sub init_transcript {
  my $self = shift;
  
  $self->add_tracks('other',
    [ 'gsv_variations', '', 'gsv_variations', { display => 'on',     strand => 'r', menu => 'no', colours => $self->get_parameter('colours')->{'variation'} }],
#    [ 'gsv_variations', '', 'gsv_variations', { display => 'on',     strand => 'r', menu => 'no', colours => $self->species_defs->colour('variation') }],
    [ 'spacer',         '', 'spacer',         { display => 'normal', strand => 'r', menu => 'no', height => 10,                              }],
  );
  
  $self->get_node('transcript')->remove;
  
  $self->modify_configs(
    [ 'gsv_variations' ],
    { display => 'box' }
  );
}

sub init_transcripts_bottom {
  my $self = shift;
  
  $self->add_tracks('other',
    [ 'geneexon_bgtrack', '', 'geneexon_bgtrack', { display => 'normal', strand => 'r', menu => 'no', tag => 1, colours => 'bisque', src => 'all'                         }],
    [ 'snp_join',         '', 'snp_join',         { display => 'normal', strand => 'r', menu => 'no', tag => 1, colours => $self->get_parameter('colours')->{'variation'}, context => 50 }],
    [ 'ruler',            '', 'ruler',            { display => 'normal', strand => 'r', menu => 'no', notext => 1, name => 'Ruler'                                        }],
    [ 'spacer',           '', 'spacer',           { display => 'normal', strand => 'r', menu => 'no', height => 50,                                                       }],
  );
  
  $self->get_node($_)->remove for qw(gsv_domain transcript);
}

sub init_snps {
  my $self= shift;
  
  $self->set_parameters({
    bgcolor   => 'background1',
    bgcolour1 => 'background3',
    bgcolour2 => 'background1'
  });
  
  $self->add_tracks('other',
    [ 'snp_fake',             '', 'snp_fake',             { display => 'on',  strand => 'f', colours => $self->get_parameter('colours')->{'variation'}, tag => 2                                    }],
    [ 'variation_legend',     '', 'variation_legend',     { display => 'on',  strand => 'r', menu => 'no', caption => 'Variation legend'                                             }],
    [ 'snp_fake_haplotype',   '', 'snp_fake_haplotype',   { display => 'off', strand => 'r', colours => $self->get_parameter('colours')->{'haplotype'}                                              }],
    [ 'tsv_haplotype_legend', '', 'tsv_haplotype_legend', { display => 'off', strand => 'r', colours => $self->get_parameter('colours')->{'haplotype'}, caption => 'Haplotype legend', src => 'all' }],
  );
  
  $self->get_node($_)->remove for qw(gsv_domain transcript);
}

1;
