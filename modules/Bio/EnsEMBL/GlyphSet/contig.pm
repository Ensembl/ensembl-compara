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
use Sanger::Graphics::ColourMap;
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
   
  my $vc = $self->{'container'};
  $self->{'vc'} = $vc;
  my $length = $vc->length();

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
  foreach my $segment (@{$vc->project('seqlevel')||[]}) {
    my $start      = $segment->from_start;
    my $end        = $segment->from_end;
    my $ctg_slice  = $segment->to_Slice;
    my $ORI        = $ctg_slice->strand;
    my $feature = { 'start' => $start, 'end' => $end, 'name' => $ctg_slice->seq_region_name };
    $feature->{'locations'}{ $ctg_slice->coord_system->name } = [ $ctg_slice->seq_region_name, $ctg_slice->start, $ctg_slice->end, $ctg_slice->strand  ];
    foreach( @{$vc->adaptor->db->get_CoordSystemAdaptor->fetch_all() || []} ) {
      my $path;
      eval { $path = $ctg_slice->project($_->name); };
      next unless(@$path == 1);
      $path = $path->[0]->to_Slice;
      $feature->{'locations'}{$_->name} = [ $path->seq_region_name, $path->start, $path->end, $path->strand ];
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

  my $vc = $self->{'vc'};
  my $length = $vc->length();
  my $ch = $vc->seq_region_name;

  my $Config = $self->{'config'};

  my $module = ref($self);
     $module = $1 if $module=~/::([^:]+)$/;
  my $threshold_navigation = ($Config->get($module, 'threshold_navigation')|| 2e6)*1001;
  my $navigation     = $Config->get($module, 'navigation') || 'on';
  my $show_navigation = ($length < $threshold_navigation) && ($navigation eq 'on');

  my $cmap     = $Config->colourmap();
 
########
# Vars used only for scale drawing
#
  my $black    = 'black';
  my $red      = 'red';
  my $highlights = join('|', $self->highlights());
     $highlights = $highlights ? "&highlight=$highlights" : '';
  my $clone_based = $Config->get('_settings','clone_based') eq 'yes';
  my $param_string   = $clone_based ? $Config->get('_settings','clone')       : ("chr=". $vc->seq_region_name());
  my $global_start   = $clone_based ? $Config->get('_settings','clone_start') : $vc->start();
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
    my $rend   = $tile->{'end'};
    my $rstart = $tile->{'start'};
    my $rid    = $tile->{'name'};
    my $strand = $tile->{'ori'};
       $rstart = 1 if $rstart < 1;
       $rend   = $length if $rend > $length;
                
   warn Data::Dumper::Dumper( $tile->{'locations'}," " );
    my $glyph = new Sanger::Graphics::Glyph::Rect({
      'x'         => $rstart - 1,
      'y'         => $ystart+2,
      'width'     => $rend - $rstart+1,
      'height'    => 11,
      'colour'    => $colours[0],
      'absolutey' => 1, 
    });
    push @colours, shift @colours;
    
    if($navigation eq 'on') {
      foreach( qw(chunk supercontig clone scaffold contig) ) {
        if( my $Q = $tile->{'locations'}->{$_} ) {
          $glyph->{'href'} = qq(/@{[$self->{container}{_config_file_name_}]}/$ENV{'ENSEMBL_SCRIPT'}?ch=$ch&region=$Q->[0]);
        }
      }
    }
    my $label = '';
    if($show_navigation) {
      $glyph->{'zmenu'} = {
        'caption' => $rid,
      };
      my $POS = 10;
      foreach( qw(scaffold contig clone supercontig chunk) ) {
        if( my $Q = $tile->{'locations'}->{$_} ) {
          my $name =$Q->[0];
             $name =~ s/\.\d+$// if $_ eq 'clone';
          $label ||= $tile->{'locations'}->{$_}->[0];
          (my $T=ucfirst($_))=~s/contig/Contig/g;
          $glyph->{'zmenu'}{"$POS:$T $name"} ='' unless $_ eq 'contig';
          $POS++;
          $glyph->{'zmenu'}{"$POS:EMBL source file"} = $self->ID_URL( 'EMBL', $name) if /clone/;	
          $POS++;
          $glyph->{'zmenu'}{"$POS:Centre on $T"} = qq(/@{[$self->{container}{_config_file_name_}]}/$ENV{'ENSEMBL_SCRIPT'}?ch=$ch&region=$name);
          $POS++;
          $glyph->{'zmenu'}{"$POS:Export this $T"} = qq(/@{[$self->{container}{_config_file_name_}]}/exportview?tab=fasta&type=feature&ftype=$_&id=$name);
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
    
  my $vc_size_limit = $Config->get('_settings', 'default_vc_size');
  # only draw a red box if we are in contigview top and there is a 
  # detailed display
  my $rbs = $Config->get('_settings','red_box_start');
  my $rbe = $Config->get('_settings','red_box_end');
  if ($Config->get('_settings','draw_red_box') eq 'yes') { 
    # only draw focus box on the correct display...
    $self->unshift( new Sanger::Graphics::Glyph::Rect({
      'x'            => $rbs - $global_start,
      'y'            => $ystart - 4 ,
      'width'        => $rbe-$rbs+1,
      'height'       => 23,
      'bordercolour' => $red,
      'absolutey'    => 1,
    }) );
    $self->unshift( new Sanger::Graphics::Glyph::Rect({
      'x'            => $rbs - $global_start,
      'y'            => $ystart - 3 ,
      'width'        => $rbe-$rbs+1,
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
        'href'      => $self->zoom_URL($param_string, $interval_middle + $global_start, $length,  1  , $highlights),
        'zmenu'     => $self->zoom_zmenu($param_string, $interval_middle + $global_start, $length, $highlights ),
      }));
      # the reverse strand ticks
      $self->unshift( new Sanger::Graphics::Glyph::Space({
        'x'         => $im_width - $pos - $interval,
        'y'         => $ystart+16,
        'width'     => $interval,
        'height'    => 3,
        'absolutey' => 1,
        'absolutex' => 1,'absolutewidth'=>1,
        'href'      => $self->zoom_URL($param_string, $global_end+1-$interval_middle, $length,  1  , $highlights),
        'zmenu'     => $self->zoom_zmenu($param_string, $global_end+1-$interval_middle, $length, $highlights ),
      }) );
      $interval_middle += $width;
    }
  }
}



1;
