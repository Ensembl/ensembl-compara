package EnsEMBL::Web::Component::Gene::GeneSNPImage;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub caption {
  return undef;
}

sub _content {
  my $self    = shift;
  my $no_snps = shift;
  my $object  = $self->object;
  my $image_width  = $object->param( 'image_width' ) || 800;
  my $context      = $object->param( 'context' );
  my $extent       = $context eq 'FULL' ? 1000 : $context;

  my $master_config = $object->get_imageconfig( "genesnpview_transcript" );
     $master_config->set_parameters( {
       'image_width' =>  $self->image_width || 800,
       'container_width' => 100,
       'slice_number' => '1|1',
     });



  # Padding-----------------------------------------------------------
  # Get 5 configs - and set width to width of context config
  # Get three slice - context (5x) gene (4/3x) transcripts (+-EXTENT)
  my $Configs;
  my @confs = qw(context gene transcripts_top transcripts_bottom);
  push @confs, 'snps' unless $no_snps;

  foreach( @confs ) {
    $Configs->{$_} = $object->get_imageconfig( "genesnpview_$_" );
    $Configs->{$_}->set_parameter('image_width' => $image_width );
  }
   $object->get_gene_slices( ## Written...
    $master_config,
    [ 'context',     'normal', '100%'  ],
    [ 'gene',        'normal', '33%'  ],
    [ 'transcripts', 'munged', $extent ]
  );

  my $transcript_slice = $object->__data->{'slices'}{'transcripts'}[1]; warn $transcript_slice;
  my $sub_slices       =  $object->__data->{'slices'}{'transcripts'}[2];


  # Fake SNPs -----------------------------------------------------------
  # Grab the SNPs and map them to subslice co-ordinate
  # $snps contains an array of array each sub-array contains [fake_start, fake_end, B:E:Variation object] # Stores in $object->__data->{'SNPS'}
  my ($count_snps, $snps, $context_count) = $object->getVariationsOnSlice( $transcript_slice, $sub_slices  );
  my $start_difference =  $object->__data->{'slices'}{'transcripts'}[1]->start - $object->__data->{'slices'}{'gene'}[1]->start;

  my @fake_filtered_snps;
  map { push @fake_filtered_snps,
     [ $_->[2]->start + $start_difference,
       $_->[2]->end   + $start_difference,
       $_->[2]] } @$snps;

  $Configs->{'gene'}->{'filtered_fake_snps'} = \@fake_filtered_snps unless $no_snps;


  # Make fake transcripts ----------------------------------------------
 $object->store_TransformedTranscripts();        ## Stores in $transcript_object->__data->{'transformed'}{'exons'|'coding_start'|'coding_end'}

  my @domain_logic_names = qw(Pfam scanprosite Prints pfscan PrositePatterns PrositeProfiles Tigrfam Superfamily Smart PIRSF);
  foreach( @domain_logic_names ) {
    $object->store_TransformedDomains( $_ );    ## Stores in $transcript_object->__data->{'transformed'}{'Pfam_hits'}
  }
  $object->store_TransformedSNPS() unless $no_snps;      ## Stores in $transcript_object->__data->{'transformed'}{'snps'}


  ### This is where we do the configuration of containers....
  my @transcripts            = ();
  my @containers_and_configs = (); ## array of containers and configs

  foreach my $trans_obj ( @{$object->get_all_transcripts} ) {
## create config and store information on it...
    $trans_obj->__data->{'transformed'}{'extent'} = $extent;
    my $CONFIG = $object->get_imageconfig( "genesnpview_transcript" );
    $CONFIG->{'geneid'}     = $object->stable_id;
    $CONFIG->{'snps'}       = $snps unless $no_snps;
    $CONFIG->{'subslices'}  = $sub_slices;
    $CONFIG->{'extent'}     = $extent;
      ## Store transcript information on config....
    my $TS = $trans_obj->__data->{'transformed'};
#        warn Data::Dumper::Dumper($TS);
    $CONFIG->{'transcript'} = {
      'exons'        => $TS->{'exons'},
      'coding_start' => $TS->{'coding_start'},
      'coding_end'   => $TS->{'coding_end'},
      'transcript'   => $trans_obj->Obj,
      'gene'         => $object->Obj,
      $no_snps ? (): ('snps' => $TS->{'snps'})
    };
    foreach ( @domain_logic_names ) {
      $CONFIG->{'transcript'}{lc($_).'_hits'} = $TS->{lc($_).'_hits'};
    }

   # $CONFIG->container_width( $object->__data->{'slices'}{'transcripts'}[3] );
   $CONFIG->set_parameters({'container_width' => $object->__data->{'slices'}{'transcripts'}[3] });  
   if( $object->seq_region_strand < 0 ) {
      push @containers_and_configs, $transcript_slice, $CONFIG;
    } else {
      ## If forward strand we have to draw these in reverse order (as forced on -ve strand)
      unshift @containers_and_configs, $transcript_slice, $CONFIG;
    }
    push @transcripts, { 'exons' => $TS->{'exons'} };
  }
## -- Map SNPs for the last SNP display --------------------------------- ##
  my $SNP_REL     = 5; ## relative length of snp to gap in bottom display...
  my $fake_length = -1; ## end of last drawn snp on bottom display...
  my $slice_trans = $transcript_slice;

## map snps to fake evenly spaced co-ordinates...
  my @snps2;
  unless( $no_snps ) {
    @snps2 = map {
      $fake_length+=$SNP_REL+1;
      [ $fake_length-$SNP_REL+1 ,$fake_length,$_->[2], $slice_trans->seq_region_name,
        $slice_trans->strand > 0 ?
          ( $slice_trans->start + $_->[2]->start - 1,
            $slice_trans->start + $_->[2]->end   - 1 ) :
          ( $slice_trans->end - $_->[2]->end     + 1,
            $slice_trans->end - $_->[2]->start   + 1 )
      ]
    } sort { $a->[0] <=> $b->[0] } @{ $snps };
## Cache data so that it can be retrieved later...
    #$object->__data->{'gene_snps'} = \@snps2; fc1 - don't think is used
    foreach my $trans_obj ( @{$object->get_all_transcripts} ) {
      $trans_obj->__data->{'transformed'}{'gene_snps'} = \@snps2;
    }
  }

## -- Tweak the configurations for the five sub images ------------------ ##
## Gene context block;
  my $gene_stable_id = $object->stable_id;
  $Configs->{'context'}->{'geneid2'} = $gene_stable_id; ## Only skip background stripes...
 # $Configs->{'context'}->container_width( $object->__data->{'slices'}{'context'}[1]->length() );
  $Configs->{'context'}->set_parameters({ 'container_width' =>  $object->__data->{'slices'}{'context'}[1]->length() });  
  $Configs->{'context'}->get_node( 'scalebar')->set('label', "Chr. @{[$object->__data->{'slices'}{'context'}[1]->seq_region_name]}");
  #$Configs->{'context'}->get_node('variation')->set('on','off') if $no_snps;
#  $Configs->{'context'}->set('snp_join','on','off') if $no_snps;
## Transcript block
  $Configs->{'gene'}->{'geneid'}      = $gene_stable_id;
#  $Configs->{'gene'}->container_width( $object->__data->{'slices'}{'gene'}[1]->length() );
  $Configs->{'gene'}->set_parameters({ 'container_width' => $object->__data->{'slices'}{'gene'}[1]->length() }); 
  $Configs->{'gene'}->get_node('snp_join')->set('on','off') if $no_snps;
## Intronless transcript top and bottom (to draw snps, ruler and exon backgrounds)
  foreach(qw(transcripts_top transcripts_bottom)) {
   # $Configs->{$_}->get_node('snp_join')->set('on','off') if $no_snps;
    $Configs->{$_}->{'extent'}      = $extent;
    $Configs->{$_}->{'geneid'}      = $gene_stable_id;
    $Configs->{$_}->{'transcripts'} = \@transcripts;
    $Configs->{$_}->{'snps'}        = $object->__data->{'SNPS'} unless $no_snps;
    $Configs->{$_}->{'subslices'}   = $sub_slices;
    $Configs->{$_}->{'fakeslice'}   = 1;
#    $Configs->{$_}->container_width( $object->__data->{'slices'}{'transcripts'}[3] );
    $Configs->{$_}->set_parameters({ 'container_width' => $object->__data->{'slices'}{'transcripts'}[3] }); 
  }
  #$Configs->{'transcripts_bottom'}->get_node('spacer')->set('on','off') if $no_snps;
## SNP box track...
  unless( $no_snps ) {
    $Configs->{'snps'}->{'fakeslice'}   = 1;
    $Configs->{'snps'}->{'snps'}        = \@snps2;
 #   $Configs->{'snps'}->container_width(   $fake_length   );
    $Configs->{'snps'}->set_parameters({ 'container_width' => $fake_length }); 
    $Configs->{'snps'}->{'snp_counts'} = [$count_snps, scalar @$snps, $context_count];
  } 
#  return if $do_not_render;
## -- Render image ------------------------------------------------------ ##
  my $image    = $object->new_image([
    $object->__data->{'slices'}{'context'}[1],     $Configs->{'context'},
    $object->__data->{'slices'}{'gene'}[1],        $Configs->{'gene'},
    $transcript_slice, $Configs->{'transcripts_top'},
    @containers_and_configs,
    $transcript_slice, $Configs->{'transcripts_bottom'},
    $no_snps ? ():($transcript_slice, $Configs->{'snps'})
  ],
  [ $object->stable_id ]
  );
  #$image->set_extra( $object );

  $image->imagemap = 'yes';
  $image->set_extra( $object );
  $image->{'panel_number'} = 'top';
  $image->set_button( 'drag', 'title' => 'Drag to select region' );

  return $image->render;
}

sub content {
  return $_[0]->_content(0);
}

1;

