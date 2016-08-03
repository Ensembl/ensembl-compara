=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Component::Transcript::SupportingEvidence;

use strict;

use Bio::EnsEMBL::Intron;
use Bio::EnsEMBL::Registry;

use base qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
  $self->configurable(1);
  $self->has_image(1);
}

sub content {
  my $self   = shift;
  my $hub    = $self->hub;
  my $object = $self->object || $self->hub->core_object('transcript');
  my $html   = '<div class="content">';
  
  if (!$object->count_supporting_evidence) {
    $html .=  ' <dt>No Evidence</dt><dd>';
    
    # show message for transcripts with no evidence
    if ($hub->type =~ /otter/ || $object->db_type eq 'vega' ){
      $html .= '
      <p>
        Although this Vega Havana transcript has been manually annotated and its structure is supported by experimental evidence, this evidence is currently missing from the database.
        We are adding the evidence to the database as time permits
      </p>';
    } else {
      $html .= '<p>There is no supporting evidence available for this transcript</p>';
    }
  } else {
    $html .= $self->_content;
  }
  
  $html .= '</dd>';
  $html .= sprintf qq{<p>Click <a href="%s">here</a> for a summary of the evidence that supports all the transcripts of this gene</p>}, $hub->url({ type => 'Gene', action => 'Evidence', t => undef });
  
  return $html;
}

