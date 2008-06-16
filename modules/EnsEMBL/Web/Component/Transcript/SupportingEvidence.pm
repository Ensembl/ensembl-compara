package EnsEMBL::Web::Component::Transcript::SupportingEvidence;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);

use Data::Dumper;
$Data::Dumper::Maxdepth = 4;

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

	#set 5' and 3' extensions depending on the context
	my $extent       = $context eq 'FULL' ? 1000 : $context;
	
	my $config = $object->get_userconfig( "supporting_evidence_transcript" );
	$config->set( '_settings', 'width',  $image_width ); 

	#add transcript itself
	my $transcript = $object->Obj;
	$config->{'transcript'}{'transcript'} = $transcript;

	#get both real slice and normalised slice
	my @slice_defs = ( [ 'supporting_evidence_transcript', 'munged', $extent ] );
	foreach my $slice_type (@slice_defs) {
		$object->__data->{'slices'}{$slice_type->[0]} = $object->get_transcript_slices($slice_type) || warn "Couldn't get slice";	
	}

	my $transcript_slice = $object->__data->{'slices'}{'supporting_evidence_transcript'}[1];
	my $sub_slices       = $object->__data->{'slices'}{'supporting_evidence_transcript'}[2];

	my $fake_length      =  $object->__data->{'slices'}{'supporting_evidence_transcript'}[3];
    $config->container_width( $fake_length ); # sets width of image
	$config->{'id'} = $object->stable_id;
	$config->{'subslices'}  = $sub_slices; #used to draw lines for exons
    $config->{'extent'}     = $extent; #used for padding between exons and at the end of the transcript
	$config->{'fakeslice'}   = 1; # ??

