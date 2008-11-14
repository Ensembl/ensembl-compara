package EnsEMBL::Web::Object::DAS::translation;

use strict;
use warnings;
use Data::Dumper;

use EnsEMBL::Web::Object::DAS::transcript;
our @ISA = qw(EnsEMBL::Web::Object::DAS::transcript);

sub Types {
### Returns a list of types served by this das source....
  my $self = shift;
  return [
	  {
	      'REGION' => '*',
	      'FEATURES' => [
			     { 'id' => 'exon'  }
			     ]
			     }
	  ];
}

###gets features on a slice, and adds to those any other features / groups requested
### -the format od the DSN is very similar transcripts:
###
###> {species}.ASSEMBLY[-{coordinate_system}]/translation[-{database}[-{logicname}]*]
###
### If database is missing assumes core, if logicname is missing assumes all
###

sub Features {
	my $self = shift;

	#debugging - return chromosomal coordinates as well as clone coordinates when requested
	#DO NOT use when live. Also print some warnings
	my $debug = 0;
	#put exon IDS here for debugging
	my @dumping_ids = ();# = qw(OTTHUME00000656829 OTTHUME00000657283);

	my @features;        ## Final array whose reference is returned - simplest way to handle errors/unknowns...
	my $features;        ## Temporary hashref to store segments and features there on...
	my $dba_hashref;     ## Hash ref of database handles...
	my @logic_names;     ## List of logic names of transcripts to return...

	#parse input parameters
	my @segments = $self->Locations;      ##segments requested
	my %fts      = map { $_=>1 } grep { $_ } @{$self->FeatureTypes  || []};
	my @groups   =               grep { $_ } @{$self->GroupIDs      || []};
	my @ftids    =               grep { $_ } @{$self->FeatureIDs    || []};
	my $additions    = {
		map( { ( $_, 'exon'       ) } @ftids  ),  ## other exon features...
		map( { ( $_, 'translation' ) } @groups ), ## other translation features...
	};

	#parse db type and logic names
	my @dbs = ();
	my $db;	
	if( $ENV{'ENSEMBL_DAS_SUBTYPE'} ) {
		( $db, @logic_names ) = split /-/, $ENV{'ENSEMBL_DAS_SUBTYPE'};
		push @dbs, $db;
	} else {
		@dbs = ('core');  ## default = core...;
	}
	foreach (@dbs) {
		my $T = $self->{data}->{_databases}->get_DBAdaptor($_,$self->real_species);
		$dba_hashref->{$_}=$T if $T;
	}
	@logic_names = (undef) unless @logic_names;  ## default is all features of this type
	my %logic_name_filter = map { $_ ? ($_,1) : () } @logic_names;
	
	#templates
	$self->{'templates'}={
		'transview_URL' => sprintf( '%s/%s/transview?transcript=%%s;db=%%s', $self->species_defs->ENSEMBL_BASE_URL, $self->real_species ),
		'protview_URL' => sprintf( '%s/%s/protview?peptide=%%s;db=%%s', $self->species_defs->ENSEMBL_BASE_URL, $self->real_species ),
	};

	#coordinate system on which features are to be returned
	my ($assembly,$cs_wanted) = split '-', $ENV{'ENSEMBL_DAS_ASSEMBLY'};

	my %projection_mappings;
	#all features on the requested slices...
	foreach my $seg (@segments) {
		if( ref($seg) eq 'HASH' && ($seg->{'TYPE'} eq 'ERROR' || $seg->{'TYPE'} eq 'UNKNOWN') ) {
			push @features, $seg;
			next;
		}
		my $slice_genomic_start = $seg->slice->start;
		my $slice_genomic_end = $seg->slice->end;
		my $slice_name = $seg->slice->seq_region_name.":$slice_genomic_start,$slice_genomic_end:".$seg->slice->strand;

		#get mappings on any requested coordinate system
		if ($cs_wanted) {
			foreach my $mapping (@{$self->get_projections($seg->slice,$cs_wanted)}) {
				push @{$projection_mappings{$slice_name}}, $mapping;
			}
		}
		if ($projection_mappings{$slice_name}) {
			foreach my $proj (@{$projection_mappings{$slice_name}}) {	
				$features->{$proj->{'slice_full_name'}}= {
					'REGION'   => $proj->{'slice_name'},
					'START'    => $proj->{'slice_start'},
					'STOP'     => $proj->{'slice_end'},
					'FEATURES' => [],
				}
			}
			if ($debug) {
				$features->{$slice_name}= {
					'REGION'   => $seg->slice->seq_region_name,
					'START'    => $slice_genomic_start,
					'STOP'     => $slice_genomic_end,
					'FEATURES' => [],
				};
			}
		}
		else {
			$features->{$slice_name}= {
				'REGION'   => $seg->slice->seq_region_name,
				'START'    => $slice_genomic_start,
				'STOP'     => $slice_genomic_end,
				'FEATURES' => [],
			};
		}

		foreach my $db_key ( keys %$dba_hashref ) {
			foreach my $gene (@{$seg->slice->get_all_Genes(undef,$db_key) }) {
			TRANS:
				foreach my $transcript (@{$gene->get_all_Transcripts}) {
					#skip if logic_name filtering is requested
					next TRANS if  defined $logic_names[0] && !$logic_name_filter{ $transcript->analysis->logic_name };
					if (my $transl = $transcript->translation()) {
						my $transcript_id = $transcript->stable_id;
						my $strand = $transcript->strand;
						my $transl_id = $transl->stable_id;
						delete $additions->{$transl_id}; #delete this ID from the addition list	if present
						my $translation_group = {
							'ID'   => $transl_id,
							'TYPE' => 'translation:'.$transcript->analysis->logic_name,
							'LABEL' =>  sprintf( '%s (%s)', $transl_id, $transcript->external_name || 'Novel' ),
							'LINK' => [
									{ 'text' => 'Protein Summary '.$transl_id ,
									  'href' => sprintf( $self->{'templates'}{'protview_URL'}, $transl_id, $db_key ),
								  }
								],
						};
				
						#get positions of coding region with respect to the DAS slice
						my $cr_start_slice = $transcript->coding_region_start;
						my $cr_end_slice   = $transcript->coding_region_end;
						
						#get positions of coding region in genomic coords
						my $cr_start_genomic = $transcript->coding_region_start + $slice_genomic_start -1;
						my $cr_end_genomic   = $transcript->coding_region_end +$slice_genomic_end -1;
						
						#get positions of coding region in transcript coords
						my $cr_start_transcript = $transcript->cdna_coding_start;
						my $cr_end_transcript   = $transcript->cdna_coding_end;
						
					EXON:
						foreach my $exon (@{$transcript->get_all_Exons()}) {
							my $exon_stable_id = $exon->stable_id;
							
							#positions of CDS of this exon in transcript coordinates
							my $coding_start_cdna = $exon->cdna_coding_start($transcript);
							my $coding_end_cdna = $exon->cdna_coding_end($transcript);
							#skip if the exon is not coding
							next EXON unless ($coding_start_cdna && $coding_end_cdna);
							
							#positions of exon coding region in slice coordinates
							my ($slice_coding_start,$slice_coding_end);
							#positions of exon coding region in chromosome coordinates
							my ($genomic_coding_start,$genomic_coding_end);
							#positions of exon coding region with respect to transcript
							my ($transcript_coding_start,$transcript_coding_end);
							
							#get positions of exon with respect to the DAS slice
							my $slice_exon_start = $exon->start;
							my $slice_exon_end = $exon->end;
							
							#get positions of exons in chromosome coordinates
							my $exon_start_genomic = $slice_genomic_start + $slice_exon_start;
							my $exon_end_genomic =  $slice_genomic_start + $slice_exon_end;							
							
							#filter exons to only show that which overlaps the slice
							next EXON unless ($exon_start_genomic < $slice_genomic_end && $exon_end_genomic > $slice_genomic_start);
							
							delete $additions->{$exon_stable_id};
							$slice_coding_start = $slice_exon_start < $cr_start_slice ? $cr_start_slice : $slice_exon_start;
							$slice_coding_end   = $slice_exon_end   > $cr_end_slice   ? $cr_end_slice   : $slice_exon_end;
							$genomic_coding_start = $seg->slice->start + $slice_coding_start  - 1;
							$genomic_coding_end = $seg->slice->start + $slice_coding_end - 1;

							if (grep {$exon_stable_id eq $_} @dumping_ids) {
								warn "$exon_stable_id:\$slice_exon_start=$slice_exon_start:\$slice_exon_end=$slice_exon_end:\$strand=$strand";
								warn "$exon_stable_id:\$exon_start_genomic = $exon_start_genomic:\$exon_end_genomic = $exon_end_genomic";
								warn "\$slice_genomic_start = $slice_genomic_start:\$slice_genomic_end = $slice_genomic_end";
								warn "\$genomic_coding_start = $genomic_coding_start:\$genomic_coding_end = $genomic_coding_end";
							}	
							
							##get transcript coordinates of coding portions of exons
							#positions of this exon in transcript coordinates
							my $cdna_start = $exon->cdna_start($transcript);
							my $cdna_end   = $exon->cdna_end($transcript);

							$transcript_coding_start = ($coding_start_cdna > $cdna_start ) ? $coding_start_cdna : $cdna_start;
							$transcript_coding_end = ($coding_end_cdna < $cdna_end) ? $coding_end_cdna : $cdna_end;
							
							#adjust if these regions are beyond either end of the slice requested
							if  ($genomic_coding_start < $slice_genomic_start) {
								$transcript_coding_start = $transcript_coding_start - $genomic_coding_start + $slice_genomic_start;
								$genomic_coding_start = $slice_genomic_start;
								
							}
							if ($genomic_coding_end > $slice_genomic_end) {
								$transcript_coding_end = $transcript_coding_end - ($genomic_coding_end - $slice_genomic_end);
								$genomic_coding_end = $slice_genomic_end;
							}

							my $det = {
								'ID'          => $exon_stable_id,
								'TYPE'        => 'exon:coding:'.$transcript->analysis->logic_name,
								'METHOD'      => $transcript->analysis->logic_name,
								'CATEGORY'    => 'translation',						
								'GROUP'       => [$translation_group],
								'TARGET'      => {
									'ID'    => $transcript_id,								
								}
							};
							
							if ($projection_mappings{$slice_name}) {
								foreach my $proj (@{$projection_mappings{$slice_name}}) {

									#need to swap start and end if the reverse strand has been requested
									if ($proj->{'original_slice_strand'} < 0) {
										$genomic_coding_start = $seg->slice->end - $slice_coding_end + 1;
										$genomic_coding_end = $seg->slice->end - $slice_coding_start + 1;
									}
									my $exon_details = {
										'stable_id'        => $exon_stable_id,
										'genomic_start'    => $genomic_coding_start,
										'genomic_end'      => $genomic_coding_end,
										'transcript_start' => $transcript_coding_start,
										'transcript_end'   => $transcript_coding_end,
										'strand'           => $strand,
									};
									#nasty bit of projecting onto another coordinate system
									$self->project_onto_coord_system($exon_details,$proj,$features,{%{$det}});
								}
								if ($debug) {
									$det->{'START'} = $genomic_coding_start;
									$det->{'END'}   = $genomic_coding_end;
									$det->{'ORIENTATION'} = $self->ori($strand);
									$det->{'TARGET'}{'START'} = $transcript_coding_start;
									$det->{'TARGET'}{'STOP'}  = $transcript_coding_end;
									push @{$features->{$slice_name}{'FEATURES'}}, $det;
								}
							}
							else {
								$det->{'START'} = $genomic_coding_start;
								$det->{'END'}   = $genomic_coding_end;
								$det->{'ORIENTATION'} = $self->ori($strand);
								$det->{'TARGET'}{'START'} = $transcript_coding_start;
								$det->{'TARGET'}{'STOP'}  = $transcript_coding_end;
								push @{$features->{$slice_name}{'FEATURES'}}, $det;
							}
						}
					}
				}
			}
		}
	}

	#get any additional requested features
	if ($additions) {
		foreach my $db_key ( keys %$dba_hashref ) {

			#need to go via the gene since cannot go backwards, ie can't get a transcript from a translation
			my $geneadap = $self->{data}->{_databases}->get_DBAdaptor($db_key,$self->real_species)->get_GeneAdaptor;
			while ( my ($extra_id,$type) = each %{$additions} ) {
				my $gene;
				if ($type eq 'translation') {
					$gene = $geneadap->fetch_by_translation_stable_id($extra_id);
					next unless ($gene = $geneadap->fetch_by_translation_stable_id($extra_id));
				}
				elsif ($type eq 'exon') {
					next unless ($gene = $geneadap->fetch_by_exon_stable_id($extra_id));
				}
				#only allow translation and exon stable IDs
				else {
					next;
				}

				my $slice_name;
			TRANS:
				foreach my $transcript (@{$gene->get_all_Transcripts}) {
					if (my $transl = $transcript->translation()) {
						next TRANS if ($transl->stable_id ne $extra_id);
						next TRANS if (defined $logic_names[0] && !$logic_name_filter{ $transcript->analysis->logic_name });
						if ($type eq 'translation') {
							$slice_name = $transcript->slice->seq_region_name.':'.$transcript->slice->start.':'.$transcript->slice->end.':'.$transcript->slice->strand;				
							#add projections if requested
							if ($cs_wanted) {
								foreach my $proj (@{$self->get_projections($transcript->feature_Slice,$cs_wanted)}) {
									unless (exists $features->{$proj->{'slice_full_name'}}) {	
										push @{$projection_mappings{$slice_name}}, $proj;
										$features->{$proj->{'slice_full_name'}}= {
											'REGION'   => $proj->{'slice_name'},
											'START'    => $proj->{'slice_start'},
											'STOP'     => $proj->{'slice_end'},
											'FEATURES' => [],
										}								
									}
								}
								if ($debug) {
									unless (exists $features->{$slice_name}) {
										$features->{$slice_name}= {
											'REGION'   => $transcript->slice->seq_region_name,
											'START'    => $transcript->slice->start,
											'STOP'     => $transcript->slice->end,
											'FEATURES' => [],
										};
									}
								}
							}
							#otherwise add top level seqregion
							else {	
								unless( exists $features->{$slice_name} ) {	
									$features->{$slice_name}= {
										'REGION'   => $transcript->slice->seq_region_name,
										'START'    => $transcript->slice->start,
										'STOP'     => $transcript->slice->end,
										'FEATURES' => [],
									};
								}
							}
						}
						my $transcript_id = $transcript->stable_id;
						my $strand = $transcript->strand;
						my $transl_id = $transl->stable_id;
						delete $additions->{$transl_id}; 				
						my $translation_group = {
							'ID'   => $transl_id,
							'TYPE' => 'translation:'.$transcript->analysis->logic_name,
							'LABEL' => sprintf( '%s (%s)', $transl_id, $transcript->external_name || 'Novel' ),
							'LINK' => [
									{ 'text' => 'Protein Summary '.$transl_id ,
									  'href' => sprintf( $self->{'templates'}{'protview_URL'}, $transl_id, $self->{'db'} ),
								  }
								],
						};
						
						#get positions of translation in genomic coordinates
						my $cr_start_genomic = $transcript->coding_region_start;
						my $cr_end_genomic   = $transcript->coding_region_end;
						
						#get positions of translation in transcript coords
						my $cr_start_transcript = $transcript->cdna_coding_start;
						my $cr_end_transcript   = $transcript->cdna_coding_end;
						
					EXON:
						foreach my $exon (@{$transcript->get_all_Exons()}) {
							my $exon_stable_id = $exon->stable_id;
							if ($type eq 'exon') {
								next EXON if ($exon_stable_id ne $extra_id);								
								$slice_name = $exon->slice->seq_region_name.':'.$exon->slice->start.':'.$exon->slice->end.':'.$exon->slice->strand;
								
								#add projections if requested
								if ($cs_wanted) {
									foreach my $proj (@{$self->get_projections($exon->feature_Slice,$cs_wanted)}) {
										unless (exists $features->{$proj->{'slice_full_name'}}) {	
											push @{$projection_mappings{$slice_name}}, $proj;
											$features->{$proj->{'slice_full_name'}}= {
												'REGION'   => $proj->{'slice_name'},
												'START'    => $proj->{'slice_start'},
												'STOP'     => $proj->{'slice_end'},
												'FEATURES' => [],
											}								
										}
									}
									if ($debug) {
										unless (exists $features->{$slice_name}) {
											$features->{$slice_name}= {
												'REGION'   => $exon->slice->seq_region_name,
												'START'    => $exon->slice->start,
												'STOP'     => $exon->slice->end,
												'FEATURES' => [],
											};
										}
									}
								}
								#otherwise add top level seqregion
								else {	
									unless( exists $features->{$slice_name} ) {	
										$features->{$slice_name}= {
											'REGION'   => $exon->slice->seq_region_name,
											'START'    => $exon->slice->start,
											'STOP'     => $exon->slice->end,
											'FEATURES' => [],
										};
									}
								}
							}
						
							#positions of coding region in chromosome coordinates
							my ($genomic_coding_start,$genomic_coding_end);
							#positions of exon CDS with respect to transcript
							my ($transcript_coding_start,$transcript_coding_end);
							
							#get positions of exon with respect to the slice requested by das
							my $exon_start = $exon->start;
							my $exon_end = $exon->end;
							
							##get genomic coordinates of coding portions of exons
							if( $exon_start <= $cr_end_genomic && $exon_end >= $cr_start_genomic ) {
								$genomic_coding_start = $exon_start < $cr_start_genomic ? $cr_start_genomic : $exon_start;
								$genomic_coding_end = $exon_end   > $cr_end_genomic   ? $cr_end_genomic   : $exon_end;
								
								##get transcript coordinates of coding portions of exons
								#positions of this exon in transcript coordinates
								my $cdna_start = $exon->cdna_start($transcript);
								my $cdna_end   = $exon->cdna_end($transcript);
								#positions of CDS of this exon in transcript coordinates
								my $coding_start_cdna = $exon->cdna_coding_start($transcript);
								my $coding_end_cdna = $exon->cdna_coding_end($transcript);
								$transcript_coding_start = ($coding_start_cdna > $cdna_start ) ? $coding_start_cdna : $cdna_start;
								$transcript_coding_end = ($coding_end_cdna < $cdna_end) ? $coding_end_cdna : $cdna_end;
							}
							else {
								next EXON;
							}

							my $det = {
								'ID'          => $exon_stable_id,
								'TYPE'        => 'exon:coding:'.$transcript->analysis->logic_name,
								'METHOD'      => $transcript->analysis->logic_name,
								'CATEGORY'    => 'translation',						
								'GROUP'       => [$translation_group],
								'TARGET'      => {
									'ID'    => $transcript_id,								
								}
							};

							if ($projection_mappings{$slice_name}) {
								foreach my $proj (@{$projection_mappings{$slice_name}}) {
									if (grep {$exon_stable_id eq $_} @dumping_ids) {
										warn Dumper($proj);
										warn "strand  = $strand";
									}
									my $exon_details = {
										'stable_id'        => $exon_stable_id,
										'genomic_start'    => $genomic_coding_start,
										'genomic_end'      => $genomic_coding_end,
										'transcript_start' => $transcript_coding_start,
										'transcript_end'   => $transcript_coding_end,
										'strand'           => $strand,
									};									
									$self->project_onto_coord_system($exon_details,$proj,$features,{%{$det}});
								}
							}
							else {								
								push @{$features->{$slice_name}{'FEATURES'}}, {
									'ID'          => $exon_stable_id,
									'TYPE'        => 'exon:coding:'.$transcript->analysis->logic_name,
									'METHOD'      => $transcript->analysis->logic_name,
									'CATEGORY'    => 'translation',
									'START'       => $genomic_coding_start,
									'END'         => $genomic_coding_end,
									'ORIENTATION' => $self->ori($strand),
									'GROUP'       => [$translation_group],
									'TARGET'      => {
										'ID'    => $transcript_id,
										'START' => $transcript_coding_start,
										'STOP'  => $transcript_coding_end,
									}
								};
							}
						}
					}
				}
			}
		}
	}
	push @features, values %{$features};
	return \@features;
}