sub _content {
  my $self             = shift;
  my $hub              = $self->hub;
  my $object           = $self->object || $self->hub->core_object('transcript');
  my $species          = $hub->species;
  my $dbentry_adap     = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'DBEntry'); # dbentry adaptor used to get db_name of the hit
  my $logic_name       = $object->logic_name;
  my $image_width      = $self->image_width ? $self->image_width : 700;          # user defined width in pixels
  my $context          = $hub->param('context') ? $hub->param('context') : 100;  # context is user defined size of introns
  my $extent           = $context eq 'FULL' ? 1000 : $context;                   # set 5' and 3' extensions to the image depending on the context
  my $image_config     = $hub->get_imageconfig('supporting_evidence_transcript');
  my $transcript       = $object->Obj;
  my $length           = $transcript->length;
  my $translation      = $transcript->translation;
  my @missing_evidence = map $_->value, @{$transcript->get_all_Attributes('NoEvidence') || []} ;
  my $db               = $object->get_db;
  my $db_key           = 'DATABASE_' . uc $db;
  my $info_summary     = $hub->species_defs->databases->{$db_key}{'tables'};
  my @slice_defs       = ([ 'supporting_evidence_transcript', 'munged', $extent ]); # get both real slice and normalised slice (ie introns set to fixed width)

  my $trans_obj        = {}; # used to store details of transcript
  my $al_obj           = {}; # used to store all details of alignments
  
  $image_config->set_parameters({
    container_width => $length,
    image_width     => $image_width,
  });

  $trans_obj->{'transcript'}     = $transcript;
  $trans_obj->{'web_transcript'} = $object;

  ## Turn on track associated with this db/logic name
  $image_config->modify_configs(
    [ $image_config->get_track_key('TSE_transcript', $object) ],
    { qw(display supporting_evidence_transcript strand f menu no) }  ## show on the forward strand only
  );

  ###
  ## config modification now done in imageconfig because of a bug that prevents chages here
  ## being reflected in the configuration menu


  $object->__data->{'slices'}{$_->[0]} = $object->get_transcript_slices($_) || warn "Couldn't get slice" for @slice_defs;

  my $transcript_slice = $object->__data->{'slices'}{'supporting_evidence_transcript'}[1];
  my $sub_slices       = $object->__data->{'slices'}{'supporting_evidence_transcript'}[2];
  my $fake_length      = $object->__data->{'slices'}{'supporting_evidence_transcript'}[3];

  $image_config->container_width($fake_length); # sets width of image
  $trans_obj->{'subslices'}   = $sub_slices;    # used to draw lines for exons
  $trans_obj->{'extent'}      = $extent;        # used for padding between exons and at the end of the transcript
  $trans_obj->{'object_type'} = $logic_name;    # used for drawing the legend for vega / E! transcripts

  # identify coordinates of the portions of introns and exons to be drawn. Include the exon object
  my $intron_exon_slices;
  my $ens_exons;
  my $offset = $transcript_slice->start -1;
  my $exons  = $transcript->get_all_Exons;
  
  foreach my $exon (@$exons) {
    my $es     = $exon->start - $offset;
    my $ee     = $exon->end   - $offset;
    my $munge  = $object->munge_gaps('supporting_evidence_transcript', $es);
    push @$ens_exons, [ $es + $munge, $ee + $munge, $exon ];
  }
  
  my $e_counter = 0;
  my $e_count   = scalar @$ens_exons;

  # reverse the order of exons if the strand is negative
  my @exons = $transcript->strand == 1 ? @$ens_exons : reverse @$ens_exons;
  
  SUBSLICE:
  foreach my $subslice (@$sub_slices) {
    my $subslice_start = $subslice->[0]+$subslice->[2];
    my $subslice_end   = $subslice->[1]+$subslice->[2];
    my ($exon_start, $exon_end);
    
    for (; $e_counter < $e_count; $e_counter++) {
      my $exon    = $exons[$e_counter];
      $exon_start = $exon->[0];
      $exon_end   = $exon->[1];

      # if the exon is still within the subslice then work with it
      if ($subslice_end > $exon_end) {
        push @$intron_exon_slices, [ $subslice_start, $exon_start ] if $intron_exon_slices; # don't add the first one
        push @$intron_exon_slices, $exon;

        # set subslice to the end of the ready for the next exon iteration
        $subslice_start = $exon_end;
      } else {
        # otherwise draw a line to the end of the subslice and move on
        push @$intron_exon_slices, [ $exons[$e_counter-1]->[1], $subslice_end ];
        next SUBSLICE;
      }
    }
  }

  $trans_obj->{'introns_and_exons'} = $intron_exon_slices;

  # add info on normalised coding region
  my $raw_coding_start = defined($transcript->coding_region_start) ? $transcript->coding_region_start - $offset : '';
  my $raw_coding_end   = defined($transcript->coding_region_end)   ? $transcript->coding_region_end   - $offset : '';
  my $coding_start     = $raw_coding_start + $object->munge_gaps('supporting_evidence_transcript', $raw_coding_start);
  my $coding_end       = $raw_coding_end   + $object->munge_gaps('supporting_evidence_transcript', $raw_coding_end);
  
  $trans_obj->{'coding_start'} = $coding_start;
  $trans_obj->{'coding_end'}   = $coding_end;

  # get introns (would be nice to have an API call but until this is there do this)
  my @introns;
  my $s = 0;
  my $e = 1;
  my $t = scalar @$exons;
  
  while ($e < $t) {
    my $i = Bio::EnsEMBL::Intron->new($exons->[$s], $exons->[$e]);
    push @introns, [ $i, $exons->[$s]->stable_id, $exons->[$e]->stable_id ];
    $s++;
    $e++;
  }

  #intron supporting features
  my $intron_supporting_features;
  foreach my $isf (@{$transcript->get_all_IntronSupportingEvidence}) {
    my $start = $isf->seq_region_start - $offset;
    my $end   = $isf->seq_region_end - $offset;
    my $munged_start = $start + $object->munge_gaps('supporting_evidence_transcript', $start);
    my $munged_end   = $end + $object->munge_gaps('supporting_evidence_transcript', $end);
    
    push  @$intron_supporting_features, {
      real_start => $isf->seq_region_start,
      real_end   => $isf->seq_region_end,
      hit_name   => $isf->hit_name,
      munged_start => $munged_start,
      munged_end   => $munged_end,
      score        => $isf->score,
    };
  }
  $al_obj->{'intron_support'} = $intron_supporting_features;

  # add info on non_canonical splice site sequences for introns
  my @canonical_sites = (['GT', 'AG'], ['GC', 'AG'], ['AT', 'AC'], ['NN', 'NN']); # these are considered not to be non-canonical
  my $non_can_introns;
  my $hack_c = 1; # set to zero to tag first intron - used for development to highlight first intron
  
  foreach my $i_details (@introns) {
    my $i            = $i_details->[0];
    my $seq          = $i->seq;
    my $l            = length $seq;
    my $donor_seq    = substr $seq, 0, 2; # 5'
    my $acceptor_seq = $hack_c ? substr $seq, $l - 2, 2 : 'CC';
    
    $hack_c++;
    
    my $e_details = "Non-canonical splice site ($donor_seq:$acceptor_seq) between exons $i_details->[1] and $i_details->[2]";
    my $canonical = 0;
    
    foreach my $seqs (@canonical_sites) {
      $canonical = 1 if $donor_seq eq $seqs->[0] && $acceptor_seq eq $seqs->[1];
    }
    
    if (!$canonical) {
      my $is           = $i->start - $offset;
      my $ie           = $i->end   - $offset;
      my $munged_start = $is + $object->munge_gaps('supporting_evidence_transcript', $is);
      my $munged_end   = $ie + $object->munge_gaps('supporting_evidence_transcript', $ie);
      
      push @$non_can_introns, [ $munged_start, $munged_end, $donor_seq, $acceptor_seq, $e_details, $i ];
    }
  }
  
  $trans_obj->{'non_can_introns'} = $non_can_introns;

  # add info on normalised transcript_supporting_evidence
  my $t_evidence = {};
  my %t_ids;
  
  foreach my $evi (@{$transcript->get_all_supporting_features}) {
    my $coords;
    my $hit_name = $evi->hseqname;
    $t_ids{$hit_name}++;

    $t_evidence->{$hit_name}{'hit_name'}         = $hit_name;
    $t_evidence->{$hit_name}{'hit_db'}           = $dbentry_adap->get_db_name_from_external_db_id($evi->external_db_id);
    $t_evidence->{$hit_name}{'hit_type'}         = $evi->isa('Bio::EnsEMBL::DnaPepAlignFeature') ? 'protein' : $self->hit_type($info_summary, $evi);
    $t_evidence->{$hit_name}{'evidence_removed'} = 1 if grep $hit_name eq $_, @missing_evidence;
    $t_evidence->{$hit_name}{'logic_name'}       = $evi->analysis->logic_name;

    #for non-vega genes, split evidence into ungapped features (ie parse cigar string),
    #map onto exons ie determine mismatches and munge (ie account for gaps)

    my $first_feature = 1;
    my $last_end      = 0;
    my @features      = $evi->ungapped_features;

    for (my $c; $c < scalar @features; $c++) {
      my $feature       = $features[$c];
      my $munged_coords = $self->split_evidence_and_munge_gaps($feature, $exons, $offset, [ $raw_coding_start + $offset, $raw_coding_end + $offset ], ref $evi);

      if ($logic_name !~ /otter/) {
	if ($last_end) {
	  if ($evi->isa('Bio::EnsEMBL::DnaPepAlignFeature')) {
	    $munged_coords->[0]{'hit_mismatch'} = $feature->hstart - $last_end if abs($feature->hstart - $last_end) > 3;
	  } else {
	    if (abs($feature->hstart - $last_end) > 1) {
	      $munged_coords->[0]{'hit_mismatch'} = $feature->hstart - $last_end;
	    } elsif ($feature->hstart == $last_end) {
	      $munged_coords->[0]{'hit_mismatch'} = 0;
	    }
	  }
	}
	
	# is the first feature beyond the end of the transcript
	if ($first_feature) {
	  if ($transcript->strand == 1) {
	    $munged_coords->[0]{'lh-ext'} = $exons->[0]->seq_region_start - $feature->end if $feature->end < $exons->[0]->seq_region_start;
	  } elsif ($feature->start > $exons->[0]->seq_region_end) {
	    $munged_coords->[0]{'rh-ext'} = $feature->start - $exons->[0]->seq_region_end;
	  }
	  $first_feature = 0;
	}

	# is the last feature beyond the end of the transcript
	if ($c == scalar(@features) - 1) {
	  if ($transcript->strand == 1) {
	    $munged_coords->[0]{'rh-ext'} = $feature->start - $exons->[-1]->seq_region_end if $feature->start > $exons->[-1]->seq_region_end;
	  } elsif ($feature->end < $exons->[-1]->seq_region_start) {
	    $munged_coords->[0]{'lh-ext'} = $exons->[-1]->seq_region_start - $feature->end;
	  }
	}
      }
	
      $last_end = $feature->hend;

      # reverse the exon order if on the reverse strand
      if ($transcript->strand == 1) {
        push @{$t_evidence->{$hit_name}{'data'}}, $munged_coords->[0];
      } else {
        unshift  @{$t_evidence->{$hit_name}{'data'}}, $munged_coords->[0];
      }
    }
  }

  # calculate total length of the hit (used for sorting the display)
  while (my ($hit_name, $hit_details) = each (%$t_evidence)) {
    my $tot_length;

    foreach my $match (@{$hit_details->{'data'}}) {
      my $len = abs($match->{'munged_end'} - $match->{'munged_start'}) + 1;
      $tot_length += $len;
    }
    
    $t_evidence->{$hit_name}{'hit_length'} = $tot_length;
  }
  
  $al_obj->{'transcript_evidence'} = $t_evidence;


  # add info on additional supporting_evidence (exon level) (mot Vega)
  my $e_evidence = {};
  my $evidence_checks;
  my %evidence_ends;
  
  if ($logic_name !~ /otter/) {
    foreach my $exon (@$exons) {
      EVI:
      foreach my $evi (@{$exon->get_all_supporting_features}) {
        my $hit_name = $evi->hseqname;

        # only proceed (for ensembl) if this hit name has *not* been used as transcript evidence 
        # (commented out in e62)
#        next EVI if exists $t_evidence->{$hit_name};

        my $hit_seq_region_start = $evi->seq_region_start;
        my $hit_seq_region_end   = $evi->seq_region_end;

        #calculate beginning and end of the combined hit (first steps are needed to autovivify)
        $evidence_ends{$hit_name}{'start'} = $hit_seq_region_start unless exists $evidence_ends{$hit_name}{'start'};
        $evidence_ends{$hit_name}{'start'} = $hit_seq_region_start if $hit_seq_region_start < $evidence_ends{$hit_name}{'start'};
        $evidence_ends{$hit_name}{'end'}   = $hit_seq_region_end   unless exists $evidence_ends{$hit_name}{'end'};
        $evidence_ends{$hit_name}{'end'}   = $hit_seq_region_end   if $hit_seq_region_end > $evidence_ends{$hit_name}{'end'};

        # ignore duplicate entries
        next EVI if defined @{$evidence_ends{$hit_name}{'starts_and_ends'}} && grep $_ eq "$hit_seq_region_start:$hit_seq_region_end", @{$evidence_ends{$hit_name}{'starts_and_ends'}};
        
        push @{$evidence_ends{$hit_name}{'starts_and_ends'}}, "$hit_seq_region_start:$hit_seq_region_end";

        my $hit_mismatch;
        my $hit_start = $evi->hstart;

        # compare the start of this hit with the end of the last one -
        # only DNA features have to match exactly, protein features have a tolerance of +- 3
        if ($evi->isa('Bio::EnsEMBL::DnaPepAlignFeature')) {
          $hit_mismatch = $hit_start - $evidence_ends{$hit_name}{'last_end'} if $evidence_ends{$hit_name}{'last_end'} && abs($hit_start - $evidence_ends{$hit_name}{'last_end'}) > 3;
        } else {
          if ($evidence_ends{$hit_name}{'last_end'} && abs($hit_start - $evidence_ends{$hit_name}{'last_end'}) > 1) {
            $hit_mismatch = $hit_start - $evidence_ends{$hit_name}{'last_end'};
          } elsif ($hit_start == $evidence_ends{$hit_name}{'last_end'}) {
            $hit_mismatch = 0;
          }
        }

        # note position of end of the hit for next iteration
        $evidence_ends{$hit_name}{'last_end'} = $evi->hend;

        # coordinate munging:
        # pass it a single exon but could pass it all if them if we wanted to match the hit across all exons
        my $munged_coords = $self->split_evidence_and_munge_gaps($evi, [ $exon ], $offset, [ $raw_coding_start + $offset, $raw_coding_end + $offset ], ref $evi);
        foreach my $munged_hit (@$munged_coords) {
          # add tag if there is a mismatch between exon / hit boundries
          $munged_hit->{'hit_mismatch'} = $hit_mismatch if defined $hit_mismatch;

          if ($transcript->strand == 1) {
            push @{$e_evidence->{$hit_name}{'data'}}, $munged_hit;
          }  else {
            unshift @{$e_evidence->{$hit_name}{'data'}}, $munged_hit;
          }
        }

        $e_evidence->{$hit_name}{'hit_name'}         = $hit_name;
        $e_evidence->{$hit_name}{'logic_name'}       = $evi->analysis->logic_name;
        $e_evidence->{$hit_name}{'hit_db'}           = $dbentry_adap->get_db_name_from_external_db_id($evi->external_db_id);
        $e_evidence->{$hit_name}{'hit_type'}         = $evi->isa('Bio::EnsEMBL::DnaPepAlignFeature') ? 'protein' : $self->hit_type($info_summary, $evi);
        $e_evidence->{$hit_name}{'evidence_removed'} = 1 if grep $hit_name eq $_, @missing_evidence;
      }
    }
  }
  
  # remove any non-perfect matching evidence where it overlaps perfect matching evidence
  while (my ($hit, $det) = each (%$e_evidence)) {
    THIS_MATCH:
    foreach my $this_match (@{$det->{'data'}}) {
      next THIS_MATCH unless $this_match;
      next THIS_MATCH unless $this_match->{'left_end_mismatch'} || $this_match->{'right_end_mismatch'};
      
      my $this_start = $this_match->{'hit'}->seq_region_start;
      my $this_end   = $this_match->{'hit'}->seq_region_end;
      
      foreach my $check_match (@{$det->{'data'}}) {
        next unless $check_match;
        
        my $checked_start = $check_match->{'hit'}->seq_region_start;
        my $checked_end   = $check_match->{'hit'}->seq_region_end;
        
        next if $checked_start == $this_start && $checked_end == $this_end;
        
        if (
          ($checked_start == $this_start && $checked_end   != $this_end)   ||
          ($checked_end   == $this_end   && $checked_start != $this_start) ||
          ($this_end > $checked_end && $this_start < $checked_start)       ||
          ($this_end < $checked_end && $this_start > $checked_start)
        ) {
          $this_match = undef;
          next THIS_MATCH;
        }
      }
    }
  }
  
  while (my ($hit_name, $coords) = each (%evidence_ends)) {
    if (@{$e_evidence->{$hit_name}{'data'}}) {
      if ($coords->{'start'} < $transcript->start) {
        my $diff = $transcript->start - $coords->{'start'};
        $e_evidence->{$hit_name}{'data'}[0]{'lh_ext'} = $transcript->start - $coords->{'start'};
      }
      
      $e_evidence->{$hit_name}{'data'}[-1]{'rh_ext'} = $coords->{'end'} - $transcript->end if $coords->{'end'} > $transcript->end;
    }
  }

  # calculate total length of the hit (used for sorting the display)
  while (my ($hit_name, $hit_details) = each (%$e_evidence)) {
    my $tot_length;
    
    foreach my $match (@{$hit_details->{'data'}}) {
      my $l = abs($match->{'munged_end'} - $match->{'munged_start'}) + 1;
      $tot_length += $l;
    }
    
    $e_evidence->{$hit_name}{'hit_length'} = $tot_length;
  }

  # store it
  $al_obj->{'evidence'} = $e_evidence;

  # modify track captions if there is no evidence for a particular type
  if (!%{$al_obj->{'transcript_evidence'}}) {
    $image_config->modify_configs(
      [ 'TSE_generic_match_label' ],
      { 'caption', 'Transcript evi. (none)' }
    );
  }
  
  if (! %{$al_obj->{'evidence'}}) {
    $image_config->modify_configs(
      [ 'SE_generic_match_label' ],
      { 'caption', 'Exon evi. (none)' }
    );
  }

  # store everything needed for drawing
  $image_config->cache('trans_object', $trans_obj);
  $image_config->cache('align_object', $al_obj);

  # draw and render image
  my $image = $self->new_image(
    $transcript_slice, $image_config,
    [ $object->stable_id ]
  );
  
  return if $self->_export_image($image, 'no_text');
  
  $image->imagemap         = 'yes';
  $image->{'panel_number'} = 'top';
  $image->set_button( 'drag', 'title' => 'Drag to select region' );
  
  return $image->render;
}


