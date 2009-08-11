package Bio::EnsEMBL::GlyphSet::contig;

use strict;
use constant MAX_VIEWABLE_ASSEMBLY_SIZE => 5e6;


use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my $self = shift;
  
  return $self->render_text if $self->{'text_export'};
  
  # only draw contigs once - on one strand
  if ($self->species_defs->NO_SEQUENCE) {
    $self->errorTrack('Clone map - no sequence to display');
    return;
  }

  my $Container = $self->{'container'};
  my $length = $Container->length;

  $self->{'vc'} = $Container;
  
  my $gline = $self->Rect({
    'x'         => 0,
    'y'         => 0,
    'width'     => $length,
    'height'    => 0,
    'colour'    => 'grey50',
    'absolutey' => 1,
  });
  
  $self->push($gline);

  my ($fontname, $fontsize) = $self->get_font_details('innertext');
  my @res = $self->get_text_width(0, 'X', '', 'font' => $fontname, 'ptsize' => $fontsize);
  my $h = $res[3];
  my $box_h = $self->my_config('h');
  
  if (!$box_h) {
    $box_h = $h + 4;
  } elsif ($box_h < $h + 4) {
    $h = 0;
  }

  my $pix_per_bp = $self->scalex;

  my $gline = $self->Rect({
    'x'         => 0,
    'y'         => $box_h,
    'width'     => $length,
    'height'    => 0,
    'colour'    => 'grey50',
    'absolutey' => 1,
  });
  
  $self->push($gline);
  
  my @segments = @{$Container->project('seqlevel')||[]};
  my @features;
  my @coord_systems;
  
  if (!$Container->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice') && ($Container->{'__type__'} ne 'alignslice')) {
    @coord_systems = @{$Container->adaptor->db->get_CoordSystemAdaptor->fetch_all || []};
  }

  my $threshold_navigation = ($self->my_config('threshold_navigation') || 2e6)*1001;
  my $navigation = $self->my_config('navigation') || 'on';
  my $show_navigation = ($length < $threshold_navigation) && ($navigation eq 'on');

  foreach my $segment (@segments) {
    my $start      = $segment->from_start;
    my $end        = $segment->from_end;
    my $ctg_slice  = $segment->to_Slice;
    
    my $feature  = { 
      'start' => $start, 
      'end'   => $end, 
      'name'  => $ctg_slice->seq_region_name,
      'ori'   => $ctg_slice->strand
    };
    
    $feature->{'name'} = $ctg_slice->{'_tree'} if $ctg_slice->coord_system->name eq 'ancestralsegment'; # This is a Slice of Ancestral sequences: display the tree instead of the ID
    $feature->{'locations'}->{$ctg_slice->coord_system->name} = [ $ctg_slice->seq_region_name, $ctg_slice->start, $ctg_slice->end, $ctg_slice->strand  ];

    my ($hap_name) = @{$ctg_slice->get_all_Attributes('hap_contig')}; # is it a haplotype contig?
    $feature->{'haplotype_contig'} = $hap_name->{'value'} if $hap_name;

    if ($show_navigation) {
      if (!$Container->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice') && ($Container->{'__type__'} ne 'alignslice')) {
        foreach (@coord_systems) {
          my $path;
          eval { $path = $ctg_slice->project($_->name); };
          
          next unless $path || @$path == 1;
          next unless $path->[0];
          
          $path = $path->[0]->to_Slice;
          
          # get clone id out of seq_region_attrib for link to webFPC 
          if ($_->{'name'} eq 'clone') {
            my ($clone_name) = @{$path->get_all_Attributes('fpc_clone_id')};
            $feature->{'internal_name'} = $clone_name->{'value'} if $clone_name;
          }

          $feature->{'locations'}{$_->name} = [ $path->seq_region_name, $path->start, $path->end, $path->strand ];
        }
      }
    }
    
    push @features, $feature;
  }
  
  if (@features) {
    $self->_init_non_assembled_contig($h, $box_h, $fontname, $fontsize, \@features);
  } else {
    my $msg = 'Golden path gap - no contigs to display!';
    
    if ($Container->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice') && $self->get_parameter('compara') ne 'primary') {
      $msg = 'Alignment gap - no contigs to display!';
    }
    
    $self->errorTrack($msg);
  }
}

