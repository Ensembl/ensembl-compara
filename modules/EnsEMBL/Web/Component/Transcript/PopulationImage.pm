=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Transcript::PopulationImage;

use strict;

use base qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
  $self->has_image(1);
}

sub content {
  my $self      = shift;
  my $hub       = $self->hub;
  my $object    = $self->object || $self->hub->core_object('transcript');
  my $stable_id = $object->stable_id;
  my $extent    = $object->extent;
  
  # set up VCF if needed
  my $vdb           = $object->Obj->adaptor->db->get_db_adaptor('variation');
  my $species_defs  = $self->hub->species_defs;
  my $collections   = $species_defs->ENSEMBL_VCF_COLLECTIONS;

  if($collections && $vdb->can('use_vcf')) {
    $vdb->vcf_config_file($collections->{'CONFIG'});
    $vdb->vcf_root_dir($species_defs->DATAFILE_BASE_PATH);
    $vdb->use_vcf($collections->{'ENABLED'});
  }
  
  # Get two slices -  gene (4/3x) transcripts (+-EXTENT)
  foreach my $slice_type (
    [ 'transcript',     'normal', '20%'  ],
    [ 'tsv_transcript', 'munged', $extent ],
  ) { 
    $object->__data->{'slices'}{$slice_type->[0]} = $object->get_transcript_slices($slice_type) || warn "Couldn't get slice";
  }

  my $transcript_slice = $object->__data->{'slices'}{'tsv_transcript'}[1];
  my $sub_slices       = $object->__data->{'slices'}{'tsv_transcript'}[2]; 
  my $fake_length      = $object->__data->{'slices'}{'tsv_transcript'}[3];

  # Variants
  my ($count_sample_snps, $sample_snps, $context_count) = $object->getFakeMungedVariationsOnSlice($transcript_slice, $sub_slices);
  my $start_difference = $object->__data->{'slices'}{'tsv_transcript'}[1]->start - $object->__data->{'slices'}{'transcript'}[1]->start;
  my @transcript_snps;
  
  push @transcript_snps, [ $_->[2]->start + $start_difference, $_->[2]->end + $start_difference, $_->[2] ] for @$sample_snps;

  # Taken out domains (prosite, pfam)

  # Tweak the configurations for the five sub images ------------------
  # Intronless transcript top and bottom (to draw snps, ruler and exon backgrounds)
  my @ens_exons;
  
  foreach my $exon (@{$object->Obj->get_all_Exons}) { 
    my $offset = $transcript_slice->start -1;
    my $es     = $exon->start - $offset;
    my $ee     = $exon->end   - $offset;
    my $munge  = $object->munge_gaps('tsv_transcript', $es);
    push @ens_exons, [ $es + $munge, $ee + $munge, $exon ];
  }
   
  # General page configs -------------------------------------
  # Get 4 configs (one for each section) set width to width of context config
  my $configs;
  my $image_width = $self->image_width     || 800;
  my $context     = $hub->param('context') || 100;

  foreach (qw(transcript transcripts_bottom transcripts_top)) {
    $configs->{$_} = $hub->get_imageconfig({type => 'transcript_population', cache_code => $_});
    $configs->{$_}->set_parameters({
      image_width  => $image_width, 
      slice_number => '1|1',
      context      => $context  
    });
    
    $configs->{$_}->{'id'} = $stable_id;
  }

  $configs->{'transcript'}->set_parameters({ container_width => $object->__data->{'slices'}{'transcript'}[1]->length, single_Transcript => $stable_id });  
  $configs->{'transcript'}->{'filtered_fake_snps'} = \@transcript_snps;
 
  foreach(qw(transcripts_top transcripts_bottom)) {
    $configs->{$_}->{'extent'}      = $extent;
    $configs->{$_}->{'transid'}     = $stable_id;
    $configs->{$_}->{'transcripts'} = [{ exons => \@ens_exons }];
    $configs->{$_}->{'snps'}        = $sample_snps;
    $configs->{$_}->{'subslices'}   = $sub_slices;
    $configs->{$_}->{'fakeslice'}   = 1;
    $configs->{$_}->set_parameters({ container_width => $fake_length });
  }

  $configs->{'snps'} = $hub->get_imageconfig({type => 'gene_variation', cache_code => 'snps'});
  $configs->{'snps'}->set_parameters({
    image_width     => $image_width,
    container_width => 100,
    slice_number    => '1|1',
    context         => $context
  });
  
  $configs->{'snps'}->{'snp_counts'} = [ $count_sample_snps, scalar @$sample_snps, $context_count ];
  $configs->{'transcript'}->get_node('scalebar')->set('label', 'Chr. ' . $object->__data->{'slices'}{'transcript'}[1]->seq_region_name);
  
  ## Turn on track associated with this db/logic name
  $configs->{'transcript'}->modify_configs( 
    [ $configs->{'transcript'}->get_track_key('transcript', $object) ],
    {qw(display on show_labels off)}  ## also turn off the transcript labels
  );
  
  # SNP stuff ------------------------------------------------------------
  my ($containers_and_configs, $haplotype) = $self->sample_configs($transcript_slice, $sub_slices, $fake_length);

  # -- Map SNPs for the last SNP display to fake even spaced co-ordinates
  # @snps: array of arrays  [fake_start, fake_end, B:E:Variation obj]
  my $snp_rel         = 5;  ## relative length of snp to gap in bottom display
  my $snp_fake_length = -1; ## end of last drawn snp on bottom display
  my @fake_snps;
  
  foreach (sort { $a->[0] <=> $b->[0] } @$sample_snps) {
    $snp_fake_length += $snp_rel + 1;
    
    push @fake_snps, [
      $snp_fake_length - $snp_rel + 1, 
      $snp_fake_length, 
      $_->[2], 
      $transcript_slice->seq_region_name,
      $transcript_slice->strand > 0 ?
        ($transcript_slice->start + $_->[2]->start - 1, $transcript_slice->start + $_->[2]->end   - 1) :
        ($transcript_slice->end   - $_->[2]->end   + 1, $transcript_slice->end   - $_->[2]->start + 1)
    ];
  }
  
  if (scalar @$haplotype) {
    $configs->{'snps'}->get_node('snp_fake_haplotype')->set('display', 'on');
    $configs->{'snps'}->get_node('tsv_haplotype_legend')->set('display', 'on');
    $configs->{'snps'}->{'snp_fake_haplotype'} = $haplotype;
  }
  
  $configs->{'snps'}->set_parameters({ container_width => $snp_fake_length });
  $configs->{'snps'}->{'snps'}      = \@fake_snps;
  $configs->{'snps'}->{'reference'} = $hub->param('reference') || '';
  $configs->{'snps'}->{'fakeslice'} = 1;

  ## -- Render image ----------------------------------------------------- ##
  # Send the image pairs of slices and configurations

  my $image = $self->new_image([
     $object->__data->{'slices'}{'transcript'}[1], $configs->{'transcript'},
     $transcript_slice, $configs->{'transcripts_top'},
     @$containers_and_configs,
     $transcript_slice, $configs->{'transcripts_bottom'},
     $transcript_slice, $configs->{'snps'},
    ],
    [ $stable_id ]
  );
  
  return if $self->_export_image($image, 'no_text');

  $image->imagemap         = 'yes';
  $image->{'panel_number'} = 'top';
  $image->set_button('drag', 'title' => 'Drag to select region');
  
  return $image->render . $self->_info(
    'Configuring the display',
    sprintf '<p>Tip: use the "<strong>Configure this page</strong>" link on the left to customise the exon context and types of variants displayed above.<br />%s</p>', $self->variations_missing($configs->{'snps'}, $context)
  );
}

