package EnsEMBL::Web::Component::Transcript::SNPView;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);

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

  # Params for context transcript expansion.
  my $db = $object->get_db();
  my $transcript = $object->stable_id;

  # Get three slice - context (5x) gene (4/3x) transcripts (+-EXTENT)
  my $extent = tsv_extent($object); 
  foreach my $slice_type (
    [ 'context',           'normal', '100%'  ],
    [ 'transcript',        'normal', '20%'  ],
    [ 'tsv_transcript',    'munged', $extent ],
  ) { 
    $object->__data->{'slices'}{ $slice_type->[0] } =  $object->get_transcript_slices( $slice_type ) || warn "Couldn't get slice";
  }

  my $transcript_slice = $object->__data->{'slices'}{'tsv_transcript'}[1];
  my $sub_slices       =  $object->__data->{'slices'}{'tsv_transcript'}[2]; 
  my $fake_length      =  $object->__data->{'slices'}{'tsv_transcript'}[3];

  #Variations
  my ($count_sample_snps, $sample_snps, $context_count) = $object->getFakeMungedVariationsOnSlice( $transcript_slice, $sub_slices  );
  my $start_difference =  $object->__data->{'slices'}{'tsv_transcript'}[1]->start - $object->__data->{'slices'}{'transcript'}[1]->start;

  my @transcript_snps;
  map { push @transcript_snps,
    [ $_->[2]->start + $start_difference,
      $_->[2]->end   + $start_difference,
      $_->[2]] } @$sample_snps;

  # Taken out domains (prosite, pfam)

  # Tweak the configurations for the five sub images ------------------
  # Intronless transcript top and bottom (to draw snps, ruler and exon backgrounds)
  my @ens_exons;
  foreach my $exon (@{ $object->Obj->get_all_Exons() }) { 
    my $offset = $transcript_slice->start -1;
    my $es     = $exon->start - $offset;
    my $ee     = $exon->end   - $offset;
    my $munge  = $object->munge_gaps( 'tsv_transcript', $es );
    push @ens_exons, [ $es + $munge, $ee + $munge, $exon ];
  }
   
  # General page configs -------------------------------------
  # Get 4 configs (one for each section) set width to width of context config
  my $Configs;
  my $image_width    = $object->param( 'image_width' ) || 800;
  my $context      = $object->param( 'context' ) || 100;

  foreach (qw(context transcript transcripts_bottom transcripts_top)) {
    $Configs->{$_} = $object->get_imageconfig( "tsv_$_" );
    $Configs->{$_}->set_parameters({
      'image_width',  $image_width, 
      'slice_number' => '1|1',
      'context'      =>$context  
    });
    $Configs->{$_}->{'id'} = $object->stable_id;
  }

  $Configs->{'transcript'}->set_parameters({'container_width' => $object->__data->{'slices'}{'transcript'}[1]->length(), 'single_Transcript' => $object->stable_id });
  $Configs->{'transcript'}->modify_configs(
  [$Configs->{'transcript'}->get_track_key('transcript', $object)],
  {qw(display on showlabels on ), "caption" => $object->stable_id} 
  );
  $Configs->{'transcript'}->{'filtered_fake_snps'} = \@transcript_snps;
 
  foreach(qw(transcripts_top transcripts_bottom)) {
    $Configs->{$_}->{'extent'}      = $extent;
    $Configs->{$_}->{'transid'}     = $object->stable_id;
    $Configs->{$_}->{'transcripts'} = [{ 'exons' => \@ens_exons }];
    $Configs->{$_}->{'snps'}        = $sample_snps;
    $Configs->{$_}->{'subslices'}   = $sub_slices;
    $Configs->{$_}->{'fakeslice'}   = 1;
    $Configs->{$_}->set_parameters({'container_width' => $fake_length });
  }

  $Configs->{'snps'} = $object->get_imageconfig( "genesnpview_snps" );
  $Configs->{'snps'}->set_parameters({
      'image_width',  $image_width,
      'container_width' => 100,
      'slice_number' => '1|1',
      'context'      =>$context
  });
  $Configs->{'snps'}->{'snp_counts'} = [$count_sample_snps, scalar @$sample_snps, $context_count];
  $Configs->{'context'}->set_parameters({'container_width' => $object->__data->{'slices'}{'context'}[1]->length() });
  $Configs->{'context'}->get_node('scalebar')->set('label', "Chr. @{[$object->__data->{'slices'}{'context'}[1]->seq_region_name]}"); 
  #$Configs->{'context'}->get_node( 'est_transcript')->set('display','off');
  #$Configs->{'context'}->set( '_settings', 'URL', $base_URL."bottom=%7Cbump_", 1);
  #$Configs->{'context'}->{'filtered_fake_snps'} = $context_snps;
  $Configs->{'transcript'}->modify_configs( ## Turn on track associated with this db/logic name
    [$Configs->{'transcript'}->get_track_key( 'transcript', $object )],
    {qw(display on show_labels off)}  ## also turn off the transcript labels...
  );



  # SNP stuff ------------------------------------------------------------
  my ($containers_and_configs, $haplotype);

 # Foreach sample ...
  ($containers_and_configs, $haplotype) = _sample_configs($object, $transcript_slice, $sub_slices, $fake_length);

  # -- Map SNPs for the last SNP display to fake even spaced co-ordinates
  # @snps: array of arrays  [fake_start, fake_end, B:E:Variation obj]
  my $SNP_REL     = 5; ## relative length of snp to gap in bottom display...
  my $snp_fake_length = -1; ## end of last drawn snp on bottom display...
  my @fake_snps = map {
    $snp_fake_length +=$SNP_REL+1;
      [ $snp_fake_length - $SNP_REL+1, $snp_fake_length, $_->[2], $transcript_slice->seq_region_name,
  $transcript_slice->strand > 0 ?
  ( $transcript_slice->start + $_->[2]->start - 1,
    $transcript_slice->start + $_->[2]->end   - 1 ) :
  ( $transcript_slice->end - $_->[2]->end     + 1,
    $transcript_slice->end - $_->[2]->start   + 1 )
      ]
  } sort { $a->[0] <=> $b->[0] } @$sample_snps;



  if (scalar @$haplotype) {
    $Configs->{'snps'}->get_node('snp_fake_haplotype')->set('display', 'on' );
    $Configs->{'snps'}->get_node('tsv_haplotype_legend')->set('display', 'on' );
    $Configs->{'snps'}->{'snp_fake_haplotype'}  =  $haplotype;
  }

  $Configs->{'snps'}->set_parameters({'container_width' => $snp_fake_length  } );
  $Configs->{'snps'}->{'snps'}        = \@fake_snps;
  $Configs->{'snps'}->{'reference'}   = $object->param('reference')|| "";
  $Configs->{'snps'}->{'fakeslice'}   = 1;
  #$Configs->{'snps'}->{'URL'} =  $base_URL;
 # return if $do_not_render;

  ## -- Render image ----------------------------------------------------- ##
  # Send the image pairs of slices and configurations
  my $image    = $object->new_image(
    [
     $object->__data->{'slices'}{'context'}[1],     $Configs->{'context'},
     $object->__data->{'slices'}{'transcript'}[1],  $Configs->{'transcript'},
     $transcript_slice, $Configs->{'transcripts_top'},
     @$containers_and_configs,
    $transcript_slice, $Configs->{'transcripts_bottom'},
     $transcript_slice, $Configs->{'snps'},
    ],
    [ $object->stable_id ]
  );

  $image->imagemap = 'yes';
  $image->set_extra( $object );
  $image->{'panel_number'} = 'top';
  $image->set_button( 'drag', 'title' => 'Drag to select region' );

  return $image->render;
}