#	warn Dumper($sub_slices);

	#add info on normalised exons (ie flattened introns)
	my $ens_exons;
	my $offset = $transcript_slice->start -1;
	my $exons = $object->Obj->get_all_Exons();
	foreach my $exon (@{$exons}) {
		my $es     = $exon->start - $offset;
		my $ee     = $exon->end   - $offset;
		my $munge  = $object->munge_gaps('supporting_evidence_transcript', $es);
		push @$ens_exons, [ $es + $munge, $ee + $munge, $exon ];
#		warn $exon->stable_id.":".$exon->start."-".$exon->end;
#		warn "munged exon = ",$es+$munge,"-",$ee+$munge;
	}
	$config->{'transcript'}{'exons'} = $ens_exons ;

	#this could be used to drawing a direction arrow on the image ...?
	$config->{'_draw_single_Transcript'} = 1;

	#add info normalised coding region
    my $raw_coding_start = defined($transcript->coding_region_start) ? $transcript->coding_region_start-$offset : $transcript->start-$offset;
    my $raw_coding_end   = defined($transcript->coding_region_end) ? $transcript->coding_region_end-$offset : $transcript->end-$offset;
    my $coding_start = $raw_coding_start + $object->munge_gaps( 'supporting_evidence_transcript', $raw_coding_start );
    my $coding_end   = $raw_coding_end   + $object->munge_gaps( 'supporting_evidence_transcript', $raw_coding_end );
	$config->{'transcript'}{'coding_start'} = $coding_start;
	$config->{'transcript'}{'coding_end'} = $coding_end;

	#add info on normalised transcript_supporting_evidence
	my $t_evidence;
	foreach my $evi (@{$transcript->get_all_supporting_features}) {
		my $hit_name = $evi->hseqname;
		$t_evidence->{$hit_name}{'hit_name'}   = $hit_name;

		#map evidence onto exons and account for gaps 
		my $munged_coords = $self->split_evidence_and_munge_gaps($evi,$exons,$offset);
		$t_evidence->{$hit_name}{'data'}       = $munged_coords;
			
		#calculate total length of the hit on the normalised slice (used for sorting in display)
		my $tot_length;
		foreach my $match (@{$munged_coords}) {
			my $l = int($match->[1] - $match->[0] ) + 1;
			$tot_length += $l;
		}
		$t_evidence->{$hit_name}{'hit_length'} = $tot_length;

		#note if the evidence extends beyond the ends of the transcript
		if ($evi->start < $transcript->start) {
			$t_evidence->{$hit_name}{'5_extension'} = 1;
		}
		if ($evi->end < $transcript->end) {
			$t_evidence->{$hit_name}{'3_extension'} = 1;
		}
	}
	$config->{'transcript'}{'transcript_evidence'} = $t_evidence;	

	#add info on additional supporting_evidence (exon level)
	my $e_evidence;
	my $evidence_checks;
	foreach my $exon (@{$exons}) {
	EVI:
		foreach my $evi (@{$exon->get_all_supporting_features}) {
			#only proceed if this hit name has not been used as transcript evidence
			my $hit_name = $evi->hseqname;
			next EVI if (exists($t_evidence->{$hit_name}));

			# shouldn't really have to look for exon supporting evidence that goes across boundries
			# since there shouldn't be any in e! And although there could be some for Havana there 
			# should be no supporting_features that are not in transcript supporting features or Havana.
			# Nevertheless use this code since it does the coordinate munging
			my $munged_coords = $self->split_evidence_and_munge_gaps($evi,[ $exon ],$offset);

			foreach my $munged_hit (@$munged_coords) {
#checking for unique hits not needed for the reasons above, but might be if Havana changes their approach
#			next EVI if ( (grep {$munged_hit->[0] eq $_} @{$evidence_checks->{$hit_name}{'starts'}})
#					   && (grep {$munged_hit->[1] eq $_} @{$evidence_checks->{$hit_name}{'stops'}} ) );
#				push @{$evidence_checks->{$hit_name}{'starts'}},  $munged_hit->[0];
#				push @{$evidence_checks->{$hit_name}{'stops'}},   $munged_hit->[1];
				push @{$e_evidence->{$hit_name}{'data'}}, $munged_hit ;
				
			}
			$e_evidence->{$hit_name}{'hit_name'} = $hit_name;
		}
	}

	#calculate total length of the hit on the normalised slice (used for sorting the display)
	while ( my ($hit_name, $hit_details) = each (%{$e_evidence})  ) {
		my $tot_length;
		foreach my $match (@{$hit_details->{'data'}}) {
			my $l = int($match->[1] - $match->[0]) + 1;
			$tot_length += $l;
		}
		$e_evidence->{$hit_name}{'hit_length'} = $tot_length;
	}
	$config->{'transcript'}{'evidence'} = $e_evidence;	


	my $image    = $object->new_image(
		$transcript_slice,$config,
		[ $object->stable_id ]
	);
	$image->imagemap = 'yes';

	return $image->render;

}

sub split_evidence_and_munge_gaps {
	my $self =  shift;
	my ($hit,$exons,$offset) = @_;
	my $object  = $self->object;
	my $hit_start = $hit->start;
	my $hit_end = $hit->end;
#	if ($hit->hseqname eq 'P59047') { warn "hits - $hit_start--$hit_end";}
	my $coords;
	foreach my $exon (@{$exons}) {
		my $estart = $exon->start;
		my $eend   = $exon->end;
#		if ($hit->hseqname eq 'P59047') { warn "**exons - $estart:$eend"; }
		my @coord;
		next if ( ($eend < $hit_start) || ($estart > $hit_end) ); 
		my $start = $hit_start >= $estart ? $hit_start : $estart;
#		if ($hit->hseqname eq 'P59047') { warn "****calculated start = $start (minus offset of $offset = ",$start-$offset,")"; }
		$start -= $offset;
		my $munged_start = $start + $object->munge_gaps( 'supporting_evidence_transcript', $start );
		my $end    = $hit_end <= $eend ? $hit_end : $eend;
#		if ($hit->hseqname eq 'P59047') { warn "****calculated end = $end (minus offset of $offset = ",$end-$offset,")"; }
		$end -= $offset;
		my $munged_end = $end + $object->munge_gaps( 'supporting_evidence_transcript', $end );
		push @{$coords}, [$munged_start, $munged_end, $hit];
	}
#	if ($hit->hseqname eq 'P59047') {
#		warn Dumper($coords);
#	}
	return $coords;
}		


1;