#almost exactly the same as the transcript stylesheet
sub Stylesheet {
	my $self = shift;
	my $stylesheet_structure = {};
	my $colour_hash = { 
		'default'                   => 'grey50',
		'havana'                    => 'dodgerblue4',
		'ensembl'                   => 'rust',
		'flybase'                   => 'rust',
		'wornbase'                  => 'rust',
		'ensembl_havana_transcript' => 'goldenrod3',
		'estgene'                   => 'purple1',
		'otter'                     => 'dodgerblue4',
		'otter_external'            => 'orangered2',
		'otter_corf'                => 'olivedrab',
		'otter_igsf'                => 'olivedrab',
		'otter_eucomm'              => 'orangered2',
	};
	foreach my $key ( keys %$colour_hash ) {
		my $colour = $colour_hash->{$key};
		$stylesheet_structure->{"translation"}{$key ne 'default' ? "exon:coding:$key" : 'default'}=
			[{ 'type' => 'box', 'attrs' => { 'FGCOLOR' => $colour, 'BGCOLOR' => 'white', 'HEIGHT' => 6  } },
		 ];
		$stylesheet_structure->{'translation'}{$key ne 'default' ? "exon:coding:$key" : 'default'} =
			[{ 'type' => 'box', 'attrs' => { 'BGCOLOR' => $colour, 'FGCOLOR' => $colour, 'HEIGHT' => 10  } }];
		$stylesheet_structure->{"group"}{$key ne 'default' ? "translation:$key" : 'default'} =
			[{ 'type' => 'line', 'attrs' => { 'STYLE' => 'intron', 'HEIGHT' => 10, 'FGCOLOR' => $colour, 'POINT' => 1 } }];
	}
	return $self->_Stylesheet( $stylesheet_structure );
}

1;
