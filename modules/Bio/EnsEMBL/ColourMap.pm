package Bio::EnsEMBL::ColourMap;
use strict;
use Sanger::Graphics::ColourMap;
use EnsWeb;
use vars qw(@ISA);
@ISA = qw(Sanger::Graphics::ColourMap);

sub new {
  my $class = shift;
  my $self = $class->SUPER::new( @_ );
  while(my($k,$v) = each %{$EnsWeb::species_defs->ENSEMBL_COLOURS||{}} ) {
    $self->{$k} = $v;
  }

  $self->{'colour_sets'} = {};
  $self->{'colour_sets'}{'synteny'} = [qw(
    red3 green4 cyan4 blue3 chocolate3 brown
    chartreuse4 grey25 deeppink4 slateblue3
    olivedrab4 gold4 blueviolet seagreen4 violetred3
  )];
  my %core = (
    '_KNOWN'     => [ 'rust', 'known' ],
    '_KNOWNXREF' => [ 'rust', 'known' ],
    '_XREF'      => [ 'black','novel' ],
    '_ORTH'      => [ 'green3', 'ortholog' ],
    '_PREDXREF'  => [ 'red3',   'prediction'  ],
    '_PRED'      => [ 'red3',   'prediction'  ],
    '_BACCOM'    => [ 'red',    'bacterial contaminent' ],
    '_'          => [ 'black',  'novel' ],
    '_PSEUDO'    => [ 'grey50', 'pseudogene' ],
  );
  $self->colourSet( 'ensembl_gene',
    'hi'         => 'highlight1',
    'superhi'    => 'highlight2',
    map { $_ => [ $core{$_}[0], "EnsEMBL predicted genes (@{[$core{$_}[1]]})" ] } keys %core
  );
  $self->colourSet( 'wormbase_gene',
    'hi'         => 'highlight1',
    'superhi'    => 'highlight2',
    map { $_ => [ $core{$_}[0], "Wormbase predicted genes (@{[$core{$_}[1]]})" ] } keys %core
  );
  $self->colourSet( 'flybase_gene',
    'hi'         => 'highlight1',
    'superhi'    => 'highlight2',
    map { $_ => [ $core{$_}[0], "Flybase predicted genes (@{[$core{$_}[1]]})" ] } keys %core
  );
  $self->colourSet( 'vega_gene',
    'hi'                    => 'highlight1',
    'superhi'               => 'highlight2',
    'Novel_CDS'             => [ 'blue', 'Curated novel CDS' ],
    'Novel_CDS_in_progress' => [ 'cornflowerblue', 'Curated novel CDS (in progress)'],
    'Putative'              => [ 'lightslateblue', 'Curated putative' ],
    'Known'                 => [ 'dodgerblue4', 'Curated known gene' ],
    'Known_in_progress'     => [ 'lightskyblue4', 'Curated known gene (in progress)'],
    'Pseudogene'            => [ 'grey70', 'Curated pseudogene' ],
    'Processed_pseudogene'  => [ 'grey38', 'Curated processed pseudogene' ],
    'Unprocessed_pseudogene'=> [ 'grey27', 'Curated unprocessed pseudogene' ],
    'Novel_Transcript'      => [ 'skyblue3', 'Curated novel transcript' ],
    'Ig_Segment'            => [ 'midnightblue', 'Curated Ig segment' ],
    'Ig_Pseudogene_Segment' => [ 'mediumpurple4', 'Curated Ig pseudogene' ],
    'Predicted_Gene'        => [ 'steelblue4', 'Curated predicted gene'] ,
    'Transposon'            => [ 'steelblue', 'Curated transposon'] ,
    'Polymorphic'           => [ 'blue4', 'Curated Polymorhic' ]
  );
  $self->colourSet( 'rna_gene',
    'hi'         => 'highlight1',
    'superhi'    => 'highlight2',
    'rna-pseudo' => [ 'plum3', 'RNA Pseudogene' ] ,
    'rna-real'   => [ 'plum4', 'RNA gene' ]
  );
  $self->colourSet( 'est_gene',
    'hi'         => 'highlight1',
    'superhi'    => 'highlight2',
    'genomewise' => [ 'purple1', 'EST gene' ],
    'est_genebuilder' => [ 'purple1', 'EST gene' ],
    'estgene'    => [ 'purple1', 'EST gene' ],
    'est_gene'    => [ 'purple1', 'EST gnee' ]
  );
  $self->colourSet( 'prot_gene',
    'hi'         => 'highlight1',
    'superhi'    => 'highlight2',
    '_col'       => [ 'orchid4', 'Aligned protein' ], 
  );
  $self->colourSet( 'refseq_gene',
    'hi'         => 'highlight1',
    'superhi'    => 'highlight2',
    '_refseq' => [ 'blue', 'Aligned RefSeq' ],
  );

  $self->colourSet( 'protein',
    'default'    => 'gold',
    'refseq'     => 'orange',
  );
  $self->colourSet( 'cdna',
    'default'    => 'chartreuse3',
    'refseq'     => 'mediumspringgreen',
    'riken'      => 'olivedrab4',
  );
  $self->colourSet( 'mrna',
    'default'    => 'red',
  );
  $self->colourSet( 'est',
    'default'    => 'purple1',
    'genoscope'  => 'purple3',
  );
  $self->colourSet( 'glovar_sts',
    'col'    => 'grey',
    'unknown'    => 'grey',
    'pass' => 'green',
    'fail'  => 'red',
  );
  $self->colourSet( 'snp',
    '_coding'      => 'red',
    '_utr'         => 'orange',
    '_intron'      => 'contigblue2',
    '_local'       => 'contigblue1',
    '_'            => 'gray50',
    'label_coding' => 'white',
    'label_utr'    => 'black',
    'label_intron' => 'white',
    'label_local'  => 'white',
    'label_'       => 'white',
  );
  $self->colourSet( 'marker',
    ''               => 'magenta',
    'est'            => 'magenta',
    'microsatellite' => 'plum4',
  );
  return $self;
}

sub colourSet {
  my $self = shift;
  my $name = shift;
  if(@_) {
    $self->{'colour_sets'}{$name} = {@_};
  }
  return %{$self->{'colour_sets'}{$name}||{}};
}
1;
