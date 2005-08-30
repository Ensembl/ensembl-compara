package Bio::EnsEMBL::GlyphSet::contig;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Poly;
use Sanger::Graphics::Glyph::Space;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Composite;
use Data::Dumper;
$Data::Dumper::Indent=2;
use constant MAX_VIEWABLE_ASSEMBLY_SIZE => 5e6;

sub init_label {
  my ($self) = @_;
  return if( defined $self->{'config'}->{'_no_label'} );
  my $label = new Sanger::Graphics::Glyph::Text({
    'text'      => 'DNA(contigs)',
    'font'      => 'Small',
    'absolutey' => 1,
    'href'      => qq[javascript:X=hw('@{[$self->{container}{_config_file_name_}]}','$ENV{'ENSEMBL_SCRIPT'}','contig')],
    'zmenu'     => {
      'caption'                     => 'HELP',
      '01:Track information...'     => qq[javascript:X=hw(\'@{[$self->{container}{_config_file_name_}]}\',\'$ENV{'ENSEMBL_SCRIPT'}\',\'contig\')]
    }
  });
  $self->label($label);
}

sub _init {
  my ($self) = @_;

  # only draw contigs once - on one strand
  return unless ($self->strand() == 1);
   
  my $Container = $self->{'container'};
  $self->{'vc'} = $Container;
  my $length = $Container->length();

  my $ystart = 3;

  my $gline = new Sanger::Graphics::Glyph::Rect({
    'x'         => 0,
    'y'         => $ystart + 7,
    'width'     => $length,
    'height'    => 0,
    'colour'    => 'grey50',
    'absolutey' => 1,
  });

  $self->push($gline);
  
  my @features = ();
  my @segments = ();

  if ($Container->isa("Bio::EnsEMBL::Compara::AlignSlice")) {
      foreach my $slice (@{$Container->get_all_Slices()}) {
	  push @segments, @{$slice->project("contig")};
      }
  } else {
      @segments = @{$Container->project('seqlevel')||[]};
  }

  foreach my $segment (@segments) {
      my $start      = $segment->from_start;
      my $end        = $segment->from_end;
      my $ctg_slice  = $segment->to_Slice;
      my $ORI        = $ctg_slice->strand;
      my $feature = { 'start' => $start, 'end' => $end, 'name' => $ctg_slice->seq_region_name };

      $feature->{'locations'}{ $ctg_slice->coord_system->name } = [ $ctg_slice->seq_region_name, $ctg_slice->start, $ctg_slice->end, $ctg_slice->strand  ];
      if ( ! $Container->isa("Bio::EnsEMBL::Compara::AlignSlice") && ($Container->{__type__} ne 'alignslice')) {
	  foreach( @{$Container->adaptor->db->get_CoordSystemAdaptor->fetch_all() || []} ) {
	      my $path;
	      eval { $path = $ctg_slice->project($_->name); };
	      next unless(@$path == 1);
	      $path = $path->[0]->to_Slice;
# get clone id out of seq_region_attrib for link to webFPC 
	      if ($_->{'name'} eq 'clone') {
		  my ($clone_name) = @{$path->get_all_Attributes('fpc_clone_id')};
		  $feature->{'internal_name'} = $clone_name->{'value'} if $clone_name;;
	      }
	      $feature->{'locations'}{$_->name} = [ $path->seq_region_name, $path->start, $path->end, $path->strand ];
	  }
      }
    $feature->{'ori'} = $ORI;
    push @features, $feature;
  }
  if( @features) {
    $self->_init_non_assembled_contig($ystart, \@features);
  } else {
    $self->errorTrack("Golden path gap - no contigs to display!");
  }
}

sub _init_non_assembled_contig {
  my ($self, $ystart, $contig_tiling_path) = @_;

  my $Container = $self->{'vc'};
  my $length = $Container->length();
  my $ch = $Container->seq_region_name;

  my $Config = $self->{'config'};

  my $module = ref($self);
     $module = $1 if $module=~/::([^:]+)$/;
  my $threshold_navigation = ($Config->get($module, 'threshold_navigation')|| 2e6)*1001;
  my $navigation     = $Config->get($module, 'navigation') || 'on';
  my $show_navigation = ($length < $threshold_navigation) && ($navigation eq 'on');

########
# Vars used only for scale drawing
#
  my $black    = 'black';
  my $red      = 'red';
  my $highlights = join('|', $self->highlights());
     $highlights = $highlights ? ";highlight=$highlights" : '';
 if( $self->{'config'}->{'compara'} ) { ## this is where we have to add in the other species....
    my $C = 0;
    foreach( @{ $self->{'config'}{'other_slices'}} ) {
      if( $C!= $self->{'config'}->{'slice_number'} ) {
        if( $C ) {
          if( $_->{'location'} ) {
            $highlights .= sprintf( ";s$C=%s;c$C=%s:%s:%s;w$C=%s", $_->{'location'}->species,
                         $_->{'location'}->seq_region_name, $_->{'location'}->centrepoint, $_->{'ori'}, $_->{'location'}->length );
          } else {
            $highlights .= sprintf( ";s$C=%s", $_->{'species'} );
          }
        } else {
          $highlights .= sprintf( ";c=%s:%s:1;w=%s",
                       $_->{'location'}->seq_region_name, $_->{'location'}->centrepoint,
                       $_->{'location'}->length );
        }
      }
      $C++;
    }
 } ##

  my $contig_strand = $Container->can('strand') ? $Container->strand : 1;
  my $clone_based = $Config->get('_settings','clone_based') eq 'yes';
  my $global_start   = $clone_based ? $Config->get('_settings','clone_start') : $Container->start();
  my $global_end     = $global_start + $length - 1;
  my $im_width = $Config->image_width();
#
########

#######
# Draw the Contig Tiling Path
#
  my ($w,$h)   = $Config->texthelper()->real_px2bp('Tiny');    
  my $i = 1;
  my @colours  = qw(contigblue1 contigblue2);

  foreach my $tile ( sort { $a->{'start'} <=> $b->{'start'} } @{$contig_tiling_path} ) {
      my $strand = $tile->{'ori'};
      my $rend   = $tile->{'end'};
    my $rstart = $tile->{'start'};

# AlignSlice segments can be on different strands - hence need to check if start & end need a swap

      if ($rstart > $rend ) {
	  ($rstart, $rend) = ($rend, $rstart);
      }
    my $rid    = $tile->{'name'};
    
       $rstart = 1 if $rstart < 1;
       $rend   = $length if $rend > $length;

    
    my $glyph = new Sanger::Graphics::Glyph::Rect({
      'x'         => $rstart - 1,
      'y'         => $ystart+2,
      'width'     => $rend - $rstart+1,
      'height'    => 11,
      'colour'    => $colours[0],
      'absolutey' => 1, 
    });
    push @colours, shift @colours;
    
    my $script = $ENV{'ENSEMBL_SCRIPT'};
    my $caption = 'Centre on';
    if(  $script eq 'multicontigview' ) { 
      $script = 'contigview';
      $caption = 'Jump to contigview';
    } 
    if($navigation eq 'on') {
      foreach( qw(chunk supercontig clone scaffold contig) ) {
        if( my $Q = $tile->{'locations'}->{$_} ) {
          $glyph->{'href'} = qq(/@{[$self->{container}{_config_file_name_}]}/$script?ch=$ch;region=$Q->[0]);
        }
      }
    }
    my $label = '';
    if($show_navigation) {
      $glyph->{'zmenu'} = {
        'caption' => $rid,
      };
      my $POS = 10;
      foreach( qw( contig clone supercontig scaffold chunk) ) {
        if( my $Q = $tile->{'locations'}->{$_} ) {
          my $name =$Q->[0];
          my $full_name = $name;
	  $name =~ s/\.\d+$// if $_ eq 'clone';
          $label ||= $tile->{'locations'}->{$_}->[0];
          (my $T=ucfirst($_))=~s/contig/Contig/g;
          $glyph->{'zmenu'}{"$POS:$T $name"} ='' unless $_ eq 'contig';
          $POS++;
#add links to Ensembl and FPC (vega danio)
          if( /clone/) {
	    my $ens_URL = $self->ID_URL('EGB_ENSEMBL', $name);
	    $glyph->{'zmenu'}{"$POS:View in Ensembl"} = $ens_URL if $ens_URL;
	    $POS++;
	    my $internal_clone_name = $tile->{'internal_name'};
	    my $fpc_URL = $self->ID_URL('FPC',$internal_clone_name); 
	    $glyph->{'zmenu'}{"$POS:View in WebFPC"} = $fpc_URL if $fpc_URL && $internal_clone_name;
	    $POS++;
	  }
	  $glyph->{'zmenu'}{"$POS:EMBL source (this version)"} = $self->ID_URL( 'EMBL', $full_name) if /clone/;	
          $POS++;
	  $glyph->{'zmenu'}{"$POS:EMBL source (latest version)"} = $self->ID_URL( 'EMBL', $name) if /clone/;	
          $POS++;
          $glyph->{'zmenu'}{"$POS:$caption $T"} = qq(/@{[$self->{container}{_config_file_name_}]}/$script?ch=$ch;region=$name);
          $POS++;
          $glyph->{'zmenu'}{"$POS:Export this $T"} = qq(/@{[$self->{container}{_config_file_name_}]}/exportview?action=select;option=fasta;type1=region;anchor1=$name);
          $POS++;
        }
      }
    }
    $self->push($glyph);

    $label = $strand > 0 ? "$label >" : "< $label";
    my $bp_textwidth = $w * length($label) * 1.2; # add 20% for scaling text
    if($bp_textwidth > ($rend - $rstart)) {
      my $pointer = $strand > 0 ? ">" : "<";
      $bp_textwidth = $w * length($pointer) * 1.2; # add 20% for scaling text
      unless($bp_textwidth > ($rend - $rstart)){
        my $tglyph = new Sanger::Graphics::Glyph::Text({
          'x'          => ($rend + $rstart - $bp_textwidth)/2,
          'y'          => $ystart+4,
          'font'       => 'Tiny',
          'colour'     => 'white',
          'text'       => $pointer,
          'absolutey'  => 1,
        });
        $self->push($tglyph);
      }
    } else {
      my $tglyph = new Sanger::Graphics::Glyph::Text({
        'x'          => ($rend + $rstart - 1 - $bp_textwidth)/2,
        'y'          => $ystart+5,
        'font'       => 'Tiny',
        'colour'     => 'white',
        'text'       => $label,
        'absolutey'  => 1,
      });
      $self->push($tglyph);
    }
  } 

######
# Draw the scale, ticks, red box etc
#
  my $gline = new Sanger::Graphics::Glyph::Rect({
    'x'         => 0,
    'y'         => $ystart,
    'width'     => $im_width,
    'height'    => 0,
    'colour'    => $black,
    'absolutey' => 1,
    'absolutex' => 1,'absolutewidth'=>1,
  });
  $self->unshift($gline);
  $gline = new Sanger::Graphics::Glyph::Rect({
    'x'         => 0,
    'y'         => $ystart+15,
    'width'     => $im_width,
    'height'    => 0,
    'colour'    => $black,
    'absolutey' => 1,
    'absolutex' => 1,    'absolutewidth'=>1,
  });
  $self->unshift($gline);
    
  ## pull in our subclassed methods if necessary
  if ($self->can('add_arrows')){
    $self->add_arrows($im_width, $black, $ystart);
  }

  my $tick;
  my $interval = int($im_width/10);
  # correct for $im_width's that are not multiples of 10
  my $corr = int(($im_width % 10) / 2);
  for (my $i=1; $i <=9; $i++){
    my $pos = $i * $interval + $corr; 
    $self->unshift( new Sanger::Graphics::Glyph::Rect({# the forward strand ticks
      'x'         => 0 + $pos,
      'y'         => $ystart-4,
      'width'     => 0,
      'height'    => 3,
      'colour'    => $black,
      'absolutey' => 1,
      'absolutex' => 1,'absolutewidth'=>1,
    }) );
    $self->unshift( new Sanger::Graphics::Glyph::Rect({# the reverse strand ticks 
      'x'         => 0 + $pos,
      'y'         => $ystart+16,
      'width'     => 0,
      'height'    => 3,
      'colour'    => $black,
      'absolutey' => 1,
      'absolutex' => 1,'absolutewidth'=>1,
     }) );
   }
    
    # The end ticks
  $self->unshift( new Sanger::Graphics::Glyph::Rect({
    'x'         => 0 + $corr,
    'y'         => $ystart-2,
    'width'     => 0,
    'height'    => 1,
    'colour'    => $black,
    'absolutey' => 1,
    'absolutex' => 1,'absolutewidth'=>1,
  }) );
   
  # the reverse strand ticks
  $self->unshift( new Sanger::Graphics::Glyph::Rect({
    'x'         => $im_width - 1 - $corr,
    'y'         => $ystart+16,
    'width'     => 0,
    'height'    => 1,
    'colour'    => $black,
    'absolutey' => 1,
    'absolutex' => 1,'absolutewidth'=>1,
  }) );
    
  my $Container_size_limit = $Config->get('_settings', 'default_vc_size');
  # only draw a red box if we are in contigview top and there is a 
  # detailed display
  my $rbs = $Config->get('_settings','red_box_start');
  my $rbe = $Config->get('_settings','red_box_end');

 if ($Config->get('_settings','draw_red_box') eq 'yes') { 

      my $global_start2 = $global_start;
      my $gwidth = $rbe-$rbs+1;

      if ($Container->{__type__} eq 'alignslice') {
	  my $hs = $Container->{slice_mapper_pairs}->[0];
	  $global_start2 = $hs->{slice}->{start};
	  my $s1 = $rbs - $global_start2;
	  my $cigar_line = $Container->get_cigar_line();
	  my @inters = split (/[MD]/, $cigar_line);
	  my $ms = 0;
	  my $ds = 0;
	  while (@inters) {
	      $ms += (shift (@inters) || 1);
	      last if ($ms > $s1);
	      $ds += (shift (@inters) || 1);
	  }
	  $rbs += $ds;
      }
      
   
  

    # only draw focus box on the correct display...
    $self->unshift( new Sanger::Graphics::Glyph::Rect({
      'x'            => $rbs - $global_start2,
      'y'            => $ystart - 4 ,
      'width'        => $gwidth,
      'height'       => 23,
      'bordercolour' => $red,
      'absolutey'    => 1,
    }) );
    $self->unshift( new Sanger::Graphics::Glyph::Rect({
      'x'            => $rbs - $global_start2,
      'y'            => $ystart - 3 ,
      'width'        => $gwidth,
      'height'       => 21,
      'bordercolour' => $red,
      'absolutey'    => 1,
    }) );
  } 

  my $width = $interval * ($length / $im_width) ;
  my $interval_middle = $width/2;

  if($navigation eq 'on') {
    foreach my $i(0..9){
      my $pos = $i * $interval;
      # the forward strand ticks
      $self->unshift( new Sanger::Graphics::Glyph::Space({
        'x'         => 0 + $pos,
        'y'         => $ystart-4,
        'width'     => $interval,
        'height'    => 3,
        'absolutey' => 1,
        'absolutex' => 1,'absolutewidth'=>1,
        'href'      => $self->zoom_URL($Container->seq_region_name, $interval_middle + $global_start, $length,  1  , $highlights, $self->{'config'}->{'slice_number'}, $contig_strand),
        'zmenu'     => $self->zoom_zmenu($Container->seq_region_name, $interval_middle + $global_start, $length, $highlights, $self->{'config'}->{'slice_number'}, $contig_strand ),
      }));
      # the reverse strand ticks
      $self->unshift( new Sanger::Graphics::Glyph::Space({
        'x'         => $im_width - $pos - $interval,
        'y'         => $ystart+16,
        'width'     => $interval,
        'height'    => 3,
        'absolutey' => 1,
        'absolutex' => 1,'absolutewidth'=>1,
        'href'      => $self->zoom_URL($Container->seq_region_name, $global_end+1-$interval_middle, $length,  1  , $highlights, $self->{'config'}->{'slice_number'}, $contig_strand),
        'zmenu'     => $self->zoom_zmenu($Container->seq_region_name, $global_end+1-$interval_middle, $length, $highlights, $self->{'config'}->{'slice_number'}, $contig_strand ),
      }) );
      $interval_middle += $width;
    }
  }
}



1;