sub _init_non_assembled_contig {
  my ($self, $h, $box_h, $fontname, $fontsize, $contig_tiling_path) = @_;
  
  my $length = $self->{'vc'}->length;
  my $pix_per_bp = $self->scalex;
  
  my $threshold_navigation = ($self->my_config('threshold_navigation') || 2e6)*1001;
  my $navigation           = $self->my_config('navigation') || 'on';
  my $show_navigation      = ($length < $threshold_navigation) && ($navigation eq 'on');

  # Draw the Contig Tiling Path
  my @colours  = ([ 'contigblue1', 'contigblue2' ], [ 'lightgoldenrod1', 'lightgoldenrod3' ]);
  my @label_colours = qw(white black);

  foreach my $tile (sort { $a->{'start'} <=> $b->{'start'} } @$contig_tiling_path) {
    my $strand = $tile->{'ori'};
    my $rend   = $tile->{'end'};
    my $rstart = $tile->{'start'};

    # AlignSlice segments can be on different strands - hence need to check if start & end need a swap
    ($rstart, $rend) = ($rend, $rstart) if $rstart > $rend;
    $rstart = 1 if $rstart < 1;
    $rend   = $length if $rend > $length;

    # if this is a haplotype contig then need a different pair of colours for the contigs    
    my $i = 0;
    $i = $tile->{'haplotype_contig'} ? 1 : 0 if exists $tile->{'haplotype_contig'};

    my $action = 'View';
    my $region = $tile->{'name'};
    my $species = $self->species;
    
    my $dets = {
      'x'         => $rstart - 1,
      'y'         => 0,
      'width'     => $rend - $rstart+1,
      'height'    => $box_h,
      'colour'    => $colours[$i]->[0],
      'absolutey' => 1,
      'title'     => $region 
    };
    
    if ($show_navigation && $species ne 'Ancestral_sequences') {
      my $url = $self->_url({
        'species'  => $self->species,
        'type'     => 'Location',
        'action'   => $action,
        'region_n' => $region,
        'r'        => undef
      });
      
      $dets->{'href'} = $url;
    }
    
    my $glyph = $self->Rect($dets);

    push @{$colours[$i]}, shift @{@colours[$i]};
    

    ## This section will be usefull when we come to put vega on new web code, when the
    ## time comes put it in vega plugin and remove from here
    #
    # my $species_sr7= $self->species_defs->SPECIES_COMMON_NAME;
    # if($species_sr7 eq 'Zebrafish'){
    #   if($region=~/(.+\.\d+)\.\d+\.\d+/){
    #     $region= $1;
    #   }
    # }
    # (my $T=ucfirst($_))=~s/contig/Contig/g;
    #
    ## add links to Ensembl and FPC (vega danio)
    # if( /clone/) {
    #   my $ens_URL = $self->ID_URL('EGB_ENSEMBL', $name);
    #   $glyph->{'zmenu'}{"$POS:View in Ensembl"} = $ens_URL if $ens_URL;
    #   $POS++;
    #   my $internal_clone_name = $tile->{'internal_name'};
    #   my $fpc_URL = $self->ID_URL('FPC',$internal_clone_name); 
    #   $glyph->{'zmenu'}{"$POS:View in WebFPC"} = $fpc_URL if $fpc_URL && $internal_clone_name;
    #   $POS++;
    # }

    $self->push($glyph);

    if ($h) {
      my @res = $self->get_text_width(
        ($rend-$rstart) * $pix_per_bp,
        $strand > 0 ? "$region >" : "< $region",
        $strand > 0 ? '>' : '<',
        'font' => $fontname, 'ptsize' => $fontsize
      );
      
      if ($res[0]) {
        $self->push($self->Text({
          'x'         => ($rend + $rstart - $res[2]/$pix_per_bp)/2,
          'height'    => $res[3],
          'width'     => $res[2]/$pix_per_bp,
          'textwidth' => $res[2],
          'y'         => ($h-$res[3])/2,
          'font'      => $fontname,
          'ptsize'    => $fontsize,
          'colour'    => $label_colours[$i],
          'text'      => $res[0],
          'absolutey' => 1
        }));
      }
    }
  }
}

sub render_text {
  my $self = shift;
  
  return if $self->species_defs->NO_SEQUENCE;
  
  my $container = $self->{'container'};
  my $sa = $container->adaptor;
  my $export;  
  
  foreach (@{$container->project('seqlevel')||[]}) {
    my $ctg_slice = $_->to_Slice;
    my $feature_name = $ctg_slice->coord_system->name eq 'ancestralsegment' ? $ctg_slice->{'_tree'} : $ctg_slice->seq_region_name;
    my $feature_slice = $sa->fetch_by_region('seqlevel', $feature_name)->project('toplevel')->[0]->to_Slice;
    
    $export .= $self->_render_text($_, 'Contig', { 'headers' => [ 'id' ], 'values' => [ $feature_name ] }, {
      'seqname' => $feature_slice->seq_region_name,
      'start'   => $feature_slice->start, 
      'end'     => $feature_slice->end, 
      'strand'  => $feature_slice->strand
    });
  }
  
  return $export;
}



1;
