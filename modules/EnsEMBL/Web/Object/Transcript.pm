package EnsEMBL::Web::Object::Transcript;

use strict;
use warnings;
no warnings "uninitialized";

use Bio::EnsEMBL::Utils::TranscriptAlleles;
use Bio::EnsEMBL::Variation::Utils::Sequence qw(ambiguity_code variation_class);
use EnsEMBL::Web::Object;
use EnsEMBL::Web::Proxy::Object;
use EnsEMBL::Web::Cache;

use POSIX qw(floor ceil);
use Data::Dumper;
our @ISA = qw(EnsEMBL::Web::Object);

our $MEMD = new EnsEMBL::Web::Cache;

sub _filename {
  my $self = shift;
  my $name = sprintf '%s-transcript-%d-%s-%s',
    $self->species,
    $self->species_defs->ENSEMBL_VERSION,
    $self->get_db,
    $self->Obj->stable_id;
  $name =~ s/[^-\w\.]/_/g;
  return $name;
}

sub availability {
  my $self = shift;
  my $hash = $self->_availability;
  if( $self->Obj->isa('EnsEMBL::Web::Fake') ) { ;
    $hash->{$self->Obj->type} = 1;
  } elsif( $self->Obj->isa('Bio::EnsEMBL::ArchiveStableId') ) { 
    $hash->{'history'}    = 1;
    my $trans_id = $self->param('p') || $self->param('protein'); 
    my $trans = scalar @{$self->Obj->get_all_translation_archive_ids};
    if ( $trans_id || $trans >= 1 ){ $hash->{'history_protein'} =1; }    
  } elsif( $self->Obj->isa('Bio::EnsEMBL::PredictionTranscript') ) {
    $hash->{'either'}     = 1;
  } else {
    my $rows = $self->table_info( $self->get_db, 'stable_id_event' )->{'rows'};
    $hash->{'history'}    = $rows ? 1 : 0;
    $hash->{'history_protein'}    = $rows ? 1 : 0;
    $hash->{'core'}       = $self->get_db eq 'core' ? 1 : 0;
    $hash->{'either'}     = 1;
    $hash->{'transcript'} = 1;
    $hash->{'domain'}     = 1;
    $hash->{'translation'}  = $self->Obj->translation ? 1 : 0;
    $hash->{'strains'}    = $self->species_defs->databases->{'DATABASE_VARIATION'}->{'#STRAINS'} ? 1 : 0;
    $hash->{'history_protein'} = 0 unless $self->translation_object;

 }
  return $hash;
}

sub counts {
  my $self = shift;
  my $sd = $self->species_defs;

  my $key = '::COUNTS::TRANSCRIPT::'.
            $ENV{ENSEMBL_SPECIES}                 .'::'.
            $self->core_objects->{parameters}{db} .'::'.
            $self->core_objects->{parameters}{t}  .'::';

  my $counts;

  $counts = $MEMD->get($key) if $MEMD;

  unless ($counts) {
    return unless $self->Obj->isa('Bio::EnsEMBL::Transcript');
    $counts->{'exons'} = @{$self->Obj()->get_all_Exons};
    $counts->{'evidence'}           = $self->count_supporting_evidence;
    $counts->{'similarity_matches'} = $self->count_similarity_matches;
    $counts->{'oligos'}             = $self->count_oligos;
    $counts->{'prot_domains'}       = $self->count_prot_domains;
    $counts->{'prot_variations'}    = $self->count_prot_variations;
    $counts->{'go'}                 = $self->count_go;
    $MEMD->set($key, $counts, undef, 'COUNTS') if $MEMD;
  }

  return $counts;
}

sub count_prot_domains {
  my $self = shift;
  return 0 unless $self->translation_object;
  my $c = scalar(@{$self->translation_object->get_protein_domains()});
  $c   += map{ @{$self->translation_object->get_all_ProteinFeatures($_)} } qw( tmhmm SignalP ncoils Seg );
  return $c;
}

sub count_prot_variations {
  my $self = shift;
  return 0 unless $self->translation_object;
  my $snps = $self->translation_object->pep_snps();
  my $c = 0;
  foreach my $residue (@$snps){
    next if !$residue->{'allele'};
    $c++;
  }
  return $c;
}

sub count_supporting_evidence_old {
  my $self = shift;
  my $trans = $self->Obj;
  my $evi_count = 0;
  my %c;
  foreach my $evi (@{$trans->get_all_supporting_features}) {
    my $hit_name = $evi->hseqname;
    $c{$hit_name}++;
  }
  #only count transcript_supporting_features for vega database genes
  return scalar(keys(%c)) if ($self->db_type eq 'Vega');
  foreach my $exon (@{$trans->get_all_Exons()}) {
    foreach my $evi (@{$exon->get_all_supporting_features}) {
      my $hit_name = $evi->hseqname;
      $c{$hit_name}++;
    }
  }
  return scalar(keys(%c));
}

sub count_supporting_evidence {
  my $self = shift;
  my $type = $self->get_db;
  my $dbc = $self->database($type)->dbc;
  my %all_evidence;
  my $sql = qq(
      SELECT feature_type, feature_id
        FROM transcript_supporting_feature
       WHERE transcript_id = ?);
  my $sth = $dbc->prepare($sql);
  $sth->execute($self->Obj->dbID);
  while ( my ($type,$feature_id) = $sth->fetchrow_array ) {
    $all_evidence{$type}{$feature_id}++;
  }
  if( $self->db_type ne 'Vega' ){
    my $sql = qq(
    SELECT feature_type, feature_id
      FROM supporting_feature sf, exon_transcript et
     WHERE et.exon_id = sf.exon_id
       AND et.transcript_id = ?);
    my $sth = $dbc->prepare($sql);
    $sth->execute($self->Obj->dbID);
    while (my ($type,$feature_id) = $sth->fetchrow_array) {
      $all_evidence{$type}{$feature_id}++;
    };
  }
  my %names = (
    'dna_align_feature'     => 'dna_align_feature_id',
    'protein_align_feature' => 'protein_align_feature_id'
  );
  my %hits;
  my $dbh = $dbc->db_handle;
  while ( my ($evi_type, $hits) = each %all_evidence) {
    foreach my $hit_id (keys %$hits) {
      my $type = $names{$evi_type};
      my $sql = "SELECT hit_name FROM $evi_type where $type = $hit_id";
      my ($hit_name) = $dbh->selectrow_array($sql);
      $hits{$hit_name}++
    }
  }
  return scalar(keys %hits);
}

sub count_similarity_matches {
    my $self = shift;
    my $type = $self->get_db;
    my $dbc = $self->database($type)->dbc;
    my %all_xrefs;

    #xrefs on the transcript
    my $sql1 = qq(
                SELECT x.display_label, edb.db_name, edb.type, edb.status
                  FROM transcript t, object_xref ox, xref x, external_db edb
                 WHERE t.transcript_id = ox.ensembl_id
                   AND ox.xref_id = x.xref_id
                   AND x.external_db_id = edb.external_db_id
                   AND ox.ensembl_object_type = 'Transcript'
                   AND t.transcript_id = ?);

    my $sth = $dbc->prepare($sql1);
    $sth->execute($self->Obj->dbID);
    while (my ($label,$db_name,$type,$status) = $sth->fetchrow_array) {
	$all_xrefs{'transcript'}{$label} = {'db_name'=>$db_name, 'type'=>$type, 'status'=>$status};
    }

    #xrefs on the translation
    my $sql2 = qq(
                SELECT x.display_label, edb.db_name, edb.type, edb.status
                  FROM translation tl, object_xref ox, xref x, external_db edb
                 WHERE tl.translation_id = ox.ensembl_id
                   AND ox.xref_id = x.xref_id
                   AND x.external_db_id = edb.external_db_id
                   AND ox.ensembl_object_type = 'Translation'
                   AND tl.transcript_id = ?);
    $sth = $dbc->prepare($sql2);
    $sth->execute($self->Obj->dbID);
    while (my ($label,$db_name,$type,$status) = $sth->fetchrow_array) {
	$all_xrefs{'translation'}{$label} = {'db_name'=>$db_name, 'type'=>$type, 'status'=>$status, 'display_label'=>$label};
    }

    #filter out what isn't shown on the 'External References' page
    my @counted_xrefs;
    foreach my $t (qw(transcript translation)) {
	my $xrefs = $all_xrefs{$t};
	while (my ($id,$det) = each %$xrefs) {
	    next unless (grep {$det->{'type'} eq $_} qw(MISC PRIMARY_DB_SYNONYM));

	    #these filters are taken directly from Component::_sort_similarity_links
            #code duplication needs removing, and some of these may well not be needed any more
	    next if ($det->{'status'} eq 'ORTH');                        # remove all orthologs
	    next if (lc($det->{'db_name'}) eq 'medline');                # ditch medline entries - redundant as we also have pubmed
	    next if ($det->{'db_name'} =~ /^flybase/i && $id =~ /^CG/ ); # Ditch celera genes from FlyBase
	    next if ($det->{'db_name'} eq 'Vega_gene');                  # remove internal links to self and transcripts
	    next if ($det->{'db_name'} eq 'Vega_transcript');
	    next if ($det->{'db_name'} eq 'Vega_translation');
	    next if ($det->{'db_name'} eq 'GO');
	    next if ($det->{'db_name'} eq 'OTTP') && ($det->{'display_label'} =~ /^\d+$/); #ignore xrefs to vega translation_ids
	    push @counted_xrefs, $id;
	}
    }
    return scalar @counted_xrefs;
}