sub sample_configs {
  my ($self, $transcript_slice, $sub_slices, $fake_length) = @_;
  my $hub       = $self->hub;
  my $object    = $self->object || $self->hub->core_object('transcript');
  my $stable_id = $object->stable_id;
  my $extent    = $object->extent;
  my @containers_and_configs; ## array of containers and configs
  my @haplotype;
  my $strain_slice_adaptor = $hub->database('variation')->get_StrainSliceAdaptor;
  
  # THIS IS A HACK. IT ASSUMES ALL COVERAGE DATA IN DB IS FROM SANGER fc1
  # Only display coverage data if source Sanger is on 
  my $display_coverage = $hub->param('opt_sanger') eq 'off' ? 0 : 1;
  
  foreach my $sample ($object->get_samples) {
    my $sample_slice = $strain_slice_adaptor->get_by_strain_Slice($sample, $transcript_slice); 

    next unless $sample_slice; 
    
    ## Initialize content
    my $sample_config = $hub->get_imageconfig({type => 'transcript_population', cache_code => $sample});
    $sample_config->init_sample_transcript;
    $sample_config->{'id'}         = $stable_id;
    $sample_config->{'subslices'}  = $sub_slices;
    $sample_config->{'extent'}     = $extent;
    $sample_config->set_parameter('tsv_transcript' => $stable_id);

    ## Get this transcript only, on the sample slice
    my $transcript;

    foreach my $test_transcript (@{$sample_slice->get_all_Transcripts}) { 
      next unless $test_transcript->stable_id eq $stable_id;
      $transcript = $test_transcript;  # Only display on e transcripts
      last;
    }
    
    next unless $transcript;

    my $raw_coding_start = defined $transcript->coding_region_start ? $transcript->coding_region_start : $transcript->start;
    my $raw_coding_end   = defined $transcript->coding_region_end   ? $transcript->coding_region_end   : $transcript->end;
    my $coding_start     = $raw_coding_start + $object->munge_gaps('tsv_transcript', $raw_coding_start);
    my $coding_end       = $raw_coding_end   + $object->munge_gaps('tsv_transcript', $raw_coding_end);
    my @exons;
    
    foreach my $exon (@{$transcript->get_all_Exons}) {
      my $es     = $exon->start;
      my $offset = $object->munge_gaps('tsv_transcript', $es);
      push @exons, [ $es + $offset, $exon->end + $offset, $exon ];
    }
    
    my ($allele_info, $consequences) = $object->getAllelesConsequencesOnSlice($sample, 'tsv_transcript', $sample_slice);
    my ($coverage_level, $raw_coverage_obj) = $display_coverage ? $object->read_coverage($sample, $sample_slice) : ([], []);
    my $munged_coverage = $object->munge_read_coverage($raw_coverage_obj);
    
    $sample_config->{'transcript'} = {
      sample         => $sample,
      exons          => \@exons,
      coding_start   => $coding_start,
      coding_end     => $coding_end,
      transcript     => $transcript,
      allele_info    => $allele_info,
      consequences   => $consequences,
      coverage_level => $coverage_level,
      coverage_obj   => $munged_coverage,
    };
    
    unshift @haplotype, [ $sample, $allele_info, $munged_coverage ];
    
    $sample_config->modify_configs(
      [ $sample_config->get_track_key('tsv_transcript', $object) ],
      { caption => $sample, display => 'normal' },
    );

    $sample_config->{'_add_labels'} = 1;
    $sample_config->set_parameters({ container_width => $fake_length });
    
    push @containers_and_configs, $sample_slice, $sample_config;
  }

  return (\@containers_and_configs, \@haplotype);
}

