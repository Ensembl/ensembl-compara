package EnsEMBL::Web::Object::DAS::transcript;

use strict;
use warnings;

use EnsEMBL::Web::Object::DAS;
our @ISA = qw(EnsEMBL::Web::Object::DAS);

use Data::Dumper;

sub Types {
### Returns a list of types served by this das source....
## Incomplete at present....
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

#put exon IDS here for debugging
our @dumping_ids = ();

sub Features {
	my $self = shift;

	###debugging - return chromosomal coordinates as well as clone coordinates when requested
	###DO NOT use when live. Also print some warnings
	my $debug = 0;

	### Return das features...
	### structure returned is an arrayref of hashrefs, each array element refers to
	### a different segment, the hashrefs contain segment info (seg type, seg name,
	### seg start, seg end) and an array of feature hashes

	###_ Part 1: initialize data structures...
	my @features;          ## Final array whose reference is returned - simplest way to handle errors/unknowns...
	my $features;          ## Temporary hashref to store segments and features there on...
	my %genes;             ## Temporary hash to store ensembl gene objects...
	my $dba_hashref;       ## Hash ref of database handles...
	
	## (although not implemented at the moment may allow multiple dbs to be connected to..)
	my @logic_names;       ## List of logic names of transcripts to return...

	###_ Part 2: parse the DSN to work out what we want to display
	### Relevant part of DSN is stored in $ENV{'ENSEMBL_DAS_SUBTYPE'}
	###
	### For transcripts the format is:
	###
	###> {species}.ASSEMBLY[-{coordinate_system}]/[enhanced_]transcript[-{database}[-{logicname}]*]
	###
	### If database is missing assumes core, if logicname is missing assumes all
	### transcript features
	###
	### coordinate_system defines the coord system on whihc to return the features
   	### e.g.
	###
	###* /das/Homo_sapiens.NCBI36-toplevel.transcript-core-ensembl
	###
	###* /das/Homo_sapiens.NCBI36-clone.transcript-vega
	###

#	warn  $ENV{'ENSEMBL_DAS_SUBTYPE'};
#	warn  $ENV{'ENSEMBL_DAS_TYPE'};

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
	
	###_ Part 3: parse CGI parameters to get out feature types, group ids and feature ids
	###* FeatureTypes - Currently ignored...
	###* Group IDs    - filter in this case transcripts
	###* Feature IDs  - filter in ths case exons
	my @segments = $self->Locations;
	my %fts      = map { $_=>1 } grep { $_ } @{$self->FeatureTypes  || []};
	my @groups   =               grep { $_ } @{$self->GroupIDs      || []};
	my @ftids    =               grep { $_ } @{$self->FeatureIDs    || []};
	
	my $filters    = {
		map( { ( $_, 'exon'       ) } @ftids  ),  ## Filter for exon features...
		map( { ( $_, 'transcript' ) } @groups )   ## Filter for transcript features...
	};
	my $no_filters = {};
	
	#logic names filter
	my %logic_name_filter = map { $_ ? ($_,1) : () } @logic_names;

	###Part 4: Fetch features on the segments requested...
	###The approach is to map all requested slices onto the top level in the Factory, irrespective of
	###their actual coord system. By retrieving features on this top level coord_system partially
	###overlapping features can be retrieved.

	###When features are requested to be *returned* on a different coordinate system such as clone,
	###then this change in coordinates is done at the very end, using information in the 
	###%projection_mappings hash.
	
	#coordinate system on which features are to be returned
	my ($assembly,$cs_wanted) = split '-', $ENV{'ENSEMBL_DAS_ASSEMBLY'};

	#identify coordinates of the wanted slice on the requested coordinate system
	my %projection_mappings;
	foreach my $segment (@segments) {
		if( ref($segment) eq 'HASH' && ($segment->{'TYPE'} eq 'ERROR' || $segment->{'TYPE'} eq 'UNKNOWN') ) {
			push @features, $segment;
			next;
		}
		my $segment_name   = $segment->slice->seq_region_name;
		my $segment_start  = $segment->slice->start;
		my $segment_end    = $segment->slice->end;
		my $segment_strand = $segment->slice->strand;
		my $slice_name  = "$segment_name:$segment_start,$segment_end:$segment_strand";

		#get mappings onto any requested coordinate system
		if ($cs_wanted) {
			foreach my $mapping (@{$self->get_projections($segment->slice,$cs_wanted)}) {
				push @{$projection_mappings{$slice_name}}, $mapping;
			}
		}

		#Each slice is added irrespective of whether there is any data, so we "push"
		#on empty slice entries...
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
					'REGION'   => $segment->slice->seq_region_name,
					'START'    => $segment->slice->start,
					'STOP'     => $segment->slice->end,
					'FEATURES' => [],
				};
			}
		}
		else {
			$features->{$slice_name}= {
				'REGION'   => $segment->slice->seq_region_name,
				'START'    => $segment->slice->start,
				'STOP'     => $segment->slice->end,
				'FEATURES' => [],
			};
		}

		if ($debug) {
			warn "Features will be stored on the following slices ",Dumper($features);
		}

		#foreach database get all genes on the top level slice
		foreach my $db_key ( keys %$dba_hashref ) {
			foreach my $gene ( @{$segment->slice->get_all_Genes(undef,$db_key) } ) {
				my $gsi = $gene->stable_id;
				delete $filters->{$gsi}; # This comes off a segment so make sure it isn't filtered!
				$no_filters->{$gsi} = 1;
				my $trans_arrayref = [];
				foreach my $transcript ( @{$gene->get_all_Transcripts} ) {
					next if  defined $logic_names[0] && 
						!$logic_name_filter{ $transcript->analysis->logic_name };
					my $tsi = $transcript->stable_id;
					my $transobj = { 'obj' => $transcript, 'exons' => [] };
					delete $filters->{$tsi}; # This comes off a segment so make sure it isn't filtered!
					$no_filters->{$tsi} = 1;
					my $start = 1;
					foreach my $exon ( @{$transcript->get_all_Exons} ) {
						my $esi = $exon->stable_id;
						delete $filters->{$esi}; # This comes off a segment so make sure it isn't filtered!
						push @{ $transobj->{'exons'} }, [ $exon , $start, $start+$exon->length-1 ];
						$start += $exon->length;
						$no_filters->{$esi} = 1;
					}
					
					push @$trans_arrayref,$transobj;
				}
				$genes{ $gsi } = { 'db' => $db_key, 'obj' => $gene, 'transcripts' => $trans_arrayref  } if @$trans_arrayref;
			}
		}
	} ## end of segment loop....

	if ($debug) {
		warn scalar(keys(%genes))," genes retrieved from top level slice";
	}

	###_ Part 5: Fetch features based on group_id and filter_id - filter_id currently only works for exons
	### and group_id only for transcripts
	my $ga_hashref = {};
	my $ea_hashref = {};
	my $ta_hashref = {};

	#link extra exon_IDs requested with the projection seq_region(s) they are on
	my %extra_regions;

	foreach my $id ( keys %$filters ) {
		next unless $filters->{$id};
		my $gene;
		my $filter;
		my $db_key;
		foreach my $db ( keys %$dba_hashref ) {
			$db_key = $db;
			$ga_hashref->{$db} ||= $dba_hashref->{$db}->get_GeneAdaptor;
			$ea_hashref->{$db} ||= $dba_hashref->{$db}->get_ExonAdaptor;
			$ta_hashref->{$db} ||= $dba_hashref->{$db}->get_TranscriptAdaptor;
			if( $filters->{$id} eq 'exon' ) {
				$gene = $ga_hashref->{$db}->fetch_by_exon_stable_id( $id );
				my $exon = $ea_hashref->{$db}->fetch_by_stable_id( $id );
				$filter = 'exon';
				my $slice_name = $exon->slice->seq_region_name.':'.$exon->slice->start.','.$exon->slice->end.':'.$exon->slice->strand;

				#add regions for extra exon IDs requested
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
						push @{$extra_regions{$id}}, $slice_name;
					}
					if ($debug) {
						unless( exists $features->{$slice_name} ) {
							$features->{$slice_name} = {
								'REGION' => $exon->slice->seq_region_name,
								'START'  => $exon->slice->start,
								'STOP'   => $exon->slice->end,
								'FEATURES' => [],
							};
						}
						push @{$extra_regions{$id}}, $slice_name;
					}
				}
				else {
					unless( exists $features->{$slice_name} ) {
						$features->{$slice_name} = {
							'REGION' => $exon->slice->seq_region_name,
							'START'  => $exon->slice->start,
							'STOP'   => $exon->slice->end,
							'FEATURES' => [],
						};
					}
				}
			}
			else {
				$filter = 'transcript';
				$gene = $ga_hashref->{$db}->fetch_by_transcript_stable_id( $id );
				my $trans = $ta_hashref->{$db}->fetch_by_stable_id( $id );
				my $slice_name = $trans->slice->seq_region_name.':'.$trans->slice->start.','.$trans->slice->end.':'.$trans->slice->strand;

				#add regions for extra transcript ID requested
				if ($cs_wanted) {
					foreach my $proj (@{$self->get_projections($trans->feature_Slice,$cs_wanted)}) {
						unless (exists $features->{$proj->{'slice_full_name'}}) {	
							push @{$projection_mappings{$slice_name}}, $proj;
							$features->{$proj->{'slice_full_name'}}= {
								'REGION'   => $proj->{'slice_name'},
								'START'    => $proj->{'slice_start'},
								'STOP'     => $proj->{'slice_end'},
								'FEATURES' => [],
							}								
						}
						push @{$extra_regions{$id}}, $slice_name;
					}
					if ($debug) {
						unless( exists $features->{$slice_name} ) {
							$features->{$slice_name} = {
								'REGION' => $trans->slice->seq_region_name,
								'START'  => $trans->slice->start,
								'STOP'   => $trans->slice->end,
								'FEATURES' => [],
							};
						}
						push @{$extra_regions{$id}}, $slice_name;
					}
				}
				else {
					unless( exists $features->{$slice_name} ) {
						$features->{$slice_name} = {
							'REGION' => $trans->slice->seq_region_name,
							'START'  => $trans->slice->start,
							'STOP'   => $trans->slice->end,
							'FEATURES' => [],
						};
					}
				}
			}
			last if $gene;
		}
		next unless $gene;
		my $gsi = $gene->stable_id;
		unless( exists $genes{$gsi} ) { ## Gene doesn't exist so we have to store it and grab transcripts and exons...
			my $trans_arrayref = [];
			foreach my $transcript ( @{$gene->get_all_Transcripts} ) {
				next if  defined $logic_names[0] &&
					!$logic_name_filter{ $transcript->analysis->logic_name };
				my $tsi = $transcript->stable_id;
				my $transobj = { 'obj' => $transcript, 'exons' => [] };
				my $start = 1;
				foreach my $exon ( @{$transcript->get_all_Exons} ) {
					my $esi = $exon->stable_id;
					push @{ $transobj->{'exons'} }, [ $exon , $start, $start+$exon->length-1 ];
					$start += $exon->length;
				}
				push @{ $genes{$gsi}->{'transcripts'} },$transobj;
			}
			$genes{ $gsi } = { 'obj' => $gene, 'transcripts' => $trans_arrayref  } if @$trans_arrayref;
		}
		if( $filter eq 'gene' ) { ## Delete all filters on Gene and subsequent exons
			delete $filters->{$gsi};
			$no_filters->{$gsi} = 1;
			foreach my $transobj ( @{ $genes{$gsi}{'transcripts'} } ) {
				my $transcript = $transobj->{'obj'}; 
				delete $filters->{$transcript->stable_id};
				$no_filters->{$transcript->stable_id} = 1;
				foreach my $exon ( @{$transobj->{'exons'}} ) {
					$no_filters->{$exon->[0]->stable_id} = 1;
					delete $filters->{$exon->[0]->stable_id};
				}
			}
		} elsif( $filter eq 'transcript' ) { ## Delete filter on Transcript...
			foreach my $transobj ( @{ $genes{$gsi}{'transcripts'} } ) {
				my $transcript = $transobj->{'obj'}; 
				next unless $transcript->stable_id eq $id;
				foreach my $exon ( @{$transobj->{'exons'}} ) {
					$no_filters->{$exon->[0]->stable_id} = 1;
					delete $filters->{$exon->[0]->stable_id};
				}
			}
		}
	} ## end of segment loop....


	#View templates
	$self->{'templates'} ||= {};
	$self->{'templates'}{'transview_URL'} = sprintf( '%s/%s/transview?transcript=%%s;db=%%s', $self->species_defs->ENSEMBL_BASE_URL, $self->real_species );
	$self->{'templates'}{'geneview_URL'}  = sprintf( '%s/%s/geneview?gene=%%s;db=%%s',        $self->species_defs->ENSEMBL_BASE_URL, $self->real_species );
	$self->{'templates'}{'protview_URL'}  = sprintf( '%s/%s/protview?peptide=%%s;db=%%s',     $self->species_defs->ENSEMBL_BASE_URL, $self->real_species );
	$self->{'templates'}{'r_URL'}         = sprintf( '%s/%s/r?d=%%s;ID=%%s',                  $self->species_defs->ENSEMBL_BASE_URL, $self->real_species );
	