sub count_oligos {
  my $self = shift;
  my $type = 'funcgen';
  return unless $self->database('funcgen');
  my $dbc = $self->database($type)->dbc; 
  my $sql = qq(
               SELECT count(distinct(ox.ensembl_id))
                 FROM object_xref ox, xref x, external_db edb
                WHERE ox.xref_id = x.xref_id
                  AND x.external_db_id = edb.external_db_id
                  AND (ox.ensembl_object_type = 'ProbeSet'
                       OR ox.ensembl_object_type = 'Probe')
                  AND x.info_text = 'Transcript'
                  AND x.dbprimary_acc = ?);
  my $sth = $dbc->prepare($sql); 
  $sth->execute($self->Obj->stable_id);
  my $c = $sth->fetchall_arrayref->[0][0];
  return $c;
}

sub count_go {
  my $self = shift;
  return 0 unless $self->Obj->translation;
  my $type = $self->get_db;
  my $dbc = $self->database($type)->dbc;
  my $tl_dbID = $self->Obj->translation->dbID;
  my $sql = qq(
    SELECT count(distinct(x.display_label))
      FROM object_xref ox, xref x, external_db edb
     WHERE ox.xref_id = x.xref_id
       AND x.external_db_id = edb.external_db_id
       AND edb.db_name = 'GO'
       AND ox.ensembl_object_type = 'Translation'
       AND ox.ensembl_id = ?
  );
  my $sth = $dbc->prepare($sql);
  $sth->execute($self->transcript->translation->dbID);
  my $c = $sth->fetchall_arrayref->[0][0];
  return $c;
}

sub get_database_matches {
  my $self = shift;
  my @DBLINKS;
  eval { @DBLINKS = @{$self->Obj->get_all_DBLinks};};
  return \@DBLINKS  || [];
}

sub default_track_by_gene {
  my $self = shift;
  my $db    = $self->get_db;
  my $logic = $self->logic_name;

  my %mappings_db_ln = (
    'core' => {
    map( {( $_, $_ )} qw( 
      genscan fgenesh genefinder snap ciona_snap augustus
      gsc gid slam gws_h gws_s )
    ),
    map( {($_, $_.'_transcript')} qw(
      vectorbase tigr_0_5 species_protein human_one2one_mus_orth mus_one2one_human_orth
      human_one2one_mouse_cow_orth
      cdna_all targettedgenewise human_ensembl_proteins
      medaka_protein gff_prediction oxford_fgu platypus_olfactory_receptors
      genebuilderbeeflymosandswall gsten flybase wormbase
      ensembl sgd homology_low cow_proteins refseq mouse_protein dog_protein horse_protein
      jamboree_cdnas ciona_dbest_ncbi ciona_est_seqc ciona_est_seqn organutan_protein
      ciona_est_seqs ciona_jgi_v1 ciona_kyotograil_2004
 ensembl_projection ensembl_segment fugu_protein lamprey_protein
      ciona_kyotograil_2005 )
    ),
    qw(
      rodent_protein   rprot_transcript
      hox              gsten_transcript
      cyt              gsten_transcript
      ncrna            rna_transcript
      mirna            rna_transcript
      trna             rna_transcript
      rrna             rna_transcript
      snrna            rna_transcript
      snlrna           rna_transcript
      snorna           rna_transcript
      ensembl_ncrna    erna_transcript
      homology_medium  homology_low_transcript
      homology_high    homology_low_transcript
      beeprotein       homology_low_transcript
      otter            vega_transcript
    )
    },
    'otherfeatures' => { qw(
      oxford_fgu oxford_fgu_ext_transcript
      estgene est_transcript ), 
      map( {($_, $_.'_transcript')} qw(
        singapore_est singapore_protein chimp_cdna chimp_est human_est human_cdna
        medaka_transcriptcoalescer medaka_genome_project
      ) )
    },
	'vega' => {
			   otter          => 'evega_transcript',
			   otter_external => 'evega_external_transcript',
			  }
  );

  return lc($logic).'_transcript' if $db eq 'otherfeatures' && lc($logic) =~ /^singapore_(est|protein)$/;
  return $mappings_db_ln{ lc($db) }{ lc( $logic ) } ||
         'ensembl_transcript';
}

sub short_caption {
  my $self = shift;
  return 'Transcript-based displays';
  my( $disp_id ) = $self->display_xref;
  return $self->type_name.': '.($disp_id||$self->stable_id);
}


sub caption           {
  my $self = shift;
  my( $disp_id ) = $self->display_xref;
  my $caption = $self->type_name.': ';
  if( $disp_id ) {
    $caption .= "$disp_id (".$self->stable_id.")";
  } else {
    $caption .= $self->stable_id;
  }
  return $caption;
}

sub type_name         {
  my $self = shift;
  if( $self->Obj->isa( 'EnsEMBL::Web::Fake' ) ){
    return ucfirst($self->Obj->type);
  }
  return $self->species_defs->translate('Transcript');
}
sub source            { my $self = shift; return $self->gene ? $self->gene->source : undef; }
sub stable_id         { my $self = shift; return $self->Obj->stable_id;  }
sub feature_type      { my $self = shift; return $self->Obj->type;       }
sub version           { my $self = shift; return $self->Obj->version;    }
sub logic_name        { my $self = shift; return $self->gene ? $self->gene->analysis->logic_name : $self->Obj->analysis->logic_name; }
sub status            { my $self = shift; return $self->Obj->status;  }
sub display_label        {
  my $self = shift;
  return $self->Obj->analysis->display_label || $self->logic_name;
}
sub coord_system      { my $self = shift; return $self->Obj->slice->coord_system->name; }
sub seq_region_type   { my $self = shift; return $self->coord_system; }
sub seq_region_name   { my $self = shift; return $self->Obj->slice->seq_region_name; }
sub seq_region_start  { my $self = shift; return $self->Obj->start; }
sub seq_region_end    { my $self = shift; return $self->Obj->end; }
sub seq_region_strand { my $self = shift; return $self->Obj->strand; }
sub feature_length    { my $self = shift; return $self->Obj->feature_Slice->length; }

sub get_families {
### Returns a hash of family information and associated (API) Gene objects
## N.B. moved various bits from Translation and Family objects
  my $self = shift;
  my $databases = $self->database('compara') ;

  ## get taxon_id
  my $taxon_id;
  eval {
    my $meta = $self->database('core')->get_MetaContainer();
    $taxon_id = $meta->get_taxonomy_id();
  };
  if( $@ ){ warn($@); return {} }

  ## create family object
  my $family_adaptor;
  eval{ $family_adaptor = $databases->get_FamilyAdaptor };
  if ($@){ warn($@); return {} }
  my $families = [];
  my $translation = $self->translation_object;
  eval{
    $families = $family_adaptor->fetch_by_Member_source_stable_id('ENSEMBLPEP',$translation->stable_id)
  };

  ## munge data
  my $family_hash = {};
  if (@$families) {
    my $ga = $self->database( 'core' )->get_GeneAdaptor;
    foreach my $family( @$families ){
      $family_hash->{$family->stable_id}  =
        {
        'description' => $family->description,
        'count' => $family->Member_count_by_source_taxon('ENSEMBLGENE', $taxon_id),
        'genes' => [ map { $ga->fetch_by_stable_id( $_->[0]->stable_id ) } 
                    @{$family->get_Member_Attribute_by_source_taxon('ENSEMBLGENE', $taxon_id) || []} ],
        };
    }
  }
  return $family_hash;
}

