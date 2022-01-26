=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::VariationImage;

use strict;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
  $self->has_image(1);
}

sub content {
  my $self        = shift;
  my $no_snps     = shift;
  my $ic_type     = shift || 'gene_variation';  
  my $hub         = $self->hub;

  ## View retired for human genes
  return if ($hub->species eq 'Homo_sapiens' && $ic_type eq 'gene_variation');

  my $object      = $self->object || $hub->core_object(lc($hub->param('data_type')));
  my $image_width = $self->image_width     || 800;  
  my $context     = $hub->param('context') || 100; 
  my $extent      = $context eq 'FULL' ? 5000 : $context;
  my @confs       = qw(gene transcripts_top transcripts_bottom);
  my ($image_configs, $config_type, $snp_counts, $gene_object, $transcript_object, @trans);

  if ($object->isa('EnsEMBL::Web::Object::Gene') || $object->isa('EnsEMBL::Web::Object::LRG')){
    $gene_object = $object;
    $config_type = 'gene_variation';
  } else {
    $transcript_object = $object;
    $gene_object = $self->hub->core_object('gene');
    $config_type = $ic_type;
  }
 
  # Padding
  # Get 4 configs - and set width to width of context config
  # Get two slice -  gene (4/3x) transcripts (+/-extent)
  
  push @confs, 'snps' unless $no_snps;  

  foreach (@confs) { 
    $image_configs->{$_} = $hub->get_imageconfig({'type' => $_ eq 'gene' ? $ic_type : $config_type, 'cache_code' => $_});
    $image_configs->{$_}->set_parameters({
      image_width => $image_width, 
      context     => $context
    });
  }


  $gene_object->get_gene_slices(
    $image_configs->{'gene'},
    [ 'gene',        'normal', '33%'   ],
    [ 'transcripts', 'munged', $extent ]
  );
  
  my $transcript_slice = $gene_object->__data->{'slices'}{'transcripts'}[1]; 
  my $sub_slices       = $gene_object->__data->{'slices'}{'transcripts'}[2];  

  # Fake SNPs
  # Grab the SNPs and map them to subslice co-ordinate
  # $snps contains an array of array each sub-array contains [fake_start, fake_end, B:E:Variation object] # Stores in $object->__data->{'SNPS'}
  my ($count_snps, $snps, $context_count);
  if (!$no_snps) {
    ($count_snps, $snps, $context_count) = $gene_object->getVariationsOnSlice($transcript_slice, $sub_slices);
    my $start_difference   = $gene_object->__data->{'slices'}{'transcripts'}[1]->start - $gene_object->__data->{'slices'}{'gene'}[1]->start;
    my @fake_filtered_snps = map [ $_->[2]->start + $start_difference, $_->[2]->end + $start_difference, $_->[2] ], @$snps;
    $image_configs->{'gene'}->{'filtered_fake_snps'} = \@fake_filtered_snps unless $no_snps;
  }   

  my @domain_logic_names = @{$self->hub->species_defs->DOMAIN_LOGIC_NAMES||[]}; 
  
  # Make fake transcripts
  $gene_object->store_TransformedTranscripts;                            # Stores in $transcript_object->__data->{'transformed'}{'exons'|'coding_start'|'coding_end'}
  $gene_object->store_TransformedDomains($_) for @domain_logic_names;    # Stores in $transcript_object->__data->{'transformed'}{'Pfam_hits'}
  $gene_object->store_TransformedSNPS(undef,[ map $_->[2], @$snps]) unless $no_snps;   # Stores in $transcript_object->__data->{'transformed'}{'snps'}


  # This is where we do the configuration of containers
  my (@transcripts, @containers_and_configs);

  # sort so trancsripts are displayed in same order as in transcript selector table  
  my $strand = $object->Obj->strand;
  @trans  = @{$gene_object->get_all_transcripts};
  my @sorted_trans;
  
  if ($strand == 1) {
    @sorted_trans = sort { $b->Obj->external_name cmp $a->Obj->external_name || $b->Obj->stable_id cmp $a->Obj->stable_id } @trans;
  } else {
    @sorted_trans = sort { $a->Obj->external_name cmp $b->Obj->external_name || $a->Obj->stable_id cmp $b->Obj->stable_id } @trans;
  } 

  foreach my $trans_obj (@sorted_trans) {
    next if $transcript_object && $trans_obj->stable_id ne $transcript_object->stable_id;
    my $image_config = $hub->get_imageconfig({type => $ic_type, cache_code => $trans_obj->stable_id});
    $image_config->init_transcript;
    
    # create config and store information on it
    $trans_obj->__data->{'transformed'}{'extent'} = $extent;
    
    $image_config->{'geneid'}      = $gene_object->stable_id;
    $image_config->{'snps'}        = $snps unless $no_snps;
    $image_config->{'subslices'}   = $sub_slices;
    $image_config->{'extent'}      = $extent;
    $image_config->{'_add_labels'} = 1;
    
    # Store transcript information on config
    my $transformed_slice = $trans_obj->__data->{'transformed'};

    $image_config->{'transcript'} = {
      exons        => $transformed_slice->{'exons'},
      coding_start => $transformed_slice->{'coding_start'},
      coding_end   => $transformed_slice->{'coding_end'},
      transcript   => $trans_obj->Obj,
      gene         => $gene_object->Obj
    };
    
    $image_config->{'transcript'}{'snps'} = $transformed_slice->{'snps'} unless $no_snps;
    
    # Turn on track associated with this db/logic name 
    $image_config->modify_configs(
      [ $image_config->get_track_key('gsv_transcript', $gene_object) ],
      { display => 'normal', show_labels => 'off', caption => '' }
    );

    $image_config->{'transcript'}{lc($_) . '_hits'} = $transformed_slice->{lc($_) . '_hits'} for @domain_logic_names;
    $image_config->set_parameters({ container_width => $gene_object->__data->{'slices'}{'transcripts'}[3] });

    if ($gene_object->seq_region_strand < 0) {
      push @containers_and_configs, $transcript_slice, $image_config;
    } else {
      unshift @containers_and_configs, $transcript_slice, $image_config; # If forward strand we have to draw these in reverse order (as forced on -ve strand)
    }
    
    push @transcripts, { exons => $transformed_slice->{'exons'} };
  }
  
  # Map SNPs for the last SNP display
  my $snp_rel     = 5;  # relative length of snp to gap in bottom display
  my $fake_length = -1; # end of last drawn snp on bottom display
  my $slice_trans = $transcript_slice;

  # map snps to fake evenly spaced co-ordinates
  my @snps2;
  
  if (!$no_snps) {
    foreach (sort { $a->[0] <=> $b->[0] } @$snps) {
      $fake_length += $snp_rel + 1;
      
      push @snps2, [
        $fake_length - $snp_rel + 1, 
        $fake_length,
        $_->[2], 
        $slice_trans->seq_region_name,
        $slice_trans->strand > 0 ? (
          $slice_trans->start + $_->[2]->start - 1,
          $slice_trans->start + $_->[2]->end   - 1
        ) : (
          $slice_trans->end - $_->[2]->end   + 1,
          $slice_trans->end - $_->[2]->start + 1
        )
      ];
    }
    
    $_->__data->{'transformed'}{'gene_snps'} = \@snps2 for @trans; # Cache data so that it can be retrieved later
  }

  # Tweak the configurations for the five sub images
  # Gene context block;
  my $gene_stable_id = $gene_object->stable_id;

  # Transcript block
  $image_configs->{'gene'}->{'geneid'} = $gene_stable_id; 
  $image_configs->{'gene'}->set_parameters({ container_width => $gene_object->__data->{'slices'}{'gene'}[1]->length }); 
  $image_configs->{'gene'}->modify_configs(
    [ $image_configs->{'gene'}->get_track_key('transcript', $gene_object) ],
    { display => 'transcript_nolabel', menu => 'no' }  
  );
 
  # Intronless transcript top and bottom (to draw snps, ruler and exon backgrounds)
 foreach(qw(transcripts_top transcripts_bottom)) {
   $image_configs->{$_}->{'extent'}      = $extent;
   $image_configs->{$_}->{'geneid'}      = $gene_stable_id;
   $image_configs->{$_}->{'transcripts'} = \@transcripts;
   $image_configs->{$_}->{'snps'}        = $gene_object->__data->{'SNPS'} unless $no_snps;
   $image_configs->{$_}->{'subslices'}   = $sub_slices;
   $image_configs->{$_}->{'fakeslice'}   = 1;
   $image_configs->{$_}->set_parameters({ container_width => $gene_object->__data->{'slices'}{'transcripts'}[3] }); 
 }
  
  $image_configs->{'transcripts_bottom'}->get_node('spacer')->set('display', 'off') if $no_snps;
  
  # SNP box track
  if (!$no_snps) {
    $image_configs->{'snps'}->{'fakeslice'}  = 1;
    $image_configs->{'snps'}->{'snps'}       = \@snps2;
    $image_configs->{'snps'}->set_parameters({ container_width => $fake_length }); 
    $snp_counts = [ $count_snps, scalar @$snps, $context_count ];
  }

  # Render image
  my $image = $self->new_image([
      $gene_object->__data->{'slices'}{'gene'}[1], $image_configs->{'gene'},
      $transcript_slice, $image_configs->{'transcripts_top'},
      @containers_and_configs,
      $transcript_slice, $image_configs->{'transcripts_bottom'},
      $no_snps ? () : ($transcript_slice, $image_configs->{'snps'})
    ],
    [ $gene_object->stable_id ]
  );
  
  return if $self->_export_image($image, 'no_text');

  $image->imagemap         = 'yes';
  $image->{'panel_number'} = 'top';
  $image->set_button( 'drag', 'title' => 'Drag to select region' );
  
  my $html = $image->render; 
  
  if ($no_snps) {
    $html .= $self->_info(
      'Configuring the display',
      "<p>Tip: use the '<strong>Configure this page</strong>' link on the left to customise the protein domains displayed above.</p>"
    );
    return $html;
  }
  
  my $info_text = $self->config_info($snp_counts);
  
  $html .= $self->_info(
    'Configuring the display',
    qq{
    <p>
      Tip: use the '<strong>Configure this page</strong>' link on the left to customise the protein domains and types of variants displayed above.<br />
      Please note the default 'Context' settings will probably filter out some intronic SNPs.<br />
      $info_text
    </p>}
  );
  
  return $html;
}

sub config_info {
  my ($self, $counts) = @_;
  
  return unless ref $counts eq 'ARRAY';
  
  my $info;
  
  if ($counts->[0] == 0) {
    $info = 'There are no SNPs within the context selected for this transcript.';
  } elsif ($counts->[1] == 0) {
    $info = "The options set in the page configuration have filtered out all $counts->[0] variants in this region.";
  } elsif ($counts->[0] == $counts->[1]) {
    $info = 'None of the variants are filtered out by the Source, Class and Type filters.';
  } else {
    $info = ($counts->[0] - $counts->[1]) . " of the $counts->[0] variants in this region have been filtered out by the Source, Class and Type filters.";
  }
  
  return $info unless defined $counts->[2]; # Context filter
  
  $info .= '<br />';
  
  if ($counts->[2]== 0) {
    $info .= 'None of the intronic variants are removed by the Context filter.';
  } elsif ($counts->[2] == 1) {
    $info .= "$counts->[2] intronic variants has been removed by the Context filter.";
  } else {
    $info .= "$counts->[2] intronic variants are removed by the Context filter.";
  }
  
  return $info;
}

1;