### Part 6: Grab and return features
### Now we do all the nasty stuff of retrieving features and creating DAS objects for them...
	foreach my $gene_stable_id ( keys %genes ) {
		if ($debug) {
			warn "Looking at gene $gene_stable_id";
		}
		my $gene = $genes{$gene_stable_id}{'obj'};
		my $db   = $genes{$gene_stable_id}{'db'};
		foreach my $transobj ( @{ $genes{$gene_stable_id}{'transcripts'} } ) {
			my $transcript = $transobj->{'obj'};
			my $transcript_stable_id = $transcript->stable_id;
			my $transcript_group = {
				'ID'    => $transcript_stable_id, 
				'TYPE'  => 'transcript:'.$transcript->analysis->logic_name,
				'LABEL' =>  sprintf( '%s (%s)', $transcript_stable_id, $transcript->external_name || 'Novel' ),
				$self->_group_info( $transcript, $gene, $db ) ## Over-riden in enhnced transcripts...
			};
			
			#get positions of coding region in genomic coordinates
			my $cr_start_genomic = $transcript->coding_region_start;
			my $cr_end_genomic   = $transcript->coding_region_end;
			if ($cr_start_genomic && $cr_end_genomic) {
				if( $transobj->{'exons'}[0][0]->slice->strand > 0 ) {
					$cr_start_genomic += $transobj->{'exons'}[0][0]->slice->start - 1;
					$cr_end_genomic   += $transobj->{'exons'}[0][0]->slice->start - 1;
				} else {
					$cr_start_genomic *= -1;
					$cr_end_genomic   *= -1;
					$cr_start_genomic += $transobj->{'exons'}[0][0]->slice->end + 1;
					$cr_end_genomic   += $transobj->{'exons'}[0][0]->slice->end + 1;
				}
			}

		EXON:
			foreach my $exon_ref ( @{$transobj->{'exons'}}) {
				my $exon = $exon_ref->[0];
				my $exon_stable_id = $exon->stable_id;
				
				#filter exons to only show that which overlaps the slice
				next EXON unless ($exon->seq_region_start <  $exon->slice->end && $exon->seq_region_end > $exon->slice->start);

				if ($debug) {
					warn "\texon $exon_stable_id is on the slice";
				}

				#get names of slices to be considered (ie also have slices from additional groups and features)
				my @slice_names;
				if (my $regions = $extra_regions{$exon_stable_id}) {
					foreach my $region (@{$regions}) {
						push @slice_names,$region;
					}
				}
				else {
					my $region = $exon->slice->seq_region_name.':'.$exon->slice->start.','.$exon->slice->end.':'.$exon->slice->strand;
					push @slice_names,$region;
				}

				unless( exists $no_filters->{$gene_stable_id} || exists $no_filters->{$transcript_stable_id } || exists $no_filters->{$gene_stable_id} ) { ## WE WILL DRAW THIS!!
					unless( exists $filters->{$exon_stable_id} || exists $filters->{$transcript_stable_id} ) {
						next;
					}
				}
				
				## Push the features on to the slice specific array
				## Now we have to work out the overlap with coding sequence...
				my $exon_start_genomic = $exon->seq_region_start;
				my $exon_end_genomic   = $exon->seq_region_end;
				my @sub_exons  = ();
				if( defined $cr_start_genomic ) { ## Translatable genes...
					my $exon_coding_start;
					my $exon_coding_end;
					my $target_start;
					my $target_end;
					if( $exon->strand > 0 ) { ## Forward strand...
						if( $exon_start_genomic < $cr_end_genomic && $exon_end_genomic > $cr_start_genomic ) {
							$exon_coding_start = $exon_start_genomic < $cr_start_genomic ? $cr_start_genomic : $exon_start_genomic;
							$exon_coding_end   = $exon_end_genomic   > $cr_end_genomic   ? $cr_end_genomic   : $exon_end_genomic;
							
							$target_start = $exon_start_genomic < $cr_start_genomic ? $cr_start_genomic - $exon_start_genomic + $exon_ref->[1] : $exon_ref->[1];
							$target_end   = $exon_end_genomic   > $cr_end_genomic   ? $cr_end_genomic   - $exon_start_genomic + $exon_ref->[1] : $exon_ref->[2];
							
							#only show region that overlaps the slice requested
							if ($exon_coding_start < $exon->slice->start) {
								$target_start = $target_start + ($exon->slice->start - $exon_coding_start);
								$exon_coding_start = $exon->slice->start;
								$exon_start_genomic = $exon->slice->start;
							}
							if ($exon_coding_end > $exon->slice->end) {
								$target_end = $target_end - ($exon_coding_end - $exon->slice->end);
								$exon_coding_end = $exon->slice->end;
								$exon_end_genomic = $exon->slice->end;
							}
							if( $exon_end_genomic > $exon_coding_end ) {
								push @sub_exons, [ "3'UTR", $exon_coding_end+1, $exon_end_genomic, $target_end +1, $exon_ref->[2], $exon->strand ];
							}
							push @sub_exons, [ "coding", $exon_coding_start, $exon_coding_end, $target_start, $target_end, $exon->strand ];
							if( $exon_start_genomic < $exon_coding_start ) {
								push @sub_exons, [ "5'UTR", $exon_start_genomic, $exon_coding_start - 1, $exon_ref->[1], $target_start - 1, $exon->strand ];
							}
						} elsif( $exon_end_genomic < $cr_start_genomic ) {
							push @sub_exons, [ "5'UTR", $exon_start_genomic, $exon_end_genomic, $exon_ref->[1], $exon_ref->[2],$exon->strand ];
						} else {
							push @sub_exons, [ "3'UTR", $exon_start_genomic, $exon_end_genomic, $exon_ref->[1], $exon_ref->[2],$exon->strand ];
						}
					} else {  ## Reverse strand...
						if( $exon_start_genomic < $cr_end_genomic && $exon_end_genomic > $cr_start_genomic ) {							
							$exon_coding_start = $exon_start_genomic < $cr_start_genomic ? $cr_start_genomic : $exon_start_genomic;
							$exon_coding_end   = $exon_end_genomic   > $cr_end_genomic   ? $cr_end_genomic   : $exon_end_genomic;
							
							$target_end = $exon_start_genomic < $cr_start_genomic ? $exon_ref->[2] - $cr_start_genomic + $exon_start_genomic : $exon_ref->[2];
							$target_start = $exon_end_genomic > $cr_end_genomic ? $exon_ref->[1] + $exon_end_genomic - $cr_end_genomic -1 : $exon_ref->[1];
							
							#only show region that overlaps the slice requested (for clone requests)
							if ($exon_coding_start < $exon->slice->start) {	
								$target_end = $target_end - ($exon->slice->start - $exon_coding_start);	
								$exon_coding_start = $exon->slice->start;
								$exon_start_genomic = $exon->slice->start;
							}
							if ($exon_coding_end > $exon->slice->end) {
								$target_start = $target_start + ($exon_coding_end - $exon->slice->end);	
								$exon_coding_end = $exon->slice->end;
								$exon_end_genomic = $exon->slice->end;
							}
							
							#note coding and non-coding regions
							push @sub_exons, [ "coding", $exon_coding_start, $exon_coding_end, $target_start, $target_end,$exon->strand ];
							if( $exon_end_genomic > $exon_coding_end ) {
								push @sub_exons, [ "5'UTR", $exon_coding_end+1, $exon_end_genomic      , $exon_ref->[1], $target_start - 1,$exon->strand  ];
							}
							if( $exon_start_genomic < $exon_coding_start ) {
								push @sub_exons, [ "3'UTR", $exon_start_genomic, $exon_coding_start - 1, $target_end+1, $exon_ref->[2], $exon->strand];
							}
						} elsif( $exon_end_genomic < $cr_start_genomic ) {
							push @sub_exons, [ "3'UTR", $exon_start_genomic, $exon_end_genomic, $exon_ref->[1], $exon_ref->[2],$exon->strand ];
						} else {
							push @sub_exons, [ "5'UTR", $exon_start_genomic, $exon_end_genomic, $exon_ref->[1], $exon_ref->[2],$exon->strand ];
						}
					}
				} else {  ## Easier one... non-translatable genes...
					@sub_exons = ( [ 'non_coding', $exon_start_genomic, $exon_end_genomic,$exon_ref->[1], $exon_ref->[2],$exon->strand ] );
				}

				#now retrieve the details of each part of the exons and add to the correct seq_region
				foreach my $se (@sub_exons ) {
					my $det = {
						'ID'          => $exon_stable_id,
						'TYPE'        => 'exon:'.$se->[0].':'.$transcript->analysis->logic_name,
						'METHOD'      => $transcript->analysis->logic_name,
						'CATEGORY'    => 'transcription',
						'GROUP'       => [ $transcript_group ],
					};
					foreach my $slice_name (@slice_names) {	
						if ($projection_mappings{$slice_name}) {
						PROJ:
							foreach my $proj (@{$projection_mappings{$slice_name}}) {
								my $exon_details = {
									'stable_id'        => $exon_stable_id,
									'genomic_start'    => $se->[1],
									'genomic_end'      => $se->[2],,
									'transcript_start' => $se->[3],
									'transcript_end'   => $se->[4],
									'strand'           => $se->[5],
								};
								#do the nast bit of projecting onto clones
								$self->project_onto_coord_system($exon_details,$proj,$features,{%{$det}});

								#also store top level coords if debugging requested
								if ($debug) {
									$det->{'START'} = $se->[1];
									$det->{'END'}   = $se->[2];
									$det->{'ORIENTATION'} = $self->ori($exon->strand);					
									$det->{'TARGET'}      = {
										'ID'    => $transcript_stable_id,
										'START' => $se->[3], 
										'STOP'  => $se->[4],
									};
									push @{$features->{$slice_name}{'FEATURES'}}, $det;
								}
							}
						}
						
						#store top level coords if no projection mapppings, ie if no alternative return coord_system requested
						else {
							$det->{'START'} = $se->[1]; 
							$det->{'END'}   = $se->[2];
							$det->{'ORIENTATION'} = $self->ori($exon->strand);					
							$det->{'TARGET'}      = {
								'ID'    => $transcript_stable_id,
								'START' => $se->[3], 
								'STOP'  => $se->[4],
							};
							push @{$features->{$slice_name}{'FEATURES'}}, $det;
						}
					}
				}
			}
		}
    }

	### Part 7: Return the reference to an array of the slice specific hashes.
	push @features, values %{$features};
	return \@features;
}