#almost certainly deprecated
sub get_interpro {
  my $self = shift;
  if (my $translation = $self->translation_object) {
	  my $hash = $translation->get_interpro_links( $self->transcript );
	  return unless (%$hash);
		
	  my $interpro;
	  for my $accession (keys %$hash){
		  my $data = {};
		  $data->{'link'} = $self->get_ExtURL_link( $accession, 'INTERPRO',$accession);
		  $data->{'desc'} = $hash->{$accession};
		  $interpro->{$accession} = $data;
	  }
	  return $interpro;
  }
  return;
}

sub get_domain_genes {
  my $self = shift;
  my $a = $self->gene ? $self->gene->adaptor : $self->Obj->adaptor;
  return $a->fetch_all_by_domain($self->param('domain')); 
}


sub get_alternative_locations {
  my $self = shift;
  my @alt_locs = map { [ $_->slice->seq_region_name, $_->start, $_->end, $_->slice->coord_system->name, ] }
                 @{$self->Obj->get_all_alt_locations};
  return \@alt_locs;
}

sub get_Slice {
  my( $self, $context, $ori ) = @_;

  my $db  = $self->get_db ;
  my $gene = $self->gene;   ### should this be called on gene?
  my $slice = $gene->feature_Slice;
  if( $context =~ /(\d+)%/ ) {
    $context = $slice->length * $1 / 100;
  }
  if( $ori && $slice->strand != $ori ) {
    $slice = $slice->invert();
  }
  return $slice->expand( $context, $context );
}

#-- Transcript SNP view -----------------------------------------------

sub get_transcript_Slice {

  ### TSV
  my $count = 0;
  my( $self, $context, $ori ) = @_; 
  my $db  = $self->get_db ;
  my $slice = $self->Obj->feature_Slice; 
  if( $context =~ /(\d+)%/ ) {
    $context = $slice->length * $1 / 100;
  }
  if( $ori && $slice->strand != $ori ) {
    $slice = $slice->invert(); 
  }
  return $slice->expand( $context, $context );
}



sub get_transcript_slices {

 ### TSV
 ### Args        : Web user config, arrayref of slices (see example)
 ### Example     : my $slice = $object->get_Slice( $wuc, ['context', 'normal', '500%'] );
 ### Description : Gets slices for transcript sample view
 ### Returns  hash ref of slices

  my( $self, $slice_config ) = @_;
  # name, normal/munged, zoom/extent
  if( $slice_config->[1] eq 'normal') {
    my $slice = $self->get_transcript_Slice( $slice_config->[2], 1 );
    return [ 'normal', $slice, [], $slice->length ];
  }
  else {
    return $self->get_munged_slice( $slice_config->[0], $slice_config->[2], 1 );
  }
}

sub get_munged_slice {
 ### TSV/TSE
  my $self = shift;
  my $config_name = shift;
  my $master_config = $self->image_config_hash( $config_name );
  $master_config->{'_draw_single_Transcript'} = $self->stable_id;

  my $slice = $self->get_transcript_Slice( @_ );  #pushes it onto forward strand, expands if necc.
  my $length = $slice->length();
  my $munged  = '0' x $length;  # Munged is string of 0, length of slice

  # Context is the padding around the exons in the fake slice
  my $extent = $self->param( 'context' );

  my @lengths;
  if( $extent eq 'FULL' ) {
    $extent = 1000;
    @lengths = ( $length );
  }
  else {
    foreach my $exon (@{$self->Obj->get_all_Exons()}) {		
      my $START    = $exon->start - $slice->start + 1 - $extent;
      my $EXON_LEN = $exon->end-$exon->start + 1 + 2 * $extent;
      # Change munged to 1 where there is exon or extent (i.e. flank)
      substr( $munged, $START-1, $EXON_LEN ) = '1' x $EXON_LEN;
    }
    @lengths = map { length($_) } split /(0+)/, $munged;
  }
  ## @lengths contains the sizes of gaps and exons(+- context)

  $munged = undef;

  my $collapsed_length = 0;
  my $flag = 0;
  my $subslices = [];
  my $pos = 0;

  foreach( @lengths , 0) {
    if ( $flag = 1-$flag ) {
      push @$subslices, [ $pos+1, 0, 0 ] ;
      $collapsed_length += $_;
    } else {
      $subslices->[-1][1] = $pos;
    }
    $pos+=$_;
  }

## compute the width of the slice image within the display
  my $PIXEL_WIDTH =
    $self->param('image_width') -
        ( $master_config->get_parameter( 'label_width' ) || 100 ) -
    3 * ( $master_config->get_parameter( 'margin' )      ||   5 );

## Work out the best size for the gaps between the "exons"
  my $fake_intron_gap_size = 11;
  my $intron_gaps  = ((@lengths-1)/2);
  if( $intron_gaps && ( $intron_gaps * $fake_intron_gap_size > $PIXEL_WIDTH * 0.75 ) ) {
     $fake_intron_gap_size = int( $PIXEL_WIDTH * 0.75 / $intron_gaps );
  }

## Compute how big this is in base-pairs
  my $exon_pixels  = $PIXEL_WIDTH - $intron_gaps * $fake_intron_gap_size;
  my $scale_factor = $collapsed_length / $exon_pixels;
  my $padding      = int($scale_factor * $fake_intron_gap_size) + 1;
  $collapsed_length += $padding * $intron_gaps;

## Compute offset for each subslice
  my $start = 0;
  foreach(@$subslices) {
    $_->[2] = $start - $_->[0];
    $start += $_->[1]-$_->[0]-1 + $padding;
  }

  return [ 'munged', $slice, $subslices, $collapsed_length ];

}

sub valids {
  ### TSV
  ### Description: Valid user selections
  ### Returns hashref

  my $self = shift;
  my %valids = ();    ## Now we have to create the snp filter....
  foreach( $self->param() ) {
    $valids{$_} = 1 if $_=~/opt_/ && $self->param( $_ ) eq 'on';
  }
  return \%valids;
}

sub extent {
 ### TSV
  my $self = shift;
  my $extent = $self->param( 'context' );
  if( $extent eq 'FULL' ) {
    $extent = 1000;
  }
  return $extent;
}


sub getFakeMungedVariationsOnSlice {

 ### TSV

   my( $self, $slice, $subslices ) = @_;
  my $sliceObj = EnsEMBL::Web::Proxy::Object->new(
        'Slice', $slice, $self->__data
       );

  my ($count_snps, $filtered_snps, $context_count) = $sliceObj->getFakeMungedVariationFeatures($subslices);
  $self->__data->{'sample'}{"snp_counts"} = [$count_snps, scalar @$filtered_snps];
 return ($count_snps, $filtered_snps, $context_count);
}