=head2 split_evidence_and_munge_gaps

  Arg [1]  : B::E::DnaDnaAlignFeature, B::E::DnaPepAlignFeature or B::E::FeaturePair
  Arg [2]  : Arrayref of B::E::Exons
  Arg [3]  : Transcript start (ie offset to convert genomic to transcript genomic coordinates)
  Arg [4]  : Arrayref of coding positions
  Arg [5]  : type of evidence (B::E::DnaDnaAlignFeature or B::E::DnaPepAlignFeature)
  Description: Takes a supporting feature and maps to all exons supplied - depending on usage either all exons
         in the transcript or just a single exon. Coordinates returned are relevant to the munged slice,
         ie fixed length introns, and are those used for drawing.
         Also looks for mismatches between the end of the hit and the end of the exon; takes into account
         the end of the CDS if the evidence is a DnaPepAlignFeature, ie evidence that stops at the end of
         the CDS is not tagged if it's protein evidence.
         Also looks for 'extra' exons, ie those that are in the parsed cigar string or combined exon hits
         but not in the transcript.
  Returntype : Arrayref of hashrefs - positions for drawing and also tags for hit/exon boundry mismatches and
         extra exons

=cut

sub split_evidence_and_munge_gaps {
  my $self = shift;
  my ($hit, $exons, $offset, $coding_coords, $obj_type) = @_;
  my $object               = $self->object || $self->hub->core_object('transcript');
  my $hit_seq_region_start = $hit->start;
  my $hit_seq_region_end   = $hit->end;
  my $hit_name             = $hit->hseqname;
  my $past_hit_end         = 0;
  my $ln                   = $object->logic_name;
  my ($cod_start, $cod_end, $coords, $last_end, $evidence_type);

  # note evidence type
  if ($obj_type eq 'Bio::EnsEMBL::DnaPepAlignFeature' || $hit_name =~ /^CCDS/) {
    $cod_start = $coding_coords->[0];
    $cod_end   = $coding_coords->[1];

    # if protein evidence lies completely outside of the CDS then treat it as a DnaDnaAlignFeature
    if ($hit_seq_region_start > $cod_end || $hit_seq_region_end < $cod_start) {
      $evidence_type = 'pretend_this_is_dna';
    } else {
      $evidence_type = 'protein';
    }
  } else {
    $evidence_type = 'dna';
  }
  
  foreach my $exon (@$exons) {
    next if $past_hit_end;
    
    my $estart = $exon->start;
    my $eend   = $exon->end;
    my $ename  = $exon->stable_id;

    # catch any extra 'exons' that are in a parsed hit
    my $extra_exon = 0;
    
    if ($last_end && $last_end < $hit_seq_region_end && $estart > $hit_seq_region_end) {
      $extra_exon = $hit;# if ($ln !~ /otter/); #uncomment to switch off mismatches for Vega transcripts
      $last_end   = $eend;
    } elsif ($eend < $hit_seq_region_start || $estart > $hit_seq_region_end) {
      $last_end = $eend;
      next;
    }

    # set this to save any further iteration if we're past the end of the exon
    $past_hit_end = 1 if $eend >= $hit_seq_region_end;

    # add tags for hit/exon start/end mismatches - protein evidence has some leeway (+-3), DNA has to be exact
    # CCDS evidence is considered as protein evidence even though it is a DNA feature
    my ($left_end_mismatch, $right_end_mismatch);
    my ($b_start, $b_end);

    if ($evidence_type eq 'protein') {
      $b_start =
        $eend      < $cod_start ? $estart    :
        $cod_start > $estart    ? $cod_start :
        $estart;
      
      $b_end =
        $estart  > $cod_end ? $eend    :
        $cod_end < $eend    ? $cod_end :
        $eend;
      
      $left_end_mismatch  = abs($b_start - $hit_seq_region_start) < 4 ? 0 : $b_start - $hit_seq_region_start;
      $right_end_mismatch = abs($b_end   - $hit_seq_region_end)   < 4 ? 0 : $hit_seq_region_end - $b_end;
    } else {
      $left_end_mismatch  = $estart == $hit_seq_region_start ? 0 : $estart - $hit_seq_region_start;
      $right_end_mismatch = $eend   == $hit_seq_region_end   ? 0 : $hit_seq_region_end - $eend;
    }

    # Map start and end positions of the hit from genomic coordinates to transcript genomic coordinates.
    # Account for off-by-three errors (which can impact on the display as just a pixel off) by setting
    # the boundry of the hit to the exon boundry in these cases
    my $start;
    
    if ($evidence_type eq 'protein') {
      $start =
        ($b_start - $hit_seq_region_start) > 4 ? $b_start :
        ($hit_seq_region_start - $b_start) < 4 ? $b_start :
        $hit_seq_region_start;
    } else {
      $start = $hit_seq_region_start >= $estart ? $hit_seq_region_start : $estart;
    }
    
    $start -= $offset;
    
    my $munged_start = $start + $object->munge_gaps('supporting_evidence_transcript', $start);
    my $end;
    
    if ($evidence_type eq 'protein') {
      $end =
        ($b_end - $hit_seq_region_end) < 4 ? $b_end :
        ($hit_seq_region_end - $b_end) > 4 ? $b_end : 
        $hit_seq_region_end;
    } else {
      $end = $hit_seq_region_end <= $eend ? $hit_seq_region_end : $eend;
    }
    
    $end -= $offset;
    
    my $munged_end = $end + $object->munge_gaps('supporting_evidence_transcript', $end);

    # don't even attempt to show any end mismatches for vega db genes, data won't allow it!
    if ($object->logic_name =~ /otter/) {
      $left_end_mismatch  = 0;
      $right_end_mismatch = 0;
    }

    #store everything so far
    my $details = {
      munged_start       => $munged_start,
      munged_end         => $munged_end,
      left_end_mismatch  => $left_end_mismatch,
      right_end_mismatch => $right_end_mismatch,
      extra_exon         => $extra_exon,
      exon               => $exon,
      hit                => $hit,
      evidence_type      => $evidence_type,
      exon_length        => $eend - $estart + 1,
      hit_length         => $hit_seq_region_end - $hit_seq_region_start + 1,
    };
    
    push @$coords, $details;
  }
  
  return $coords;
}

sub hit_type {
  # get type of evidence (to use as a key into the colour hash)
  my ($self, $info_summary, $evi) = @_;
  
  my %evidence_table_types = (
    'Bio::EnsEMBL::DnaDnaAlignFeature' => 'dna_align_feature',
    'Bio::EnsEMBL::DnaPepAlignFeature' => 'protein_align_feature',
  );
  
  my $logic_name = lc $evi->analysis->logic_name;
  my $evi_object = ref $evi;
  my $evi_type   = $evidence_table_types{$evi_object};
  
  return $info_summary->{$evi_type}{'analyses'}{$logic_name}{'web'}{'type'} || 'other';
}

1;