sub tsv_extent {
  my $object = shift;
   return $object->param( 'context' ) eq 'FULL' ? 1000 :$object->param( 'context' );

}

sub _sample_configs {
  my ($object, $transcript_slice, $sub_slices, $fake_length) = @_;

  my @containers_and_configs = (); ## array of containers and configs
  my @haplotype = ();
  my $extent = tsv_extent($object); 

  # THIS IS A HACK. IT ASSUMES ALL COVERAGE DATA IN DB IS FROM SANGER fc1
  # Only display coverage data if source Sanger is on 
  my $display_coverage = $object->get_viewconfig->get( "opt_sanger" ) eq 'off' ? 0 : 1;
 
  foreach my $sample ( $object->get_samples ) {  
    my $sample_slice = $transcript_slice->get_by_strain( $sample ); 
    next unless $sample_slice;

    ## Initialize content...
    my $sample_config = $object->get_imageconfig( "tsv_sampletranscript" );
    $sample_config->{'id'}         = $object->stable_id;
    $sample_config->{'subslices'}  = $sub_slices;
    $sample_config->{'extent'}     = $extent;
    $sample_config->set_parameter( 'tsv_transcript' => $object->stable_id );

    ## Get this transcript only, on the sample slice
    my $transcript;

    foreach my $test_transcript ( @{$sample_slice->get_all_Transcripts} ) { 
      next unless $test_transcript->stable_id eq $object->stable_id;
      $transcript = $test_transcript;  # Only display on e transcripts...
      last;
    }
    next unless $transcript;

    my $raw_coding_start = defined( $transcript->coding_region_start ) ? $transcript->coding_region_start : $transcript->start;
    my $raw_coding_end   = defined( $transcript->coding_region_end )   ? $transcript->coding_region_end : $transcript->end;
    my $coding_start = $raw_coding_start + $object->munge_gaps( 'tsv_transcript', $raw_coding_start );
    my $coding_end   = $raw_coding_end   + $object->munge_gaps( 'tsv_transcript', $raw_coding_end );

    my @exons = ();
    foreach my $exon (@{$transcript->get_all_Exons()}) {
      my $es = $exon->start;
      my $offset = $object->munge_gaps( 'tsv_transcript', $es );
      push @exons, [ $es + $offset, $exon->end + $offset, $exon ];
    }

    my ( $allele_info, $consequences ) = $object->getAllelesConsequencesOnSlice($sample, "tsv_transcript", $sample_slice);
    my ($coverage_level, $raw_coverage_obj) = ([], []);
    if ($display_coverage) {
      ($coverage_level, $raw_coverage_obj) = $object->read_coverage($sample, $sample_slice);
    }
    my $munged_coverage = $object->munge_read_coverage($raw_coverage_obj);

    $sample_config->{'transcript'} = {
      'sample'          => $sample,
      'exons'           => \@exons,
      'coding_start'    => $coding_start,
      'coding_end'      => $coding_end,
      'transcript'      => $transcript,
      'allele_info'     => $allele_info,
      'consequences'    => $consequences,
      'coverage_level'  => $coverage_level,
      'coverage_obj'    => $munged_coverage,
    };
    unshift @haplotype, [ $sample, $allele_info, $munged_coverage ];
  $sample_config->modify_configs(
    [$sample_config->get_track_key('tsv_transcript', $object)],
    {"caption" => $sample}
  );

    $sample_config->{'_add_labels'} = 1;
#warn "#### $sample\n";
#warn map { "  >> @$_\n" } @$allele_info;
#warn map { "  << @$_\n" } @$munged_coverage;
    $sample_config->set_parameters({'container_width' => $fake_length, } );

    ## Finally the variation features (and associated transcript_variation_features )...  Not sure exactly which call to make on here to get

    ## Now push onto config hash...
    push @containers_and_configs,    $sample_slice, $sample_config;
  } #end foreach sample

  return (\@containers_and_configs, \@haplotype);
}

1;