sub getAllelesConsequencesOnSlice {
  my( $self, $sample, $key, $sample_slice ) = @_;
 
  # If data already calculated, return
  my $allele_info = $self->__data->{'sample'}{$sample}->{'allele_info'};  
  my $consequences = $self->__data->{'sample'}{$sample}->{'consequences'};    
  return ($allele_info, $consequences) if $allele_info && $consequences;
  
  # Else
  my $valids = $self->valids;  

  # Get all features on slice
  my $allele_features = $sample_slice->get_all_AlleleFeatures_Slice || []; 
  return ([], []) unless @$allele_features;

  my @filtered_af =
    sort {$a->[2]->start <=> $b->[2]->start}

    # Rm many filters as not applicable to Allele Features
    # [ fake_s, fake_e, AF ]   Grep features to see if the area valid

    # [ fake_s, fake_e, AF ]   Filter our unwanted classes
    grep { $valids->{'opt_'.$self->var_class($_->[2])} }

    # [ fake_s, fake_e, AF ]   Filter our unwanted sources
     # grep { $valids->{'opt_'.lc($_->[2]->source) }  }
    grep { scalar map { $valids->{'opt_'.lc($_)}?1:() } @{$_->[2]->get_all_sources()}  }

    # [ fake_s, fake_e, AlleleFeature ]   Filter out AFs not on munged slice...
     map  { $_->[1]?[$_->[0]->start+$_->[1],$_->[0]->end+$_->[1],$_->[0]]:() } 
       # [ AF, offset ]   Map to fake coords.   Create a munged version AF
       map  { [$_, $self->munge_gaps( $key, $_->start, $_->end)] }
	 @$allele_features;
  return ([], []) unless @filtered_af;

  # consequences of AlleleFeatures on the transcript
  my @slice_alleles = map { $_->[2]->transfer($self->Obj->slice) } @filtered_af;

  $consequences =  Bio::EnsEMBL::Utils::TranscriptAlleles::get_all_ConsequenceType($self->Obj, \@slice_alleles);
  return ([], []) unless @$consequences;

  my @valid_conseq;
  my @valid_alleles;

  foreach (sort {$a->start <=> $b->start} @$consequences ){  # conseq on our transcript
    my $last_af =  $valid_alleles[-1];
    my $allele_feature;
    if ($last_af && $last_af->[2]->start eq $_->start) {
      $allele_feature = $last_af;
    }
    else {
      $allele_feature = shift @filtered_af;
    }
      next unless $allele_feature;

    foreach my $type (@{ $_->type || [] }) {
      next unless $valids->{ 'opt_'.lc($type) } ;
      warn "Allele undefined for ", $allele_feature->[2]->variation_name."\n" unless $allele_feature->[2]->allele_string;

      # [ fake_s, fake_e, SNP ]   Filter our unwanted consequences
      push @valid_conseq,  $_ ;
      push @valid_alleles, $allele_feature;
      last;
    }
  }
  $self->__data->{'sample'}{$sample}->{'consequences'} = \@valid_conseq || [];
  $self->__data->{'sample'}{$sample}->{'allele_info'}  = \@valid_alleles || [];
  return (\@valid_alleles, \@valid_conseq);
}


sub var_class {

 ### TSV

   my ($self, $allele) = @_;
  my $allele_string = join "|", $allele->ref_allele_string(), $allele->allele_string;

 return &variation_class($allele_string);
}

sub ambig_code {

 ### TSV

   my ($self, $allele) = @_;
  my $allele_string = join "|", $allele->ref_allele_string(), $allele->allele_string;

 return &ambiguity_code($allele_string);
}


sub get_samples {
  ### TSV
  ### Arg (optional) : type string
  ###  -"default": returns samples checked by default
  ###  -"display": returns samples for dropdown list with default ones first
  ### Description: returns selected samples (by default)
  ### Returns type list

  my $self    = shift;
  my $options = shift;
  my $params  = shift;

  my $vari_adaptor = $self->Obj->adaptor->db->get_db_adaptor('variation');
  
  unless ($vari_adaptor) {
    warn "ERROR: Can't get variation adaptor";
    return ();
  }

  my $individual_adaptor = $vari_adaptor->get_IndividualAdaptor;
 
  if ($options eq 'default') {
    return sort @{$individual_adaptor->get_default_strains};
  }

  my %default_pops; 
  map {$default_pops{$_} = 1 } @{$individual_adaptor->get_default_strains};
 
  my %db_pops;
  
  foreach (sort @{$individual_adaptor->get_display_strains}) {
   next if $default_pops{$_}; 
    $db_pops{$_} = 1;
  }

  my %configured_pops = (%default_pops, %db_pops);

  my $view_config = $self->get_viewconfig;
  
  my @pops;
  
  if ($options eq 'display') { # return list of pops with default first
    return (sort keys %default_pops), (sort keys %db_pops); 
  } elsif ($self->param('strain')) { # This elsif allows a user to manually add in an optional strain. Use format strain=xxx:on. Only occurs when tweak URL
    foreach my $sample ($self->param('strain')) {
      next unless $sample =~ /(.*):(\w+)/;
      
      $view_config->set("opt_pop_$1", $2, 1);
      push @pops, $1 if $2 eq 'on';
    }
  } elsif ($params) {
    foreach my $sample (sort keys %$params) {      
      push @pops, $sample if $configured_pops{$sample};
    }
  } else { # get configured samples 
    foreach my $sample (sort $view_config->options) { 
      next unless $sample =~ s/opt_pop_//;  
      next unless $view_config->get("opt_pop_$sample") eq 'on'; 
      
      push @pops, $sample if $configured_pops{$sample};
    }
  }
  
  return sort @pops;
}


sub get_source {

  ### TSV

  my $self = shift;
  my $default = shift;

  my $vari_adaptor = $self->Obj->adaptor->db->get_db_adaptor('variation');
  unless ($vari_adaptor) {
    warn "ERROR: Can't get variation adaptor";
    return ();
  }

  my $return;
  if ($default) {
    $return = $vari_adaptor->get_VariationAdaptor->get_default_source();
  }
  return $return if $return;	
  return $vari_adaptor->get_VariationAdaptor->get_all_sources();

}

sub munge_gaps {
 
 ### TSV and SE

  my( $self, $slice_code, $bp, $bp2  ) = @_;
  my $subslices = $self->__data->{'slices'}{ $slice_code }[2];
  unless ($subslices) {
    my $tmp =  $self->get_transcript_slices( [ $slice_code, 'munged', $self->extent ] );
    $subslices = $tmp->[2];
  }
  foreach( @$subslices ) {
    if( $bp >= $_->[0] && $bp <= $_->[1] ) {
      my $return =  defined($bp2) && ($bp2 < $_->[0] || $bp2 > $_->[1] ) ? undef : $_->[2];
      return $return;
    }
  }
  return undef;
}

sub munge_gaps_split {

 ### TSV

   my( $self, $slice_code, $bp, $bp2, $obj_ref  ) = @_;

  my $subslices = $self->__data->{'slices'}{ $slice_code }[2];
  my @return = ();
  foreach( @$subslices ) {
    my($st,$en);
    if( $bp < $_->[0] ) {
      $st = $_->[0];
    } elsif( $bp <= $_->[1] ) {
      $st = $bp;
    } else {
      next;
    }
    if( $bp2 > $_->[1] ) {
      $en = $_->[1];
    } elsif( $bp2 >= $_->[0] ) {
      $en = $bp2;
    } else {
      last;
    }
    if( defined( $st ) && defined( $en ) ) {
      push @return, [$st+$_->[2],$en+$_->[2], $obj_ref ];
    }
  }
  return @return;
}

sub read_coverage {
 
 ### TSV

  my ( $self, $sample, $sample_slice) = @_;

  my $individual_adaptor = $self->Obj->adaptor->db->get_db_adaptor('variation')->get_IndividualAdaptor; 
  my $sample_objs = $individual_adaptor->fetch_all_by_name($sample);
  return ([],[]) unless @$sample_objs; 
  my $sample_obj = $sample_objs->[0]; 

  my $rc_adaptor = $self->Obj->adaptor->db->get_db_adaptor('variation')->get_ReadCoverageAdaptor; 
  my $coverage_level = $rc_adaptor->get_coverage_levels; 
  my $coverage_obj = $rc_adaptor->fetch_all_by_Slice_Sample_depth($sample_slice, $sample_obj); 
  return ($coverage_level, $coverage_obj);
}

sub munge_read_coverage {

 ### TSV

   my ($self, $coverage_obj ) = @_;
  my @filtered_obj =
    sort { $a->[2]->start <=> $b->[2]->start }
    map  { $self->munge_gaps_split( "tsv_transcript", $_->start, $_->end, $_ ) }
    @$coverage_obj;
  return  \@filtered_obj;
}

sub generate_query_hash {

 ### TSV

   my $self = shift;
  return {
	  'transcript' => $self->stable_id,
	  'db'         => $self->get_db,
	 };
}


#-- end transcript SNP view ----------------------------------------------


=head2 transcript

 Arg[1]        : none
 Example     : my $ensembl_transcript = $transdata->transcript
 Description : Gets the ensembl transcript stored on the transcript data object
 Return type : Bio::EnsEmbl::Transcript

=cut

sub transcript { return $_[0]->Obj; }

=head2 gene

 Arg[1]      : Bio::EnsEMBL::Gene - (OPTIONAL)
 Example     : $ensembl_gene = $transdata->gene
               $transdata->gene( $ensembl_gene )
 Description : returns the ensembl gene object if it exists on the transcript object
                else it creates it from the core-api. Alternativly a ensembl gene object
                reference can be passed to the function if the transcript is being created
                via a gene and so saves on creating a new gene object.
 Return type : Bio::EnsEMBL::Gene

=cut

