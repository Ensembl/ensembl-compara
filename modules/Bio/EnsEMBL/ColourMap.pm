package Bio::EnsEMBL::ColourMap;
use strict;
use Sanger::Graphics::ColourMap;
use vars qw(@ISA);
@ISA = qw(Sanger::Graphics::ColourMap);

sub new {
  my $class = shift;
  my $species_defs = shift;
  my $self = $class->SUPER::new( @_ );

  my %new_colourmap = qw(
    BACKGROUND1 background0
    BACKGROUND3 background3
    BACKGROUND4 background2
    BACKGROUND5 background1
    CONTIGBLUE1 contigblue1
    CONTIGBLUE2 contigblue2
    HIGHLIGHT1  highlight1
    HIGHLIGHT2  highlight2
  );
  while(my($k,$v) = each %{$species_defs->ENSEMBL_STYLE||{}} ) {
    my $k2 = $new_colourmap{ $k };
    $self->{$k2} = $v if $k2;
  }

  $self->{'colour_sets'} = {};
  my %core = (
    '_protein_coding'           => [ 'rust', 'Known Protein Coding' ],
    '_protein_coding_KNOWN'     => [ 'rust', 'Known Protein Coding' ],
    '_protein_coding_KNOWN_BY_PROJECTION'     => [ 'rust', 'Known Proj Protein Coding' ],
    '_protein_coding_PUTATIVE'     => [ 'black', 'Putative Protein Coding' ],
    '_pseudogene_KNOWN'         => [ 'grey50','Known Pseudogene' ],
    '_protein_coding_NOVEL'     => [ 'black', 'Novel Protein Coding' ],
    '_pseudogene_NOVEL'         => [ 'grey30','Novel Pseudogene' ],
    '_Mt_tRNA_KNOWN'            => [ 'plum4', 'Known RNA' ],
    '_rRNA_KNOWN'               => [ 'plum4', 'Known RNA' ],
    '_tRNA_KNOWN'               => [ 'plum4', 'Known RNA' ],
    '_tRNA_NOVEL'               => [ 'plum3', 'Novel RNA' ],
    '_snoRNA_KNOWN'             => [ 'plum4', 'Known RNA' ],
    '_snRNA_KNOWN'              => [ 'plum4', 'Known RNA' ],
    '_misc_RNA_KNOWN'           => [ 'plum4', 'Known RNA' ],
    '_misc_RNA_NOVEL'           => [ 'plum3', 'Novel RNA' ],
    '_ORTH'      => [ 'green3', 'ortholog' ],
    '_PREDXREF'  => [ 'red3',   'prediction'  ],
    '_PRED'      => [ 'red3',   'prediction'  ],
    '_BACCOM'    => [ 'red',    'bacterial contaminent' ],
    '_'          => [ 'black',  'novel' ],
    '_NOVEL'     => [ 'black',  'novel' ],
    '_PSEUDO'    => [ 'grey50', 'pseudogene' ],
  );
  $self->colourSet( 'protein_features', qw(
    prints             rust
    prositepatterns    orange
    scanprosite        orange
    prositeprofiles    contigblue1
    pfscan    contigblue1
    pfam               grey33
    tigrfam            red
    superfamily        blue
    smart              chartreuse3
    pirs               gold3

    ncoils             darkblue
    seg                gold2
    signalp            pink
    tmhmm              darkgreen

    hi                 green
    default            violet 
  ));
  $self->colourSet( 'oxford_genes',
    'hi'         => 'highlight1',
    'superhi'    => 'highlight2',
    'oxford' => [ 'darkred', 'Oxford genes' ]
  );
  $self->colourSet( 'chimp_genes',
    'hi'         => 'highlight1',
    'superhi'    => 'highlight2',
    'chimp_est'  => [ 'purple1', 'Chimp EST genes' ],
    'chimp_cdna' => [ 'chartreuse3', 'Chimp cDNA genes' ],
    'human_cdna' => [ 'mediumspringgreen', 'Human cDNA genes' ]
  );
  $self->colourSet( 'medaka_genes',
    'hi'         => 'highlight1',
    'superhi'    => 'highlight2',
    'transcriptcoalescer' => [ 'darkgreen', 'Medaka Transcript Coalescer genes' ],
    'genome_project'      => [ 'darkred', 'Medaka Genome Project genes' ]
  );
  $self->colourSet( 'platypus_protein',
    'hi'         => 'highlight1',
    'superhi'    => 'highlight2',
    'platypus_protein' => [ 'blue', 'Platypus protein' ],
    'other_protein' => [ 'black', 'Other protein' ],
  );

  $self->colourSet( 'dog_protein',
    'hi'         => 'highlight1',
    'superhi'    => 'highlight2',
    'dog_protein' => [ 'blue', 'Dog protein' ]
  );

  $self->colourSet( 'human_ensembl_proteins_gene',
    'hi'         => 'highlight1',
    'superhi'    => 'highlight2',
    map {( "human_ensembl_proteins$_" => [ $core{$_}[0], "Human proteins (@{[$core{$_}[1]]})" ] )} keys %core
  );

  $self->colourSet( 'cow_protein',
    'hi'         => 'highlight1',
    'superhi'    => 'highlight2',
    'cow_protein' => [ 'blue', 'Cow protein' ]
  );
  $self->colourSet( 'tigr_0_5',
    'hi'         => 'highlight1',
    'superhi'    => 'highlight2',
    'tigr_0_5' => [ 'blue', 'TIGR protein' ]
  );
  $self->colourSet( 'oxford_fgu',
    'hi'         => 'highlight1',
    'superhi'    => 'highlight2',
    'oxford_fgu' => [ 'blue', 'Oxford FGU Gene Pred.' ]
  );
  $self->colourSet( 'ensembl_gene',
    'hi'         => 'highlight1',
    'superhi'    => 'highlight2',
    'havana_protein_coding_KNOWN'  => [ 'dodgerblue4', 'Havana Known Protein coding'],
    'havana_protein_coding_NOVEL'  => [ 'blue',        'Havana Novel Protein coding' ],
    'ensembl_havana_gene_protein_coding_KNOWN'  => [ 'goldenrod3', 'Merged Known Protein coding'],
    'ensembl_havana_gene_protein_coding_NOVEL'  => [ 'goldenrod4', 'Merged Novel Protein coding'],
    'ensembl_havana_transcript_protein_coding_KNOWN'  => [ 'goldenrod3', 'Common Known Protein coding'],
    'ensembl_havana_transcript_protein_coding_NOVEL'  => [ 'goldenrod4', 'Common Novel Protein coding'],
    map { ("ensembl$_" => [ $core{$_}[0], "Ensembl ".$core{$_}[1] ]) } keys %core
  );
  $self->colourSet( 'sgd_gene',
    'hi'         => 'highlight1',
    'superhi'    => 'highlight2',
    map { ("SGD$_" => [ $core{$_}[0], "SGD ".$core{$_}[1] ]) } keys %core
  );
  $self->colourSet( 'bee_gene',
    'hi'         => 'highlight1',
    'superhi'    => 'highlight2',
    map { $_ => [ $core{$_}[0], "Bee predicted genes (@{[$core{$_}[1]]})" ] } keys %core
  );
  $self->colourSet( 'bee_pre_gene',
    'Homology_high'   => [ 'sienna4', 'Homology high' ],
    'Homology_medium' => [ 'sienna3', 'Homology medium' ],
    'Homology_low'    => [ 'sienna2', 'Homology low' ],
    'BeeProtein'      => [ 'blue', 'Aligned Bee Protein' ]
  );
  $self->colourSet( 'genoscope_gene',
    'hi'         => 'highlight1',
    'superhi'    => 'highlight2',
    '_GSTEN' => [ 'black', 'Genoscope predicted genes' ],
    '_HOX' => [ 'rust', 'Genoscope annotated genes' ],
    '_CYT' => [ 'rust', 'Genoscope annoateed genes' ],
  );
  $self->colourSet( 'wormbase_gene',
    'hi'         => 'highlight1',
    'superhi'    => 'highlight2',
    map {( "wormbase$_" => [ $core{$_}[0], "Wormbase (@{[$core{$_}[1]]})" ] )} keys %core
  );
  $self->colourSet( 'vectorbase_gene',
    'hi'         => 'highlight1',
    'superhi'    => 'highlight2',
    map { ( "vectorbase$_" => [ $core{$_}[0], "Vectorbase (@{[$core{$_}[1]]})" ] )} keys %core
  );
  $self->colourSet( 'flybase_gene',
    'hi'         => 'highlight1',
    'superhi'    => 'highlight2',
    map { ( "flybase$_" => [ $core{$_}[0], "Flybase (@{[$core{$_}[1]]})" ] )} keys %core
  );
  $self->colourSet( 'vega_gene',
    'hi'                               => 'highlight1',
    'superhi'                          => 'highlight2',
    'ccdshi'                           => 'lightblue1',
    'protein_coding_KNOWN'             => [ 'dodgerblue4', 'Known Protein coding'],
    'processed_transcript_KNOWN'       => [ 'dodgerblue4', 'Known Processed transcript'],
    'protein_coding_in_progress_KNOWN' => [ 'lightskyblue4', 'Known Protein coding (in progress)'],
    'protein_coding_NOVEL'             => [ 'blue', 'Novel Protein coding' ],
    'protein_coding_in_progress_NOVEL' => [ 'cornflowerblue', 'Novel Protein coding (in progress)'],
    'protein_coding_PREDICTED'         => [ 'steelblue4', 'Predicted Protein coding'] ,
    'processed_transcript_NOVEL'       => [ 'skyblue3', 'Novel Processed transcript' ],
    'processed_transcript_PUTATIVE'    => [ 'lightslateblue', 'Putative Processed transcript' ],
    'total_pseudogene_UNKNOWN'         => [ 'grey70', 'Total Pseudogenes' ],
    'pseudogene_UNKNOWN'               => [ 'grey70', 'Pseudogene' ],
    'processed_pseudogene_UNKNOWN'     => [ 'grey38', 'Processed pseudogene' ],
    'unprocessed_pseudogene_UNKNOWN'   => [ 'grey27', 'Unprocessed pseudogene' ],
    'Ig_segment_KNOWN'                 => [ 'midnightblue', 'Known Ig segment' ],
    'Ig_segment_NOVEL'                 => [ 'navy', 'Ig segment' ],
    'total_Ig_segment_UNKNOWN'         => [ 'midnightblue', 'Ig segment' ],
    'Ig_pseudogene_segment_UNKNOWN'    => [ 'mediumpurple4', 'Ig pseudogene' ],
  );
  $self->colourSet( 'rna_gene',
    'hi'         => 'highlight1',
    'superhi'    => 'highlight2',
    'rna-realKNOWN'       => [ 'plum4', 'RNA gene (Known)' ],
    'rna-realPREDICTED'   => [ 'plum3', 'RNA gene (Predicted)' ],
    'rna-realNOVEL'       => [ 'plum1', 'RNA gene (Novel)' ],
    'rna-pseudoKNOWN'     => [ 'pink3', 'RNA Pseudogene (Known)' ] ,
    'rna-pseudoNOVEL'     => [ 'pink1', 'RNA Pseudogene (Novel)' ] ,
  );
  $self->colourSet( 'est_gene',
    'hi'         => 'highlight1',
    'superhi'    => 'highlight2',
    'EST_Genebuilder'  => [ 'purple1', 'EST gene' ],
    'genomewise' => [ 'purple1', 'EST gene' ],
    'est_genebuilder' => [ 'purple1', 'EST gene' ],
    'estgene'    => [ 'purple1', 'EST gene' ],
    'est_gene'    => [ 'purple1', 'EST gene' ],
    'protein_coding' => [ 'purple1', 'EST gene' ],
    'est_seqc' => [ 'purple1', "3' EST (Kyoto)" ],
    'est_seqn' => [ 'purple1', "5' EST (Kyoto)" ] ,
    'est_seqs' => [ 'purple1', "full insert cDNA clone" ],
    'dbest_ncbi' => [ 'purple1', "3/5' EST (dbEST)" ]
  );
  $self->colourSet( 'ciona_gene',
    'hi'         => 'highlight1',
    'superhi'    => 'highlight2',
    'jgi_v1'              => [ 'blue', 'JGI v1 models' ],
    'kyotograil_2004'     => [ 'dodgerblue4', 'Kyotograil 2004' ],
    'kyotograil_2005'     => [ 'dodgerblue4', 'Kyotograil 2005' ],
  );
  $self->colourSet( 'prot_gene',
    'hi'         => 'highlight1',
    'superhi'    => 'highlight2',
    'cdna_all'      => [ 'orchid2', 'Aligned cDNA' ],
    'TGE_gw'        => [ 'orchid4', 'Aligned protein' ],
    'tge_gw'        => [ 'orchid4', 'Aligned protein' ],
    'targettedgenewise' => [ 'orchid4', 'Aligned protein' ],
    'protein_coding'  => [ 'orchid4', 'Aligned protein' ], 
    'mus_one2one_human_orth' => [ 'orchid2', 'Mm/Hs orth. gene' ],
    'human_one2one_mus_orth' => [ 'orchid3', 'Hs/Mm orth. gene' ],
    'species_protein'        => [ 'orchid1', 'Gene' ],
    'xtrop_cdna'      => [ 'orchid2', 'Aligned cDNA' ],
    'xtrop_cDNA'      => [ 'orchid2', 'Aligned cDNA' ],
    '_col'            => [ 'orchid4', 'Aligned protein' ], 
  );
  $self->colourSet( 'refseq_gene',
    'hi'         => 'highlight1',
    'superhi'    => 'highlight2',
    '_refseq' => [ 'blue', 'Aligned RefSeq' ],
  );
  $self->colourSet( 'all_genes', map { $self->colourSet($_) } keys %{$self->{'colour_sets'}} );
    
  $self->colourSet( 'protein',
    'default'    => 'gold',
    'refseq'     => 'orange',
  );
  $self->colourSet( 'cdna',
    'default'    => 'chartreuse3',
    'refseq'     => 'mediumspringgreen',
    'riken'      => 'olivedrab4',
    'genoscope'  => 'green',
    'genoscope_ecotig'  => 'blue',
    'WZ'         => 'chartreuse3',
    'EMBL'       => 'mediumspringgreen',
    'IMCB_HOME'  => 'olivedrab4',
  );
  $self->colourSet( 'mrna',
    'default'    => 'red',
  );
  $self->colourSet( 'rna',
    'BlastmiRNA'    => 'plum4',
    'RfamBlast'     => 'plum4',
    'default'       => 'plum4'
  );

  $self->colourSet( 'est',
    'default'    => 'purple1',
    'genoscope'  => 'purple3',
    'WZ'         => 'purple1',
    'mmc'        => 'darkgreen',
    'IMCB_HOME'  => 'purple3'
  );
  $self->colourSet( 'glovar_sts',
    'col'               => 'grey',
    'Unknown'           => 'grey',
    'PCR_pass'          => 'green',
    'Failed'            => 'red',
    'Sequence_pass'     => 'green',
    'HW_pass'           => 'green',
    'Multiple_product'  => 'red',
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

  $self->{'colour_sets'}{'synteny'} = [qw(
    red3 green4 cyan4 blue3 chocolate3 brown
    chartreuse4 grey25 deeppink4 slateblue3
    olivedrab4 gold4 blueviolet seagreen4 violetred3
  )];

  # key => [colour, text, labelcolour]
  $self->colourSet( 'variation',
    'SARA'               => ['border:grey70',      'SARA', 'black',],
    'INTERGENIC'             => ['gray39',         'Intergenic',           'white',],
    'INTRONIC'               => ['contigblue2',    'Intronic',         'white',],
    'UPSTREAM'               => ['lightsteelblue2','Upstream',              'black',],
    'DOWNSTREAM'             => ['lightsteelblue2','Downstream',            'black',],
    'REGULATORY_REGION'      => ['aquamarine1',    'Regulatory region',     'black',],
    '5PRIME_UTR'             => ['cadetblue3',     "5' UTR",                'black',],
    '3PRIME_UTR'             => ['cadetblue3',     "3' UTR",                'black',],
    'UTR'                    => ['cadetblue3',     'UTR',                   'black',],
    'SPLICE_SITE'            => ['coral',          'Splice site SNP',       'black',],
    'ESSENTIAL_SPLICE_SITE'  => ['coral',          'Essential splice site', 'black',],
    'FRAMESHIFT_CODING'      => ['hotpink',        'Frameshift coding',     'black',],
    'SYNONYMOUS_CODING'      => ['chartreuse2',    'Synonymous coding', 'black',],
    'NON_SYNONYMOUS_CODING'  => ['gold',           'Non-synonymous coding', 'black',],
    'STOP_GAINED'            => ['red',            'Stop gained',           'black',],
    'STOP_LOST'              => ['red',            'Stop lost',             'black',],
    '_'                      => ['gray50',         'Other SNP',           'black',],
  );


  $self->colourSet('regulatory_search_regions',
    'cisred_search'   => [ "plum4" ],
		  );

  $self->colourSet( 'bee_pre_gene',
    'Homology_high'   => [ 'sienna4', 'Homology high' ],
    'Homology_medium' => [ 'sienna3', 'Homology medium' ],
    'Homology_low'    => [ 'sienna2', 'Homology low' ],
    'BeeProtein'      => [ 'blue', 'Aligned Bee Protein' ]
  );

  $self->colourSet( 'marker',
		    ''               => 'magenta',
		    'est'            => 'magenta',
		    'microsatellite' => 'plum4',
		  );

  $self->colourSet( 'alignment',
		    'INTRONIC'                  => 'limegreen',
		    'UPSTREAM'                  => 'mediumspringgreen',  
		    'DOWNSTREAM'                => 'mediumspringgreen',
		    '5PRIME_UTR'                => 'darkorchid1',
		    '3PRIME_UTR'                => 'darkorchid1',
		    'UTR'                       => 'darkorchid1',
		    'NON_SYNONYMOUS_CODING'     => 'red',
		    'FRAMESHIFT_CODING'         => 'orange',
		    'SYNONYMOUS_CODING'         => 'chartreuse3',
                    'STOP_GAINED'               => 'magenta',
                    'STOP_LOST'                 => 'magenta',
		    'INTERGENIC'                => 'gray50',
		    '_'                         => 'gray50',
		    );

  $self->colourSet( 'clones',
    'col_Free'        => 'gray80',
    'col_Phase0Ac'    => 'thistle2',
    'col_Committed'   => 'mediumpurple1',
    'col_PreDraftAc'  => 'plum',
    'col_Redundant'   => 'gray80',
    'col_Reserved'    => 'gray80',
    'col_DraftAc'     => 'gold2',
    'col_FinishAc'    => 'gold3',
    'col_Selected'    => 'green',
    'col_Abandoned'   => 'gray80',
    'col_Accessioned' => 'thistle2',
    'col_Unknown'     => 'gray80',
    'col_'            => 'gray80',
    'lab_Free'        => 'black',
    'lab_Phase0Ac'    => 'black',
    'lab_Committed'   => 'black',
    'lab_PreDraftAc'  => 'black',
    'lab_Redundant'   => 'black',
    'lab_Reserved'    => 'black',
    'lab_Selected'    => 'black',
    'lab_DraftAc'     => 'black',
    'lab_FinishAc'    => 'black',
    'lab_Abandoned'   => 'black',
    'lab_Accessioned' => 'black',
    'lab_Unknown'     => 'black',
    'lab_'            => 'black',
    'col_conflict'    => 'red',
    'col_consistent'  => 'chartreuse3',
    'col_unmapped'    => 'grey80',
    'lab_conflict'    => 'black',
    'lab_consistent'  => 'black',
    'lab_unmapped'    => 'black',
    'bacend'          => 'black',
    'seq_len'         => 'black',
    'fish_tag'        => 'black'
  );

  $self->colourSet( 'alternating',
    'col1' => 'red',
    'col2' => 'orange',
    'lab1' => 'black',
    'lab2' => 'black',
    'bacend' => 'black',
    'seq_len' => 'black'
  );
  $self->colourSet( 'fosmids',
    'col' => 'purple2',
    'lab' => 'black'
  );
  $self->colourSet( 'supercontigs',
    'col1' =>  'darkgreen',
    'col2' => 'green',
    'lab1' => 'white',
    'lab2' => 'black',
  );

  $self->colourSet( 'medaka_gene',
    'hi'         => 'highlight1',
    'superhi'    => 'highlight2',
    'medaka_protein' => [ 'blue', 'Medaka protein' ],
    'gff_prediction' => [ 'darkblue', 'MGP gene' ],
    'protein_coding' => [ 'darkblue', 'MGP gene' ],
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
