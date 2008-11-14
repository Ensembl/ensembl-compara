package EnsEMBL::Web::Object::DAS::gene;

use strict;
use warnings;

use EnsEMBL::Web::Object::DAS;
our @ISA = qw(EnsEMBL::Web::Object::DAS);

use Data::Dumper;

sub Types {
  my $self = shift;

  return [
	  {
	      'REGION' => '*',
	      'FEATURES' => [
			     { 'id' => 'gene'  }
			     ]
			     }
	  ];
}

sub Features {
	my $self = shift;

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
	### For genes the format will eventually be the same as for transcripts and translations:
	###
	###> {species}.ASSEMBLY[-{coordinate_system}].[enhanced_]transcript[-{database}[-{logicname}]*]
	###
	### If database is missing assumes core, if logicname is missing assumes all
	### transcript features
	###
	### coordinate_system defines the coord system on which to return the features
   	### e.g.
	###
	###* /das/Homo_sapiens.NCBI36-toplevel.transcript-core-ensembl
	###
	###* /das/Homo_sapiens.NCBI36-clone.transcript-vega
	###
	### ASSEMBLY is supported, but coordinate_system is not yet.

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
		map( { ( $_, 'exon' ) } @ftids  ),  ## Filter for exon features...
		map( { ( $_, 'gene' ) } @groups )   ## Filter for gene features...
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

	###Note that the projection onto clones is not supported yet

	#identify coordinates of the wanted slice on the requested coordinate system
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
		$features->{$slice_name}= {
			'REGION'   => $segment->slice->seq_region_name,
			'START'    => $segment->slice->start,
			'STOP'     => $segment->slice->end,
			'FEATURES' => [],
		};

		#foreach database get all genes on the top level slice
		foreach my $db ( keys %$dba_hashref ) {
			foreach my $gene ( @{$segment->slice->get_all_Genes(undef,$db) } ) {
				my $gsi = $gene->stable_id;
				delete $filters->{$gsi}; # This comes off a segment so make sure it isn't filtered!
				$no_filters->{$gsi} = 1;
				my $trans_arrayref = [];
				foreach my $transcript ( @{$gene->get_all_Transcripts} ) {
					next if  defined $logic_names[0] && 
						!$logic_name_filter{ $transcript->analysis->logic_name };
					my $tsi = $transcript->stable_id;
					my $transobj = { 'object' => $transcript, 'exons' => [] };
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
				$genes{ $gsi } = { 'db' => $db,
								   'object' => $gene, 
								   'transcripts' => $trans_arrayref,
							       'slice_name' => $slice_name 
							   } if @$trans_arrayref;
			}
		}
	} ## end of segment loop....

	###_ Part 5: Fetch features based on group_id and filter_id - filter_id currently only works for exons
	### and group_id only for genes
	my $ga_hashref = {};
	my $ea_hashref = {};
	my $ta_hashref = {};

	#link extra exon_IDs requested with the projection seq_region(s) they are on
	my %extra_regions;

	foreach my $id ( keys %$filters ) {
		my $gene;
		my $filter;
		my $slice_name;
		foreach my $db ( keys %$dba_hashref ) {
			my $gadap = $dba_hashref->{$db}->get_GeneAdaptor;
			if( $filters->{$id} eq 'gene' ) {
				$gene = $gadap->fetch_by_stable_id( $id );
				$slice_name = $gene->slice->seq_region_name.':'.$gene->slice->start.','.$gene->slice->end.':'.$gene->slice->strand;
				unless( exists $features->{$slice_name} ) {
					$features->{$slice_name} = {
						'REGION' => $gene->slice->seq_region_name,
						'START'  => $gene->slice->start,
						'STOP'   => $gene->slice->end,
						'FEATURES' => [],
					};
				}
			}
			if ($filters->{$id} eq 'exon') {
				$gene = $gadap->fetch_by_exon_stable_id( $id );
				my $eadap = $dba_hashref->{$db}->get_ExonAdaptor;
				my $exon = $eadap->fetch_by_stable_id( $id );
				$slice_name = $exon->slice->seq_region_name.':'.$exon->slice->start.','.$exon->slice->end.':'.$exon->slice->strand;
				unless( exists $features->{$slice_name} ) {
					$features->{$slice_name} = {
						'REGION' => $exon->slice->seq_region_name,
						'START'  => $exon->slice->start,
						'STOP'   => $exon->slice->end,
						'FEATURES' => [],
					};
				}
			}
			next unless $gene;
			if ($gene) {
				my $gsi = $gene->stable_id;
				unless( exists $genes{$gsi} ) { ## Gene doesn't exist so we have to store it and grab transcripts and exons...
					$genes{$gsi}->{'object'} = $gene;
					$genes{$gsi}->{'slice_name'} = $slice_name;
					$genes{$gsi}->{'db'} = $db;
					foreach my $transcript ( @{$gene->get_all_Transcripts} ) {
						next if  defined $logic_names[0] &&
							!$logic_name_filter{ $transcript->analysis->logic_name };
						my $tsi = $transcript->stable_id;
						my $transobj = { 'object' => $transcript, 'exons' => [] };
						my $start = 1;
					EXON:
						foreach my $exon ( @{$transcript->get_all_Exons} ) {
							my $esi = $exon->stable_id;
							if ($filters->{$id} eq 'exon') {
								delete $filters->{$esi};
								$no_filters->{$esi} = 1;
								if ($esi ne $id) {
									next EXON;
								}
							}
							push @{ $transobj->{'exons'} }, [ $exon , $start, $start+$exon->length-1 ];
							$start += $exon->length;
						}
						push @{ $genes{$gsi}->{'transcripts'} },$transobj;
					}
				}
				# Delete all filters on gene
				if( $filter eq 'gene' ) {
					delete $filters->{$gsi};
					$no_filters->{$gsi} = 1;
				}
			}
		}
	} ## end of segment loop....


	#View templates
	$self->{'templates'} ||= {};
	$self->{'templates'}{'geneview_URL'}  = sprintf( '%s/%s/Gene/Summary?g=%%s;db=%%s',        $self->species_defs->ENSEMBL_BASE_URL, $self->real_species );

	### Part 6: Grab and return features
	### Now we do all the nasty stuff of retrieving features and creating DAS objects for them...
	foreach my $gene_stable_id ( keys %genes ) {
		my $gene = $genes{$gene_stable_id}{'object'};
		my $slice_name = $genes{$gene_stable_id}{'slice_name'};
		my $db = $genes{$gene_stable_id}{'db'};
		my $gene_start = $gene->seq_region_start;
		my $gene_end   = $gene->seq_region_end;
		my $gene_group = {
				'ID'    => $gene_stable_id, 
				'TYPE'  => 'Gene:'.$gene->analysis->logic_name,
				'LABEL' =>  sprintf( '%s (%s)', $gene_stable_id, $gene->external_name || 'Novel' ),
				'LINK' => [
						{ 'text' => 'GeneView '.$gene_stable_id ,
						  'href' => sprintf( $self->{'templates'}{'geneview_URL'}, $gene_stable_id, $db ),
					  }
					],
			};
		foreach my $transobj ( @{ $genes{$gene_stable_id}{'transcripts'} } ) {
			my $transcript = $transobj->{'object'};
			my $transcript_stable_id = $transcript->stable_id;

		EXON:
			foreach my $exon_ref ( @{$transobj->{'exons'}}) {
				my $exon = $exon_ref->[0];
				my $exon_stable_id = $exon->stable_id;
				my $exon_start = $exon->seq_region_start;
				my $exon_end = $exon->seq_region_end;
				
				#filter exons to only show that which overlaps the slice
				next EXON unless ($exon->seq_region_start <  $exon->slice->end && $exon->seq_region_end > $exon->slice->start);
				my $det = {
					'ID'          => $exon_stable_id,
					'TYPE'        => 'exon:'.$transcript->analysis->logic_name,
					'METHOD'      => $gene->analysis->logic_name,
					'CATEGORY'    => 'transcription',
					'GROUP'       => [ $gene_group ],
					'START'       => $exon_start,
					'END'         => $exon_end,
					'ORIENTATION' => $self->ori($exon->strand),					
					'TARGET'      => {
						'ID'    => $gene_stable_id,
						'START' => $exon_start - $gene_start + 1,
						'STOP'  => $exon_end - $gene_start + 1,
					}
				};
				push @{$features->{$slice_name}{'FEATURES'}}, $det;
			}
		}
	}

	### Part 7: Return the reference to an array of the slice specific hashes.
	push @features, values %{$features};
#	warn Dumper(\@features);
	return \@features;
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
    'ensembl_havana_transcript'  => 'goldenrod3',
    'estgene'                    => 'purple1',
    'otter'                      => 'dodgerblue4',
	'otter_external'             => 'orangered2',
	'otter_corf'                 => 'olivedrab',
	'otter_igsf'                 => 'olivedrab',
	'otter_eucomm'               => 'orangered2',
  };
  foreach my $key ( keys %$colour_hash ) {
	  my $colour = $colour_hash->{$key};
	  $stylesheet_structure->{"exon"}{$key ne 'default' ? "exon:$key" : 'default'}=
		  [{ 'type' => 'box', 'attrs' => { 'FGCOLOR' => $colour, 'BGCOLOR' => 'white', 'HEIGHT' => 6  } }];
	  $stylesheet_structure->{'exon'}{$key ne 'default' ? "exon:$key" : 'default'} =
		  [{ 'type' => 'box', 'attrs' => { 'BGCOLOR' => $colour, 'FGCOLOR' => $colour, 'HEIGHT' => 10  } }];
	  $stylesheet_structure->{"group"}{$key ne 'default' ? "gene:$key" : 'default'} =
		  [{ 'type' => 'line', 'attrs' => { 'STYLE' => 'intron', 'HEIGHT' => 10, 'FGCOLOR' => $colour, 'POINT' => 1 } }];
  }
  return $self->_Stylesheet( $stylesheet_structure );
}
1;