sub gene{
  my $self = shift ;
  if(@_) {
    $self->{'_gene'} = shift;
  } elsif( !$self->{'_gene'} ) {
    eval {
      my $db = $self->get_db() ;
      my $adaptor_call = $self->param('gene_adaptor') || 'get_GeneAdaptor';
      my $GeneAdaptor = $self->database($db)->$adaptor_call;
      my $Gene = $GeneAdaptor->fetch_by_transcript_stable_id($self->stable_id);   
      $self->{'_gene'} = $Gene if ($Gene);
    };
  }
  return $self->{'_gene'};
}

=head2 translation_object

 Arg[1]      : none
 Example     : $ensembl_translation = $transdata->translation
 Description : returns the ensembl translation object if it exists on the transcript object
                else it creates it from the core-api.
 Return type : Bio::EnsEMBL::Translation

=cut

sub translation_object {
  my $self = shift;  
  unless( exists( $self->{'data'}{'_translation'} ) ){
    my $translation = $self->transcript->translation;
    if( $translation ) {
      my $translationObj = EnsEMBL::Web::Proxy::Object->new(
        'Translation', $translation, $self->__data
      );
      $translationObj->gene($self->gene);
      $translationObj->transcript($self->transcript);
      $self->{'data'}{'_translation'} = $translationObj;
    } else {
      $self->{'data'}{'_translation'} = undef;
    }
  }
  return $self->{'data'}{'_translation'};
}

=head2 db_type

 Arg[1]      : none
 Example     : $type = $transdata->db_type
 Description : Gets the db type of ensembl feature
 Return type : string
                a db type (EnsEMBL, Vega, EST, etc.)

=cut

sub db_type{
  my $self = shift;
  my $db   = $self->get_db;
  my %db_hash = qw(
    core    Ensembl
    otherfeatures     EST
    vega    Vega
  );
  return  $db_hash{$db};
}


#----------------------------------------------------------------------

=head2 gene_type

  Arg [1]   : 
  Function  : Pretty-print type of gene; Ensembl, Vega, Pseudogene etc
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub gene_type {
  my $self = shift;
  my $db = $self->get_db;
  my $type = '';
  if( $db eq 'core' ){
    $type = $self->display_label;
    $type ||= $self->db_type;
  } else {
    $type = $self->display_label;
    $type ||= $self->db_type;
  }
  $type ||= $db;
  if( $type !~ /[A-Z]/ ){ $type = ucfirst($type) } #All lc, so format
  return $type;
}

sub gene_stat_and_biotype {
  my $self = shift;
  my $db = $self->get_db;
  my $type = '';
  if( $db eq 'core' ){
    $type = ucfirst(lc($self->gene->status))." ".ucfirst(lc($self->gene->biotype));
    $type =~ s/_/ /;
    $type ||= $self->db_type;
  } elsif ($db eq 'vega') {
    my $biotype = ($self->gene->biotype eq 'tec') ? uc($self->gene->biotype) : ucfirst(lc($self->gene->biotype));
    $type = ucfirst(lc($self->gene->status))." $biotype";
    $type =~ s/_/ /g;
    $type =~ s/unknown //i;
    return $type;
  } else {
    $type = $self->logic_name;
  }
  $type ||= $db;
  if( $type !~ /[A-Z]/ ){ $type = ucfirst($type) } #All lc, so format
  $type =~ s/^Est/EST/;
  return $type;
}

#----------------------------------------------------------------------

=head2 analysis

  Arg [1]   : 
  Function  : Returns the analysis object from either the gene or transcript
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub analysis {
  my $self = shift;
  if( $self->gene ){ return $self->gene->analysis  } # for "real" gene objects
  else { return $self->transcript->analysis } # for things like genscans
}


=head2 modified

 Description: DEPRECATED - Genes no longer have a modified attribute

=cut

sub modified {
  warn "DEPRECATED - Genes no longer have a modified attribute";
  return undef;
}

=head2 get_author_name

 Arg[1]      : none
 Example     : $author = $transcriptdata->get_author_name
 Description : Gets the author of an annotated gene
 Return type : String
               The author name

=cut

sub get_author_name {
    my $self = shift;
    my $attribs = $self->gene->get_all_Attributes('author');
    if (@$attribs) {
        return $attribs->[0]->value;
    } else {
        return undef;
    }
}

=head2 get_author_email

 Arg[1]      : String
               Email address
 Example     : $email = $transcriptdata->get_author_email
 Description : Gets the author's email address of an annotated gene
 Return type : String
               The author's email address

=cut

sub get_author_email {
    my $self = shift;
    my $attribs = $self->gene->get_all_Attributes('author_email');
    if (@$attribs) {
        return $attribs->[0]->value;
    } else {
        return undef;
    }
}

sub transcript_type {
    my $self = shift;
    my $db = $self->get_db;
    my $type = '';
    if (ref($self->Obj) eq 'Bio::EnsEMBL::PredictionTranscript') {
	return '';
    }
    elsif( $db ne 'core' ){
	return '';
    }
    else {
	$type = ucfirst(lc($self->Obj->status)).' '.(lc($self->Obj->biotype));
	$type =~ s/_/ /g;
	return $type;
    }
}

sub transcript_class {
    my $self = shift;
    my $class = ucfirst(lc($self->Obj->status)).' '.ucfirst(lc($self->Obj->biotype));
    $class =~ s/_/ /g;
    $class =~ s/unknown//i;
    return $class;
}

=head2 trans_description

 Arg[1]      : none
 Example     : $description = $transdata->trans_description
 Description : Gets the description from the GENE object (no description on transcript)
 Return type : string
                The description of a feature

=cut

sub trans_description {
  my $gene = $_[0]->gene;
  my %description_by_type = ( 'bacterial_contaminant' => "Probable bacterial contaminant" );
  if( $gene ){
    return $gene->description() || $description_by_type{ $gene->biotype } || 'No description';
  }
  return 'No description';
}

=head2 get_prediction_method

 Arg[1]      : none
 Example     : $prediction_method = $transdata->get_prediction_method
 Description : Gets the prediction method for a transcript
 Return type : string The prediction method of a feature

=cut

sub get_prediction_method {
  my $self = shift ;
  my $db = $self->get_db() ;
  my $logic_name = $self->logic_name || '';

  my $prediction_text;
  if( $logic_name ){
    my $confkey = "ENSEMBL_PREDICTION_TEXT_".uc($logic_name);
    $prediction_text = $self->species_defs->$confkey;
  }
  unless( $prediction_text ) {
    my $confkey = "ENSEMBL_PREDICTION_TEXT_".uc($db);
    $prediction_text   = $self->species_defs->$confkey;
  }
  return($prediction_text);
}

=head2 display_xref

 Arg[1]      : none
 Example     : ($xref_display_id, $xref_dbname) = $transdata->display_xref
 Description : returns a pair value of xref display_id and xref dbname  (BRCA1, HUGO)
 Return type : a list

=cut

sub display_xref {
  my $self = shift;
  return $self->transcript->name if $self->transcript->isa('EnsEMBL::Web::Fake');
  return unless $self->transcript->can('display_xref');
  my $trans_xref = $self->transcript->display_xref();
  return ( $trans_xref->display_id, $trans_xref->dbname, $trans_xref->primary_id, $trans_xref->db_display_name ) if $trans_xref;
}

=head2 get_contig_location

 Arg[1]      : none
 Example     : ($chr, $start, $end, $contig, $contig_start) = $transdata->get_genomic_location
 Description : returns the location of a transcript. Returns a list
                chromosome, chr_start, chr_end, contig, contig_start
 Return type : a list

=cut

sub get_contig_location {
  my $self = shift;
  my ($pr_seg) = @{$self->Obj->project('seqlevel')};
  return undef unless $pr_seg;
  return (
    $self->neat_sr_name( $pr_seg->[2]->coord_system->name, $pr_seg->[2]->seq_region_name ),
    $pr_seg->[2]->seq_region_name,
    $pr_seg->[2]->start
  );
}

=head2 get_similarity_hash

 Arg[1]      : none
 Example     : @similarity_matches = $transdata->get_similarity_hash
 Description : Returns an arrayref of hashes conating similarity matches
 Return type : an array ref

=cut

sub get_similarity_hash{
  my($self,$recurse) = @_;  

  $recurse = 1 unless defined $recurse;
  my $DBLINKS;
  eval { $DBLINKS = $recurse ? $self->transcript->get_all_DBLinks
                             : $self->transcript->get_all_DBEntries; };
  warn ("SIMILARITY_MATCHES Error on retrieving gene DB links $@") if ($@);
  return $DBLINKS  || [];
}