sub project_onto_coord_system {
	my $self = shift;
	my ($exon,$proj,$features,$det) = @_;
	my $exon_stable_id = $exon->{'stable_id'};

	##exon strand is relative to the original slice requested, ie if a clone
	##in the reversed orientation is requested, then an exon_strand orientation
	##of 1 calculated above actually means that exon is on the reverse strand
	my $tl_exon_strand = ($exon->{'strand'} == $proj->{'original_slice_strand'} ) ? 1 : -1;
	##return on the strand relative to that requested
	my $strand_to_return_on = ($tl_exon_strand == $proj->{'original_slice_strand'}) ? 1 : -1;
	$det->{'ORIENTATION'} = ($strand_to_return_on == 1) ? $self->ori(1) : $self->ori(-1);								

	#reverse the start and stop positions if neccesary
	my $tl_exon_start = $exon->{'genomic_start'};
	my $orig_start =  $tl_exon_start;
	my $tl_exon_end = $exon->{'genomic_end'};
	my $orig_end = $tl_exon_end;
	if ($tl_exon_start > $tl_exon_end) {
		my $tmp = $tl_exon_start;
		$tl_exon_start = $tl_exon_end;
		$tl_exon_end = $tmp;
	}
	#return if the exon is not on this projected slice
	if ($orig_start  > $proj->{'top_level_end'}
			|| $orig_end < $proj->{'top_level_start'}) {
		if ( grep {$exon_stable_id eq $_} @dumping_ids)  { warn "skipping to next projection";}	
		return;
	}	
	elsif ($orig_start >= $proj->{'top_level_start'}) {		
		#if the exon is fully enclosed within this projected slice..
		if ($orig_end <= $proj->{'top_level_end'}) {
			if ( grep {$exon_stable_id eq $_} @dumping_ids)  { warn "$exon_stable_id contained within slice";}
			$det->{'TARGET'}{'START'}  = $exon->{'transcript_start'};
			$det->{'TARGET'}{'STOP'}  = $exon->{'transcript_end'};			
			if ($proj->{'top_level_strand'} > 0) {
				if ($tl_exon_strand > 0) { #I
					$det->{'START'} = $proj->{'slice_start'} + ($tl_exon_start - $proj->{'top_level_start'});
					$det->{'END'} = $proj->{'slice_start'} + ($tl_exon_end - $proj->{'top_level_start'});							
				}
				else { #J
					$det->{'START'} = $proj->{'slice_start'} + ($tl_exon_start - $proj->{'top_level_start'});
					$det->{'END'} =  $proj->{'slice_start'} + ($tl_exon_end - $proj->{'top_level_start'});
				}
			}
			else { #K
				if ($tl_exon_strand > 0) {
					$det->{'END'} = $proj->{'slice_end'} - ($tl_exon_start - $proj->{'top_level_start'});
					$det->{'START'} = $proj->{'slice_end'} - ($tl_exon_end - $proj->{'top_level_start'});
				}
				else { #L
					$det->{'END'} = $proj->{'slice_end'} - ($tl_exon_start - $proj->{'top_level_start'});
					$det->{'START'} = $proj->{'slice_end'} - ($tl_exon_end - $proj->{'top_level_start'});
				}
			}
		}
		#if the start of the exon is within the projected slice but the end isn't...
		else {
			if ( grep {$exon_stable_id eq $_} @dumping_ids)  { warn "exon end off the end of the slice";}
			if ($proj->{'top_level_strand'} == 1) {
				if ($tl_exon_strand >0) { #A
					$det->{'START'}	= $proj->{'slice_end'} - ($proj->{'top_level_end'} - $tl_exon_start);
					$det->{'END'}	= $proj->{'slice_end'};
					$det->{'TARGET'}      = {
						'START' => $exon->{'transcript_start'},
						'STOP'  => $exon->{'transcript_end'},
					};
				}
				else { #B
					$det->{'END'}	= $proj->{'slice_end'};
					$det->{'START'}	= $proj->{'slice_end'} - ($proj->{'top_level_end'} - $tl_exon_start);
					$det->{'TARGET'}      = {
						'START' => $exon->{'transcript_end'} - ($proj->{'top_level_end'} - $tl_exon_end),
						'STOP'  => $exon->{'transcript_end'},
					};
				}
			}
			else { #C
				if ($tl_exon_strand > 0) {
					$det->{'END'}	= $proj->{'slice_start'} + ($proj->{'top_level_end'} - $tl_exon_start);
					$det->{'START'}	= $proj->{'slice_start'};
					$det->{'TARGET'}      = {
						'START' => $exon->{'transcript_start'},
						'STOP'  => $exon->{'transcript_start'} + ($proj->{'top_level_end'} - $tl_exon_start),
					};
				}
				else { #D
					$det->{'START'}	= $proj->{'slice_start'};
					$det->{'END'}	= $proj->{'slice_start'} + ($proj->{'top_level_end'} - $tl_exon_start);
					$det->{'TARGET'}      = {
						'START' => $exon->{'transcript_end'} - ($proj->{'top_level_end'} - $tl_exon_end),
						'STOP'  => $exon->{'transcript_end'},
					};
				}
			}
		}
	}	
	#if the end of the exon is within the projection but the start isn't...
	elsif ($orig_end <= $proj->{'top_level_end'}) {
		if ( grep {$exon_stable_id eq $_} @dumping_ids)  { warn "exon start before the start of the slice";}
		if ($proj->{'top_level_strand'} == 1) {
			if ($tl_exon_strand > 0) { #E
				$det->{'START'}	= $proj->{'slice_start'};
				$det->{'END'} = $proj->{'slice_start'} + ( $tl_exon_end - $proj->{'top_level_start'} );
				$det->{'TARGET'}      = {
					'START' => $exon->{'transcript_end'} -  ( $tl_exon_end - $proj->{'top_level_start'} ),
					'STOP'  => $exon->{'transcript_end'},
				};
			}
			else { #F
				$det->{'END'}	= $proj->{'slice_start'} + ($tl_exon_end - $proj->{'top_level_start'});
				$det->{'START'} =  $proj->{'slice_start'};
				$det->{'TARGET'} = {
					'START' => $exon->{'transcript_start'},
					'STOP'  => $exon->{'transcript_start'} + ($tl_exon_start - $proj->{'top_level_start'} ),
				};
			}
		}
		else {
			if ($tl_exon_strand > 0) {	#G
				$det->{'END'}	= $proj->{'slice_end'};
				$det->{'START'} = $proj->{'slice_end'} - ($tl_exon_end - $proj->{'top_level_start'});
				$det->{'TARGET'} = {
					'START' =>  $exon->{'transcript_end'} - ($tl_exon_end - $proj->{'top_level_start'} ),
					'STOP'  =>  $exon->{'transcript_end'},
				};
			}
			else { #H
				$det->{'START'}	= $proj->{'slice_end'} - ($tl_exon_end - $proj->{'top_level_start'});
				$det->{'END'} = $proj->{'slice_end'} ;
				$det->{'TARGET'}= {
					'START' => $exon->{'transcript_end'},
					'STOP'  => $exon->{'transcript_end'}+ ($tl_exon_start - $proj->{'top_level_start'} ),
				};
			}
		}
	}	
	else {
		warn "***Shouldn't be here - exon $exon_stable_id!";
	}

	if (grep {$exon_stable_id eq $_} @dumping_ids) {
		warn "projection for $exon_stable_id is ",Dumper($proj);
		warn "exon_details are ",Dumper($exon);
		warn "will be returned on $strand_to_return_on";
		warn "strand = $tl_exon_strand--\$tl_exon_start = $tl_exon_start--\$tl_exon_end = $tl_exon_end"
	}
	push @{$features->{$proj->{'slice_full_name'}}{'FEATURES'}}, $det;
}




