
package EnsEMBL::Web::Component::Transcript::SupportingEvidence;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);
use Bio::EnsEMBL::Intron;

use Data::Dumper;
$Data::Dumper::Maxdepth = 2;

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub caption {
  return undef;
}

sub content {
	my $self = shift;
	my $object = $self->object;

	my $type = $object->logic_name;
	my $html = qq(<div class="content">);
	if (! $object->count_supporting_evidence) {
		$html .=  qq( <dt>No Evidence</dt><dd>);
		#show message for Prediction Transcripts and Havana transcripts with no evidence
		if ($object->transcript->isa('Bio::EnsEMBL::PredictionTranscript')) {
			$html .= qq(<p>Supporting evidence is not available for Prediction transcripts</p>);
		}
		elsif ($type =~ /otter/ ){
			$html .= qq(<p>Although this Vega Havana transcript has been manually annotated and it's structure is supported by experimental evidence, this evidence is currently missing from the database. We are adding the evidence to the database as time permits</p>);
		}
		else {
			$html .= qq(<p>Supporting evidence not available for this transcript</p>);
		}
	}
	else {
		$html .= $self->_content();
	}
	$html .=  "</dd>";
	return $html;
}

sub _content {
	my $self    = shift;
	my $object  = $self->object;

	$object->param('image_width',800); ### remove this when user config is possible

	#user defined width in pixels
	my $image_width  = $object->param( 'image_width' );

	#context is user defined size of introns
	$object->param('context',100); ### remove this when user config is possible
	my $context      = $object->param('context') ? $object->param('context') : 100;

	#set 5' and 3' extensions to the image depending on the context
	my $extent       = $context eq 'FULL' ? 1000 : $context;
	
	my $config = $object->get_userconfig( "supporting_evidence_transcript" );
	$config->set( '_settings', 'width',  $image_width );

	#add transcript itself
	my $transcript = $object->Obj;
	$config->{'transcript'}{'transcript'} = $transcript;

	#get both real slice and normalised slice (ie introns flattened)
	my @slice_defs = ( [ 'supporting_evidence_transcript', 'munged', $extent ] );
	foreach my $slice_type (@slice_defs) {
		$object->__data->{'slices'}{$slice_type->[0]} = $object->get_transcript_slices($slice_type) || warn "Couldn't get slice";	
	}

	my $transcript_slice = $object->__data->{'slices'}{'supporting_evidence_transcript'}[1];
	my $sub_slices       = $object->__data->{'slices'}{'supporting_evidence_transcript'}[2];
	my $fake_length      = $object->__data->{'slices'}{'supporting_evidence_transcript'}[3];

    $config->container_width( $fake_length ); #sets width of image
	$config->{'id'}        = $object->stable_id; #used for label
	$config->{'subslices'} = $sub_slices; #used to draw lines for exons
    $config->{'extent'}    = $extent; #used for padding between exons and at the end of the transcript
	$config->{'fakeslice'} = 1; #not sure what this is used for! ??

	#add info on normalised exons (ie flattened introns) to config - this is no longer used by the transcript
    #drawing code so no longer needed to be added to the config ?
	my $ens_exons;
	my $offset = $transcript_slice->start -1;
	my $exons = $object->Obj->get_all_Exons();
	foreach my $exon (@{$exons}) {
		my $es     = $exon->start - $offset;
		my $ee     = $exon->end   - $offset;
		my $munge  = $object->munge_gaps('supporting_evidence_transcript', $es);
		push @$ens_exons, [ $es + $munge, $ee + $munge, $exon ];
	}
	$config->{'transcript'}{'exons'} = $ens_exons ;

#	warn Dumper($sub_slices);
#	warn Dumper($ens_exons);

	#identify coordinates of the portions of introns and exons to be drawn. Include the exon object
	my $e_counter = 0;
	my $e_count = scalar(@$ens_exons);
	my $intron_exon_slices;
	#reverse the order of exons if the strand is negative
	my @exons = $transcript->strand == 1 ? @{$ens_exons} : reverse(@{$ens_exons});
 SUBSLICE:
	foreach my $subslice (@{$sub_slices}) {
		my $subslice_start = $subslice->[0]+$subslice->[2];
		my $subslice_end   = $subslice->[1]+$subslice->[2];
		my ($exon_start,$exon_end);
#		warn "1. subslice_start = $subslice_start, subslice_end = $subslice_end";
		for ($e_counter; $e_counter < $e_count; $e_counter++) {
			my $exon  = $exons[$e_counter];
			$exon_start = $exon->[0];
			$exon_end = $exon->[1];
			my $exon_id = $exon->[2]->stable_id;
#			warn "$exon_id: exon_start = $exon_start, exon_end = $exon_end";
#			warn "2. subslice_start = $subslice_start, subslice_end = $subslice_end";
			#if the exon is still withn the subslice then work with it
			if ( ($subslice_end > $exon_end) ){
				my $start = $subslice_start;
				my $end   = $exon_start;
#				warn "3. start = $start, end = $end";
				push @{$intron_exon_slices}, [$start, $end] if $intron_exon_slices; #don't add the first one
				push @{$intron_exon_slices}, $exon;
				#set subslice to the end of the ready for the next exon iteration
				$subslice_start = $exon_end;
#				warn "setting start of sublice to end of exon";
			}
			else {
				#otherwise draw a line to the end of the subslice and move on
				my $start = $ens_exons->[$e_counter-1]->[1];
				my $end = $subslice_end;
				push @{$intron_exon_slices}, [$exons[$e_counter-1]->[1], $subslice_end];
#				warn "4. start = $start, end = $end";
				next SUBSLICE;
			}
		}
		#push @{$intron_exon_slices}, [$subslice_start, $subslice_end]; #uncomment to add last intron
	}
	$config->{'transcript'}{'introns_and_exons'} = $intron_exon_slices;

	#add info normalised coding region
    my $raw_coding_start = defined($transcript->coding_region_start) ? $transcript->coding_region_start-$offset : $transcript->start-$offset;
    my $raw_coding_end   = defined($transcript->coding_region_end)   ? $transcript->coding_region_end-$offset   : $transcript->end-$offset;
    my $coding_start = $raw_coding_start + $object->munge_gaps( 'supporting_evidence_transcript', $raw_coding_start );
    my $coding_end   = $raw_coding_end   + $object->munge_gaps( 'supporting_evidence_transcript', $raw_coding_end );
	$config->{'transcript'}{'coding_start'} = $coding_start;
	$config->{'transcript'}{'coding_end'}   = $coding_end;

	#get introns (would be nice to have an API call but until this is there do this)
	my @introns;
	my $s = 0;
	my $e = 1;
	my $t = scalar(@{$exons});
	while ($e < $t) {
		my $i = Bio::EnsEMBL::Intron->new($exons->[$s],$exons->[$e]);
		push @introns, [ $i, $exons->[$s]->stable_id, $exons->[$e]->stable_id ];
		$s++;
		$e++;
	}

	#add info on non_canonical splice site sequences for introns
	my @canonical_sites = ( ['GT', 'AG'],['GC', 'AG'], ['AT', 'AC'] ); #these are considered canonical

	my $non_con_introns;
	my $hack_c = 1; #set to zero to tag first intron - used for development to highlight first intron
	foreach my $i_details (@introns) {
		my $i = $i_details->[0];
		my $seq = $i->seq;
		my $l = length($seq);
		my $donor_seq = substr($seq,0,2); #5'
		my $acceptor_seq = $hack_c ? substr($seq,$l-2,2) : 'CC';
		$hack_c++;
		my $e_details = $i_details->[1].':'.$i_details->[2]."($donor_seq:$acceptor_seq)";
		my $canonical = 0;
		foreach my $seqs (@canonical_sites) {
			$canonical = 1 if ( ($donor_seq eq $seqs->[0]) && ($acceptor_seq eq $seqs->[1]) );
		}
		unless ($canonical) {
			my $is = $i->start - $offset;
			my $ie = $i->end - $offset;
			my $munged_start = $is + $object->munge_gaps( 'supporting_evidence_transcript', $is );
			my $munged_end = $ie + $object->munge_gaps( 'supporting_evidence_transcript', $ie );
			push @$non_con_introns, [ $munged_start, $munged_end, $donor_seq, $acceptor_seq, $e_details, $i ];
#		    warn "real start = ",$i->start,", real end = ",$i->end;
#			warn "offset start = $is, offset end = $ie";
#			warn "munged = ",$munged_start,"-",$munged_end;
		}
	}
	$config->{'transcript'}{'non_con_introns'} = $non_con_introns ;

	#add info on normalised transcript_supporting_evidence
	my $t_evidence;
	foreach my $evi (@{$transcript->get_all_supporting_features}) {
		my $coords;
		my $hit_name = $evi->hseqname;
		$t_evidence->{$hit_name}{'hit_name'} = $hit_name;

		#split evidence into ungapped features, map onto exons and munge (ie account for gaps)
		my $first_feature = 1;
		my $last_end = 0;
		my @features = $evi->ungapped_features;
		for (my $c; $c < scalar(@features); $c++) {
			my $feature = $features[$c];
			my $munged_coords = $self->split_evidence_and_munge_gaps($feature,$exons,$offset, [ $raw_coding_start+$offset,$raw_coding_end+$offset ], ref($evi));
			if ($last_end) {
				if ($evi->isa('Bio::EnsEMBL::DnaPepAlignFeature')) {
					if (abs($feature->hstart - $last_end) > 3) {
						$munged_coords->[0]{'hit_mismatch'} =  $feature->hstart - $last_end;
					}
				}
				else {
					if (abs($feature->hstart - $last_end) > 1) {
						$munged_coords->[0]{'hit_mismatch'} =  $feature->hstart - $last_end;
					}
					elsif ($feature->hstart == $last_end) {
						$munged_coords->[0]{'hit_mismatch'} = 0;
					}
				}
			}

			#is the first feature beyond the end of the transcript
			if ($first_feature){
				if ($transcript->strand == 1) {
					if ($feature->end <  $exons->[0]->seq_region_start) {
						$munged_coords->[0]{'lh-ext'} = 1;
					}
				}
				else {
					if ($feature->start > $exons->[0]->seq_region_end) {
						$munged_coords->[0]{'rh-ext'} = 1;
					}
				}
				$first_feature = 0
			}

			#is the last feature beyond the end of the transcript
			if ($c == scalar(@features)-1) {
				if ($transcript->strand == 1) {
					if ($feature->start > $exons->[-1]->seq_region_end) {
						$munged_coords->[0]{'rh-ext'} = 1;
					}	
				}
				else {
					if ($feature->end < $exons->[-1]->seq_region_start) {
						$munged_coords->[0]{'lh-ext'} = 1;
					}
				}
			}
				

			$last_end = $feature->hend;
			#reverse the exon order if on the reverse strand
			if ($transcript->strand == 1) {
				push @{$t_evidence->{$hit_name}{'data'}},$munged_coords->[0];
			}
			else {
				unshift  @{$t_evidence->{$hit_name}{'data'}},$munged_coords->[0];
			}
		}
		warn Dumper($t_evidence->{$hit_name}{'data'}) if ($evi->hseqname eq 'NM_024848.1');
	}

	#calculate total length of the hit (used for sorting the display)
	while ( my ($hit_name, $hit_details) = each (%{$t_evidence})  ) {
		my $tot_length;
		foreach my $match (@{$hit_details->{'data'}}) {
			my $len = abs($match->{'munged_end'} - $match->{'munged_start'}) + 1;
			$tot_length += $len;
#			if ($hit_name eq 'NP_543151.1') { warn "length of this bit is $len (",$match->[1]," - ",$match->[0],"; total is now $tot_length"; }
		}
		$t_evidence->{$hit_name}{'hit_length'} = $tot_length;
	}
#	if ($transcript->strand != 1) {
#		reverse(@{$t_evidence->{$hit_name}{'data'}});
#	}
#	warn Dumper($t_evidence->{$hit_name}{'data'}) if ($evi->hseqname eq 'NM_024848.1')

	$config->{'transcript'}{'transcript_evidence'} = $t_evidence;	
	
#	warn Dumper($t_evidence);
	
	#add info on additional supporting_evidence (exon level)
	my $e_evidence;
	my $evidence_checks;
	my %evidence_start_stops;
	foreach my $exon (@$exons) {
	EVI:
		foreach my $evi (@{$exon->get_all_supporting_features}) {
			
			my $hit_name = $evi->hseqname;
			next EVI if (exists($t_evidence->{$hit_name})); #only proceed if this hit name has not been used as transcript evidence
			
			##this can be simplified greatly if we're not tagging start and stop##
			
			
			#calculate the beginning and end of each merged hit
			my $hit_seq_region_start = $evi->start;
			my $hit_seq_region_end   = $evi->end;
			
			#calculate beginning and end of the combined hit (first steps are needed to autovivify)
			$evidence_start_stops{$hit_name}{'comb_start'} = $hit_seq_region_start unless exists($evidence_start_stops{$hit_name}{'comb_start'});
			$evidence_start_stops{$hit_name}{'comb_end'} = $hit_seq_region_end unless exists($evidence_start_stops{$hit_name}{'comb_end'});
			$evidence_start_stops{$hit_name}{'comb_start'} = $hit_seq_region_start if ($hit_seq_region_start < $evidence_start_stops{$hit_name}{'comb_start'});
			$evidence_start_stops{$hit_name}{'comb_end'} = $hit_seq_region_end if ($hit_seq_region_end > $evidence_start_stops{$hit_name}{'comb_end'});
			
			#ignore duplicate entries
			if ( defined(@{$evidence_start_stops{$hit_name}{'starts_and_ends'}})
					 && grep {$_ eq "$hit_seq_region_start:$hit_seq_region_end"} @{$evidence_start_stops{$hit_name}{'starts_and_ends'}}) {
				next EVI;
			}
			push @{$evidence_start_stops{$hit_name}{'starts_and_ends'}}, "$hit_seq_region_start:$hit_seq_region_end";
			
			
			my $hit_mismatch;
			my $hit_start = $evi->hstart;
			
			#compare the start of this hit with the end of the last one -
			#only DNA features have to match exactly, protein features have a tolerance of +- 3
			if ($evi->isa('Bio::EnsEMBL::DnaPepAlignFeature')) {
				if (   ($evidence_start_stops{$hit_name}{'last_end'}) 
						   && (abs($hit_start - $evidence_start_stops{$hit_name}{'last_end'}) > 3 )) {
					$hit_mismatch = $hit_start - $evidence_start_stops{$hit_name}{'last_end'};
				}
			}
			else {
				if (   ($evidence_start_stops{$hit_name}{'last_end'}) 
						   && (abs($hit_start - $evidence_start_stops{$hit_name}{'last_end'}) > 1) ) {
					$hit_mismatch = $hit_start - $evidence_start_stops{$hit_name}{'last_end'};
				}
				elsif ($hit_start == $evidence_start_stops{$hit_name}{'last_end'}) {
					$hit_mismatch = 0;
				}
			}
			#note position of end of the hit for next iteration
			$evidence_start_stops{$hit_name}{'last_end'} = $evi->hend;
			
			# Use this code since it does the coordinate munging but pass it just a single exon since no need to look across exon boundries
			my $munged_coords = $self->split_evidence_and_munge_gaps($evi, [ $exon ], $offset, [ $raw_coding_start+$offset,$raw_coding_end+$offset ], ref($evi));
			foreach my $munged_hit (@$munged_coords) {
				
				#add tag if there is a mismatch between exon / hit boundries
				if (defined($hit_mismatch)) {
##					push @{$munged_hit}, $hit_mismatch;
					$munged_hit->{'hit_mismatch'} = $hit_mismatch;
				}
				push @{$e_evidence->{$hit_name}{'data'}}, $munged_hit ;				
			}
			$e_evidence->{$hit_name}{'hit_name'} = $hit_name;
		}
	}
		
		
		#hack for transcript ENST00000378708
		#	$evidence_start_stops{'NM_080875.1'}{'comb_start'} = 38;
		#	$evidence_start_stops{'NM_080875.1'}{'comb_end'} = 39000000;
		
		#hack for transcript ENST00000333046
		#	$evidence_start_stops{'BC098411.1'}{'comb_start'} = 38;
		#	$evidence_start_stops{'BC098411.1'}{'comb_end'} = 140000000;
		
		
		#add tags if the merged hit extends beyond the end of the transcript
		#	while ( my ($hit_name, $coords) = each (%evidence_start_stops)) {
		#		if ($coords->{'comb_start'} < $transcript->start) {
		#			warn "$hit_name:",$coords->{'comb_start'},"--",$transcript->start;
		#			my $diff =  $transcript->start - $coords->{'comb_start'};
		#			$e_evidence->{$hit_name}{'start_extension'} = $transcript->start - $coords->{'comb_start'};
		#		}
		#		if ($coords->{'comb_end'} > $transcript->end) {
		#			$e_evidence->{$hit_name}{'end_extension'} = $coords->{'comb_end'} - $transcript->end;
		#		}
		#	}	
		
		#calculate total length of the hit (used for sorting the display)
	while ( my ($hit_name, $hit_details) = each (%{$e_evidence})  ) {
		my $tot_length;
		foreach my $match (@{$hit_details->{'data'}}) {
			my $l = abs($match->{'munged_end'} - $match->{'munged_start'}) + 1;
			$tot_length += $l;
		}
		$e_evidence->{$hit_name}{'hit_length'} = $tot_length;
	}
	$config->{'transcript'}{'evidence'} = $e_evidence;	

	#draw and render image
	my $image = $object->new_image(
		$transcript_slice,$config,
		[ $object->stable_id ]
	);
	$image->imagemap = 'yes';
	return $image->render;
}


=head2 split_evidence_and_munge_gaps

  Arg [1]    : B::E::DnaDnaAlignFeature, B::E::DnaPepAlignFeature or B::E::FeaturePair
  Arg [2]    : Arrayref of B::E::Exons
  Arg [3]    : Transcript start (ie offset to convert genomic to transcript genomic coordinates)
  Arg [4]    : Arrayref of coding positions
  Arg [5]    : type of evidence (B::E::DnaDnaAlignFeature or B::E::DnaPepAlignFeature) 
  Description: Takes a supporting feature and maps to all exons supplied - depending on usage either all exons
               in the transcript or just a single exon. Coordinates returned are those used for drawing.
               Also looks for mismatches between the end of the hit and the end of the exon; takes into account
               the end of the CDS if the evidence is a DnaPepAlignFeature, ie evidence that stops at the end of
               the CDS is not tagged if it's protein evidence. Also looks for 'extra' exons, ie those that are in
               the parsed cigar string but not in the transcript
  Returntype : Arrayref of arrayrefs (one per exon) - positions for drawing and also tags for hit/exon boundry mismatches

=cut

sub split_evidence_and_munge_gaps {
	my $self =  shift;
	my ($hit,$exons,$offset,$coding_coords,$obj_type) = @_;
	my $object    = $self->object;
	my $hit_seq_region_start = $hit->start;
	my $hit_seq_region_end   = $hit->end;
	my $hit_name = $hit->hseqname;
	if ($hit->hseqname eq 'NM_024848.1') { warn "hit: - $hit_seq_region_start--$hit_seq_region_end"; }
	if ($hit->hseqname eq 'BC059409.1') { warn "hit: - $hit_seq_region_start--$hit_seq_region_end"; }

	my $coords;
	my $last_end;

	foreach my $exon (@{$exons}) {
		my $estart = $exon->start;
		my $eend   = $exon->end;
		my $ename  = $exon->stable_id;
		if ($hit->hseqname eq 'NM_024848.1') { warn "  exon $ename: - $estart:$eend; last_end = $last_end"; }
		if ($hit->hseqname eq 'BC059409.1') { warn "  exon $ename: - $estart:$eend; last_end = $last_end"; }
#		if ($ename eq 'ENSE00000899040') { warn "HIT = ",$hit->hseqname,": exon $ename:$estart:$eend, hit $hit_seq_region_start:$hit_seq_region_end"; }
		my @coord;

		#catch any extra 'exons' that are in a parsed hit
		my $extra_exon = 0;
		if ( $last_end && ($last_end < $hit_seq_region_end) && ($estart > $hit_seq_region_end) ) {
			$extra_exon = $hit;
			$last_end = $eend;
		}

		elsif ( ($eend < $hit_seq_region_start) || ($estart > $hit_seq_region_end) ) {
			$last_end = $eend;
			next;
		}

#		if ($hit->hseqname eq 'NP_003757.1') { warn "  analysing"; }

		#add tags for hit/exon start/end mismatches - protein evidence has some leeway (+-3), DNA has to be exact
		#CCDS evidence is considered as protein evidence even though it is a DNA feature 
		my ($left_end_mismatch, $right_end_mismatch);
		my ($b_start,$b_end);
		if ( ($obj_type eq 'Bio::EnsEMBL::DnaPepAlignFeature') || ($hit_name =~ /^CCDS/) ) {
			my $cod_start = $coding_coords->[0];
			my $cod_end   = $coding_coords->[1];
			$b_start = $cod_start > $estart ? $cod_start : $estart;
			$b_end = $cod_end < $eend ? $cod_end : $eend;

#			if ($hit->hseqname eq 'NP_003757.1') { warn "   CDS: - $cod_start:$cod_end, $start:$end";  }
#			if ($ename eq 'ENSE00000899040') { warn "   CDS: - $cod_start:$cod_end, $start:$end";  }

			$left_end_mismatch  = (abs($b_start - $hit_seq_region_start) < 4) ? 0 : $b_start - $hit_seq_region_start;
			$right_end_mismatch = (abs($b_end - $hit_seq_region_end) < 4)     ? 0 : $hit_seq_region_end - $b_end;
		}
		else {
			$left_end_mismatch  = $estart == $hit_seq_region_start ? 0 : $estart - $hit_seq_region_start;
			$right_end_mismatch = $eend   == $hit_seq_region_end   ? 0 : $hit_seq_region_end - $eend;
		}

		#map start and end positions of the hit from genomic coordinates to transcript genomic coordinates
		my $start;
		if ( ($obj_type eq 'Bio::EnsEMBL::DnaPepAlignFeature') || ($hit_name =~ /^CCDS/) ) {
			$start = abs($hit_seq_region_start - $b_start) > 3 ? $hit_seq_region_start : $b_start;
		}
		else {
			$start = $hit_seq_region_start >= $estart ? $hit_seq_region_start : $estart;
		}
		$start -= $offset;
		my $munged_start = $start + $object->munge_gaps( 'supporting_evidence_transcript', $start );
		my $end;
		if ( ($obj_type eq 'Bio::EnsEMBL::DnaPepAlignFeature') || ($hit_name =~ /^CCDS/) ) {
			$end =  abs($hit_seq_region_end - $b_end) > 3 ? $hit_seq_region_end : $b_end;
		}
		else {
			$end = $hit_seq_region_end <= $eend ? $hit_seq_region_end : $eend;
		}
		$end -= $offset;
		my $munged_end = $end + $object->munge_gaps( 'supporting_evidence_transcript', $end );

		my $details = {
			'munged_start' => $munged_start,
			'munged_end'   => $munged_end,
			'left_end_mismatch' => $left_end_mismatch,
			'right_end_mismatch' => $right_end_mismatch,
			'extra_exon' => $extra_exon,
			'exon' => $exon,
			'hit' => $hit,
		};

		push @{$coords}, $details;
##		push @{$coords}, [ $munged_start, $munged_end, $hit, $left_end_mismatch, $right_end_mismatch, $exon, $extra_exon ];
	}
	return $coords;
}		


1;