sub get_gene_similarity_hash{
    my($self,$recurse) = @_;
    $recurse = 1 unless defined $recurse;
    my $DBLINKS;
    eval { $DBLINKS = $recurse ? $self->gene->get_all_DBLinks
	       : $self->gene->get_all_DBEntries; };
    warn ("SIMILARITY_MATCHES Error on retrieving gene DB links $@") if ($@);
    return $DBLINKS  || [];
}

=head2 get_go_list

 Arg[1]      : none
 Example     : @go_list = $transdata->get_go_list
 Description : Returns a hashref conating go links
 Return type : a hashref

=cut

sub get_go_list {
  my $self = shift ;
  my $trans = $self->transcript;
  my $goadaptor = $self->get_databases('go')->{'go'};# || return {};
  my @dblinks = @{$trans->get_all_DBLinks};
  my @goxrefs = grep{ $_->dbname eq 'GO' } @dblinks;

  my %go_hash;
  my %hash;
  foreach my $goxref ( sort{ $a->display_id cmp $b->display_id } @goxrefs ){
    my $go = $goxref->display_id;
    my $info_text;
    if($goxref->info_type eq 'PROJECTION'){
	$info_text= $goxref->info_text; 
    }
    
    my $evidence = '';
    if( $goxref->isa('Bio::EnsEMBL::GoXref') ){
	$evidence = join( ", ", @{$goxref->get_all_linkage_types } ); 
    }
    my ($go2) = $go=~/GO:0*(\d+)/;
    my $term;
    next if exists $hash{$go2};
    $hash{$go2}=1;

    my $term_name;
    if( $goadaptor ){
      my $term;
      eval{ $term = $goadaptor->get_term({acc=>$go2}) };
      if($@){ warn( $@ ) }
      $term_name = $term ? $term->name : '';
    }
    $term_name ||= $goxref->description || '';
    $go_hash{$go} = [$evidence, $term_name, $info_text];
  }
  return \%go_hash;
}

=head2 get_oligo_probe_data
 Arg[1]       : none 
 Example      : %probe_data  = %{$transdate->get_oligo_probe_data}
 Description  : Retrieves all oligo probe releated DBEntries for this transcript
 Returntype   : Hashref of probe info

=cut 

sub get_oligo_probe_data {
  my $self = shift; 
  my $fg_db = $self->database('funcgen'); 
  my $probe_adaptor = $fg_db->get_ProbeAdaptor(); 
  my @transcript_xrefd_probes = @{$probe_adaptor->fetch_all_by_external_name($self->stable_id)};
  my $probe_set_adaptor = $fg_db->get_ProbeSetAdaptor(); 
  my @transcript_xrefd_probesets = @{$probe_set_adaptor->fetch_all_by_external_name($self->stable_id)};
  my %probe_data;

  ## First retrieve data for Probes linked to transcript
  foreach my $probe (@transcript_xrefd_probes) {
    my ($array_name, $probe_name, $vendor, @info);
    my @names = @{$probe->get_all_complete_names};
    foreach (@names){
      ($array_name, $probe_name) = split (/:/, $_); 
    }
    my %arrays = %{$probe->get_names_Arrays};
    foreach (values %arrays) {
      $vendor =  $_->vendor;
    }
    my @dbentries = @{$probe->get_all_Transcript_DBEntries};
    foreach my $entry (@dbentries) {
      @info = ('probe', $entry->linkage_annotation);
    }
 
    my $key = $vendor ." ". $array_name;
    if ($vendor eq $array_name) {$key = $vendor;}

    if (exists $probe_data{$key}){
      my %probes = %{$probe_data{$key}};
      $probes{$probe_name} = \@info;
      $probe_data{$key} = \%probes;
    } else {
      my %probes = ($probe_name, \@info);
      $probe_data{$key} = \%probes;
    }
  }

  ## Next retrieve same information for probesets linked to transcript
  foreach my $probeset (@transcript_xrefd_probesets) {
    my ($array_name, $probe_name, $vendor, @info);

    $probe_name =  $probeset->name;
    my @arrays = @{$probeset->get_all_Arrays};
    foreach ( @arrays) {
     $vendor =  $_->vendor;
     $array_name = $_->name;
    }
    my @dbentries = @{$probeset->get_all_Transcript_DBEntries};
    foreach my $entry (@dbentries) {
      @info = ('pset', $entry->linkage_annotation); 
    }
    my $key = $vendor ." ". $array_name;
   # my @values = ($probe_name, $additiona);
    if (exists $probe_data{$key}){
      my %probes = %{$probe_data{$key}};
      $probes{$probe_name} = \@info;
      $probe_data{$key} = \%probes;
    } else {
      my %probes = ($probe_name, \@info);
      $probe_data{$key} = \%probes;
    }
  }

  $self->sort_oligo_data(\%probe_data); 
}


sub sort_oligo_data {
  my ( $self, $data) = @_; 
  my %probe_data = %$data;

  foreach my $array (sort keys %probe_data) {
    my $text;
    my $p_type = 'pset';

    my %data = %{$probe_data{$array}};
    foreach my $probe_name (sort keys %data) {
      $text .= qq(<div class="multicol">);
      my($p_type, $probe_text )= @{$data{$probe_name}};
      $text  .= qq($probe_name);
      if ($probe_text) { $text .= '<span class="small"> ['.$probe_text .']</span>'; }
      my $url = $self->_url({
        'type'   => 'Location',
        'action' => 'Genome',
        'id'     => $probe_name,
        'ftype'  => 'ProbeFeature',
        'fdb'    => 'funcgen',
        'ptype'  => $p_type, 
      });
      $text .= qq(  [<a href="$url">view all locations</a>]</div>);
    }
    push @{$self->__data->{'links'}{'ARRAY'}}, [ $array || $array, $text ]
  }
}

=head2 get_supporting_evidence
 Arg[1]      : none
 Example     : @supporting_evidence = $transdata->get_supporting_evidence
 Description : Returns a hashref conating supporting evidence hash as follows
 Return type : a hashref

=cut