sub variations_missing {
  my ($self, $snps, $context) = @_; 
  my $configure_text, 

  my $counts = $snps->{'snp_counts'}; 
  return unless ref $counts eq 'ARRAY';

  my $text;
  if ($counts->[0] == 0) {
    $text .= 'There are no SNPs within the context selected for this transcript.';
  } elsif ($counts->[1] == 0) {
    $text .= "The options set in the page configuration have filtered out all $counts->[0] variants in this region.";
  } elsif ($counts->[0] == $counts->[1]) {
    $text .= 'None of the variants are filtered out by the Source, Class and Type filters.';
  } else {
    $text .= ($counts->[0] - $counts->[1]) . " of the $counts->[0] variants in this region have been filtered out by the Source, Class and Type filters.";
  }
  
  $configure_text .= $text;

  # Context filter
  return $configure_text unless defined $counts->[2];

  my $context_text;
  
  if ($counts->[2] == 0) {
    $context_text = 'None of the intronic variants are removed by the Context filter.';
  } elsif ($counts->[2] == 1) {
    $context_text = "$counts->[2] intronic variants have been removed by the Context filter.";
  } else {
    $context_text = "$counts->[2] intronic variants are removed by the Context filter.";
  }
  
  $context_text   .= "<br />The context is currently set to display variants within $context bp of exon boundaries.";
  $configure_text .= "<br />$context_text";
  
  return $configure_text;
}

1;