sub _group_info {
## Return the links... note main difference between two tracks is the "enhanced transcript" returns more links (GV/PV) and external entries...
  my( $self, $transcript, $gene, $db ) = @_;
  return
    'LINK' => [ { 'text' => 'TransView '.$transcript->stable_id ,
                  'href' => sprintf( $self->{'templates'}{'transview_URL'}, $transcript->stable_id, $db ) }
    ];
}

sub Stylesheet {
  my $self = shift;
  my $stylesheet_structure = {};
  my $colour_hash = { 
    'default'                    => 'grey50',
    'havana'                     => 'dodgerblue4',
    'ensembl'                    => 'rust',
    'flybase'                    => 'rust',
    'wornbase'                   => 'rust',
    'ensembl_havana_transcript'  => 'goldendrod3',
    'estgene'                    => 'purple1',
    'otter'                      => 'dodgerblue4',
	'otter_external'             => 'orangered2',
	'otter_corf'                 => 'olivedrab',
	'otter_igsf'                 => 'olivedrab',
	'otter_eucomm'               => 'orangered2',
  };
  foreach my $key ( keys %$colour_hash ) {
    my $colour = $colour_hash->{$key};
    $stylesheet_structure->{"transcription"}{$key ne 'default' ? "exon:3'UTR:$key" : 'default'}=
    $stylesheet_structure->{"transcription"}{$key ne 'default' ? "exon:5'UTR:$key" : 'default'}=
    $stylesheet_structure->{"transcription"}{$key ne 'default' ? "exon:non_coding:$key" : 'default'}=
      [{ 'type' => 'box', 'attrs' => { 'FGCOLOR' => $colour, 'BGCOLOR' => 'white', 'HEIGHT' => 6  } },
      ];
    $stylesheet_structure->{'transcription'}{$key ne 'default' ? "exon:coding:$key" : 'default'} =
      [{ 'type' => 'box', 'attrs' => { 'BGCOLOR' => $colour, 'FGCOLOR' => $colour, 'HEIGHT' => 10  } }];
    $stylesheet_structure->{"group"}{$key ne 'default' ? "transcript:$key" : 'default'} =
      [{ 'type' => 'line', 'attrs' => { 'STYLE' => 'intron', 'HEIGHT' => 10, 'FGCOLOR' => $colour, 'POINT' => 1 } }];
  }
  return $self->_Stylesheet( $stylesheet_structure );
}
1;