sub get_supporting_evidence { ## USED by alignview as well!
  my $self    = shift;
  my $transid = $self->stable_id;
  my $db      =  $self->get_db;
  my $dbh     = $self->database($db);

  return undef if $self->transcript->isa('Bio::EnsEMBL::PredictionTranscript');
    # No evidence for PredictionTranscripts!

  # hack because can get exon supp evidence if transformed and
  # need the main transcript transformed for rest of page
  my $transcript_adaptor = $dbh->get_TranscriptAdaptor() ; 
  my $trans              = $transcript_adaptor->fetch_by_stable_id( $transid ); 
#  warn $self->Obj;
  $self->__data->{'_SE_trans'} = $trans ;
  my @dl_seq_list;
  my $show;
  my $exon_count=0;   # count the number of exons
  my $evidence = {
    'transcript' => { 'ID' => $self->stable_id, 'db' => $db, 'exon_count'=> 0, },
    'hits'      => {},
  };

  # get transcript supporting evidence
  my %trans_evidence = map { $_->dbID => 1 } @{ $trans->get_all_supporting_features };
  
  # Retrieve/make Exon data objects    
  foreach my $exonData ( @{$trans->get_all_Exons} ){
    $exon_count++;
    my $supporting_features;
    eval {
      $supporting_features = $exonData->get_all_supporting_features;
    };    
    if($@){
      warn("Error fetching Protein_Align_Feature: $@");
      return;
    } else {
      foreach my $this_feature (@{$supporting_features}) {
        my $dl_seq_name = $this_feature->hseqname;

        # skip evidence for this exon if it doesn't support this particular
        # transcript (vega only)

	if ( ($self->species_defs->ENSEMBL_SITE_NAME eq 'Vega') || ($self->logic_name =~ /otter/) ) {
	  next unless ($trans_evidence{$this_feature->dbID});
	}

        my $no_version_no;
        if($dl_seq_name =~ /^[A-Z]{2}\.\d+/i) {
          $no_version_no = $dl_seq_name;
        } else {
          $no_version_no = $dl_seq_name=~/^(\w+)\.\d+/ ? $1 : $dl_seq_name;
        }
        if( $no_version_no =~ /^JAM_(.*)$/ ) {
          $evidence->{ 'hits' }{$dl_seq_name}{'link'} = $self->get_ExtURL('XT_JAM',$1);
        } else {
          $evidence->{ 'hits' }{$dl_seq_name}{'link'} = $self->get_ExtURL('SRS_FALLBACK',$no_version_no);
        }
        $evidence->{ 'hits' }{$dl_seq_name}{'exon_ids'}[$exon_count - 1 ] = $exonData->stable_id;
        if( !defined( $evidence->{ 'hits' }{$dl_seq_name}{'datalib'} ) ) {
      # Create array to hold the feature top-score for each exon
          $evidence->{ 'hits' }{$dl_seq_name}{'scores'} = [];          
          push @dl_seq_list, $dl_seq_name ; # list to get descriptions in one go 
      # Hold the data library that this feature is from
          ($evidence->{ 'hits' }{$dl_seq_name}{'datalib'} = ( $this_feature->analysis ? $this_feature->analysis->logic_name : '') ) =~ s/swir/Swir/;
          $show = 1; 
        }               
        # Compare to see if this is the top-score
        if( $this_feature->score > $evidence->{ 'hits' }{$dl_seq_name}{'scores'}[$exon_count - 1 ] ) {      
      # Adjust the top-score for this hit sequence
      # Subtract old score for this exon and add new score
          $evidence->{ 'hits' }{$dl_seq_name}{'total_score'} = 
          $evidence->{ 'hits' }{$dl_seq_name}{'total_score'} - 
          $this_feature->score > $evidence->{ 'hits' }{$dl_seq_name}{'scores'}[$exon_count - 1 ] + $this_feature->score;
      
      # Keep this new top-score                   
          $evidence->{ 'hits' }{$dl_seq_name}{'scores'}[$exon_count - 1] =$this_feature->score;                   
          if( $this_feature->score > $evidence->{ 'hits' }{$dl_seq_name}{'top_score'} ) {
            $evidence->{ 'hits' }{$dl_seq_name}{'top_score'} = $this_feature->score;
          }
        } # END if 
        $evidence->{ 'hits' }{$dl_seq_name}{'num_exon_hits'} = 0;
        for my $each_score (@{$evidence->{ 'hits' }{$dl_seq_name}{'scores'}}){
          $evidence->{ 'hits' }{$dl_seq_name}{'num_exon_hits'}++ if ($each_score);
        }
      }# END foreach $this_feature  
    }
  } # END foreach $this_exon
  return unless $show;
  $evidence->{ 'transcript' }{'exon_count'} = $exon_count;
  my $indexer = new EnsEMBL::Web::ExtIndex( $self->species_defs ); 
  my $result_ref;
  eval {
    $result_ref = $indexer->get_seq_by_id({ DB  => 'EMBL', ID  => (join " ", (sort @dl_seq_list) ), OPTIONS => 'desc' });
  };
  my $keyword =  $result_ref || [] ;
  my $i = 0 ;
  for my $id (sort  @dl_seq_list ){
    my $description = $keyword->[$i];
    $description =~ s/^DE\s+//g ;
    $description =~ tr/\n/ /;
    $evidence->{ 'hits' }{$id}{'description'} =
    $description =~ /no match/i ? 'No Description' : $description ||  'Unable to retrieve description';
    $i++;
  }
  return $evidence;   
}

sub rna_notation {
  my $self = shift;
  my $obj  = $self->Obj;
  my $T = $obj->get_all_Attributes('miRNA');
  my @strings = ();
  if(@$T) {
    my $string = '-' x $obj->length;
    foreach( @$T ) {
      my( $start, $end ) = split /-/, $_->value;
      substr( $string, $start-1, $end-$start+1 ) = '#' x ($end-$start);
    }
    push @strings, $string;
  }
  $T = $obj->get_all_Attributes('ncRNA');
  if(@$T) {
    my $string = '-' x $obj->length;
    foreach( @$T ) {
      my( $start,$end,$packed ) = $_->value =~ /^(\d+):(\d+)\s+(.*)/;
      substr( $string, $start-1, $end-$start+1 ) =
        join '', map { substr($_,0,1) x (substr($_,1)||1) } ( $packed=~/(\D\d*)/g );
    }
    push @strings, $string;
  }
 # warn join "\n", @strings;
  return @strings;
}

sub location_string {
  my $self = shift;
  return sprintf( "%s:%s-%s", $self->seq_region_name, $self->seq_region_start, $self->seq_region_end );
}


=head2 vega_projection

 Arg[1]	     : EnsEMBL::Web::Proxy::Object
 Arg[2]	     : Alternative assembly name
 Example     : my $v_slices = $object->ensembl_projection($alt_assembly)
 Description : map an object to an alternative (vega) assembly
 Return type : arrayref

=cut

sub vega_projection {
  my $self = shift;
  my $alt_assembly = shift;
  my $alt_projection = $self->Obj->feature_Slice->project('chromosome', $alt_assembly);
  my @alt_slices = ();
  foreach my $seg (@{ $alt_projection }) {
    my $alt_slice = $seg->to_Slice;
    push @alt_slices, $alt_slice;
  }
  return \@alt_slices;
}


=head2 get_exon

 Arg[1]	     : EnsEMBL::Web::Proxy::Object
 Arg[2]	     : exon stable id
 Example     : my $exon = $object->get_exon($id);
 Description : get an exon from the stable_id
 Return type : B::E::Exon

=cut

sub get_exon {
  my $self    = shift;
  my $exon_id = shift;
  my $db      = shift;
  my $dbs     = $self->DBConnection->get_DBAdaptor($db);
  my $exon_adaptor = $dbs->get_ExonAdaptor;
  my $exon    = $exon_adaptor->fetch_by_stable_id($exon_id,1 );
  return $exon;
}

sub mod_date {
  my $self = shift;
  my $time = $self->transcript()->modified_date;
  return unless $time;
  return $self->date_format( $time,'%d/%m/%y' ), $self->date_format( $time, '%y/%m/%d' );
}

sub created_date {
  my $self = shift;
  my $time = $self->transcript()->created_date;
  return unless $time;
  return $self->date_format( $time,'%d/%m/%y' ), $self->date_format( $time, '%y/%m/%d' );
}

sub date_format {
  my( $self, $time, $format ) = @_;
  my( $d,$m,$y) = (localtime($time))[3,4,5];
  my %S = ('d'=>sprintf('%02d',$d),'m'=>sprintf('%02d',$m+1),'y'=>$y+1900);
  (my $res = $format ) =~s/%(\w)/$S{$1}/ge;
  return $res;
}

# Calls for IDHistoryView

sub get_archive_object {
  my $self = shift;
  my $id = $self->stable_id;
  my $archive_adaptor = $self->database('core')->get_ArchiveStableIdAdaptor;
  my $archive_object = $archive_adaptor->fetch_by_stable_id($id);

 return $archive_object;
}

sub get_latest_incarnation {
  my $self = shift;
  return $self->Obj->get_latest_incarnation;
}

=head2 history

 Arg1        : data object
 Description : gets the archive id history tree based around this ID
 Return type : listref of Bio::EnsEMBL::ArchiveStableId
               As every ArchiveStableId knows about it's successors, this is
                a linked tree.

=cut

sub history {
  my $self = shift;

  my $archive_adaptor = $self->database('core')->get_ArchiveStableIdAdaptor;
  return unless $archive_adaptor;

  my $history = $archive_adaptor->fetch_history_tree_by_stable_id($self->stable_id);
  return $history;
}

#########################################################################
#alignview support features - some ported from schema49 AlignmentFactory#

sub get_sf_hit_db_name {
  my $self = shift;
  my ($id) = @_;
  my $hit = $self->get_hit($id);
  return unless $hit;
  return $hit->db_name;
}

sub get_hit {
  my $self = shift;
  my ($id) = @_;
  foreach my $sf (@{$self->Obj->get_all_supporting_features}) {
    return $sf if ($sf->hseqname eq $id);
  }
  foreach my $exon (@{$self->Obj->get_all_Exons()}) {
    foreach my $sf (@{$exon->get_all_supporting_features}) {
      return $sf if ($sf->hseqname eq $id);	
    }
  }
  return;
}

sub determine_sequence_type{
  my $self = shift;
  my $sequence = shift;
  return 'UNKNOWN' unless $sequence;
  my $threshold = shift || 70; # %ACGT for seq to qualify as DNA
  $sequence = uc( $sequence );
  $sequence =~ s/\s|N//;
  $sequence =~ s/^>.*\n//; #remove header line since long headers confuse sequence type determination
  my $all_chars = length( $sequence );
  return unless $all_chars;
  my $dna_chars = ( $sequence =~ tr/ACGT// );
  return ( ( $dna_chars/$all_chars ) * 100 ) > $threshold ? 'DNA' : 'PEP';
}

sub split60 {
  my($self,$seq) = @_;
  $seq =~s/(.{1,60})/$1\n/g;
  return $seq;
}

sub get_int_seq {
  my $self      = shift;
  my $obj       = shift  || return undef();
  my $seq_type  = shift  || return undef(); # DNA || PEP
  my $other_obj = shift;
  my $fasta_prefix = join( '', '>',$obj->stable_id(),"<br />\n");
  if( $seq_type eq "DNA" ){
    return [ $fasta_prefix.$self->split60($obj->seq->seq()),
	     length($obj->seq->seq()) ];
  }
  elsif( $seq_type eq "PEP" ){
    if ($obj->isa('Bio::EnsEMBL::Exon') && $other_obj->isa('Bio::EnsEMBL::Transcript') ) {
      return [ $fasta_prefix.$self->split60($obj->peptide($other_obj)->seq()),
	       length($obj->peptide($other_obj)->seq()) ] if ($obj->peptide($other_obj) && $other_obj->translate);
    }
    elsif( $obj->translate ) {
      return [ $fasta_prefix.$self->split60($obj->translate->seq()),
	       length($obj->translate->seq()) ];
    }
  }
  return [];
}

sub save_seq {
  my $self = shift;
  my $content = shift ;
  my $seq_file = $self->species_defs->ENSEMBL_TMP_TMP.'/'."SEQ_".time().int(rand()*100000000).$$;
  open (TMP,">$seq_file") or die("Cannot create working file.$!");
  print TMP $content;
  close TMP;
  return ($seq_file)
}


=head2 get_Alignment

 Arg[1]      : external sequence
 Arg[2]      : internal sequence (transcript, exon or translation)
 Arg[3]      : type of sequence (DNA or PEP)
 Example     : my $alig =  $self->get_alignment( $ext_seq, $int_seq, $seq_type )
 Description : Runs either matcher or wise2 for pairwise sequence alignment
               Uses custom output format pairln if available
               Used for viewing of supporting evidence alignments
 Return type : alignment

=cut

sub get_alignment{
  my $self = shift;
  my $ext_seq  = shift || return undef();
  my $int_seq  = shift || return undef();
  $int_seq =~ s/<br \/>//g;
  my $seq_type = shift || return undef();
  ## To stop box running out of memory - put an upper limit on the size of sequence
  ## that alignview can handle...
  if( length($int_seq) > 1e6 )  {
    $self->problem('fatal', "Cannot align if sequence > 1 Mbase");
    return undef;
  }
  if( length($ext_seq) > 1e6 )  {
    $self->problem('fatal', "Cannot align if sequence > 1 Mbase");
    return undef;
  }
  my $int_seq_file = $self->save_seq($int_seq);
  my $ext_seq_file = $self->save_seq($ext_seq);
  
  my $label_width  = '22'; #width of column for e! object label
  my $output_width = 61; #width of alignment
  my $dnaAlignExe = "%s/bin/matcher -asequence %s -bsequence %s -outfile %s %s";
  my $pepAlignExe = "%s/bin/psw -m %s/wisecfg/blosum62.bla %s %s -n %s -w %s > %s";

  my $out_file = time().int(rand()*100000000).$$;
  $out_file = $self->species_defs->ENSEMBL_TMP_DIR.'/'.$out_file.'.out';
  
  my $command;
  if( $seq_type eq 'DNA' ){
    $command = sprintf( $dnaAlignExe, $self->species_defs->ENSEMBL_EMBOSS_PATH, $int_seq_file, $ext_seq_file, $out_file, '-aformat3 pairln' );
    warn "Command: $command" if $self->species_defs->ENSEMBL_DEBUG_FLAGS & $self->species_defs->ENSEMBL_DEBUG_EXTERNAL_COMMANDS ;
    `$command`;
    unless (open( OUT, "<$out_file" )) {
      $command = sprintf( $dnaAlignExe, $self->species_defs->ENSEMBL_EMBOSS_PATH, $int_seq_file, $ext_seq_file, $out_file );
      warn "Command: $command" if $self->species_defs->ENSEMBL_DEBUG_FLAGS & $self->species_defs->ENSEMBL_DEBUG_EXTERNAL_COMMANDS ;
      `$command`;
    }
    unless (open( OUT, "<$out_file" )) {
      $self->problem('fatal', "Cannot open alignment file.", $!);
    }
  }
  
  elsif( $seq_type eq 'PEP' ){
    $command = sprintf( $pepAlignExe, $self->species_defs->ENSEMBL_WISE2_PATH, $self->species_defs->ENSEMBL_WISE2_PATH, $int_seq_file, $ext_seq_file, $label_width, $output_width, $out_file );
    warn "Command: $command" if $self->species_defs->ENSEMBL_DEBUG_FLAGS & $self->species_defs->ENSEMBL_DEBUG_EXTERNAL_COMMANDS ;
    `$command`;
    unless (open( OUT, "<$out_file" )) {
      $self->problem('fatal', "Cannot open alignment file.", $!);
    }
  }
  else { return undef; }
    
    my $alignment ;
    while( <OUT> ){
	next if ( $_ =~  /\#Report_file
                         |\#----.*
                         |\/\/\s*
                         |\#\#\#
			 |^\#$
                         |Rundate: #matcher
	                 |Commandline #matcher
                         |asequence #matcher
                         |bsequence #matcher
                         |outfile #matcher
                         |aformat #matcher
                         |Align_format #matcher
			 |Report_file #matcher
                         /x
	      );
	$alignment .= $_;
    }
    $alignment =~ s/\n+$//;
    unlink( $out_file );
    unlink( $int_seq_file );
    unlink( $ext_seq_file );
    $alignment;
}

###################################
#end of alignview support features

sub get_genetic_variations {
  my $self = shift;
  my @samples = @_;
  
  my $tsv_extent = $self->param('context') eq 'FULL' ? 1000 : $self->param('context');
  my $snp_data = {};

  foreach my $sample (@samples) {
    my $munged_transcript = $self->get_munged_slice('tsv_transcript',  $tsv_extent, 1);    
    my $sample_slice = $munged_transcript->[1]->get_by_strain($sample);
    my ($allele_info, $consequences) = $self->getAllelesConsequencesOnSlice($sample, 'tsv_transcript', $sample_slice);
    
    next unless @$consequences && @$allele_info;
    
    my $index = 0;
    
    foreach my $allele_ref (@$allele_info) {
      my $allele = $allele_ref->[2];
      my $conseq_type = $consequences->[$index];
      
      $index++;
      
      next unless $conseq_type && $allele;

      # Type
      my $type = join ', ', @{$conseq_type->type || []};
      $type .= ' (Same As Ref. Assembly)' if $type eq 'SARA';

      # Position
      my $offset = $sample_slice->strand > 0 ? $sample_slice->start - 1 : $sample_slice->end + 1;
      my $chr_start = $allele->start + $offset;
      my $chr_end = $allele->end + $offset;
      my $pos = $chr_start;
      
      if ($chr_end < $chr_start) {
        $pos = "between&nbsp;$chr_end&nbsp;&amp;&nbsp;$chr_start";
      } elsif ($chr_end > $chr_start) {
        $pos = "$chr_start&nbsp;-&nbsp;$chr_end";
      }
      
      my $chr = $sample_slice->seq_region_name;
      my $aa_alleles = $conseq_type->aa_alleles || [];
      my $sources = join ', ' , @{$allele->get_all_sources || []};
      my $vid = $allele->variation_name;
      my $source = $allele->source;
      my $vf = $allele->variation->dbID;
      
      my $url = $self->_url({ 
        type   => 'Variation', 
        action => 'Summary', 
        v      => $vid , 
        vf     => $vf, 
        source => $source 
     });
      
      my $row = {
        ID          => qq{<a href="$url">$vid</a>},
        consequence => $type,
        aachange    => $conseq_type->aa_alleles ? (join "/", @$aa_alleles) || '' : '-'
      };
      
      push @{$snp_data->{"$chr:$pos"}->{$sample}}, $row;
    }
  }
  
  return $snp_data;
}

sub can_export {
  my $self = shift;
  
  return $self->action =~ /^Export$/ ? 0 : $self->availability->{'transcript'};
}

1;

