package Bio::EnsEMBL::GlyphSet::scalebar;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Intron;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Composite;
use  Sanger::Graphics::Bump;

sub _init {
    my ($self) = @_;
    #return unless ($self->strand() == -1);

    my $Config         = $self->{'config'};
    my $Container      = $self->{'container'};
    my $h              = 0;
    my $highlights     = $self->highlights();

    my $fontname       = "Tiny";
    my $fontwidth_bp   = $Config->texthelper->width($fontname),
    my ($fontwidth, $fontheight)       = $Config->texthelper->px2bp($fontname),
    my $black          = $Config->colourmap->id_by_name('black');
    my $highlights     = join('|',$self->highlights());
    $highlights        = $highlights ? "&highlight=$highlights" : '';
    my $REGISTER_LINE  = $Config->get('_settings','opt_lines');
    my $feature_colour = $Config->get('scalebar', 'col');
    my $subdivs        = $Config->get('scalebar', 'subdivs');
    my $max_num_divs   = $Config->get('scalebar', 'max_divisions') || 12;
    my $navigation     = $Config->get('scalebar', 'navigation');
    my $abbrev         = $Config->get('scalebar', 'abbrev');
    my $clone_based    = $Config->get('_settings','clone_based') eq 'yes';
    #my $param_string   = $clone_based ? $Config->get('_settings','clone') : ("chr=".$Container->_chr_name());
    my $param_string   = $clone_based ? $Config->get('_settings', 'clone') : ("chr=" . $Container->chr_name());

    my $main_width     = $Config->get('_settings', 'main_vc_width');
    warn( "MW: $main_width" );
    my $len            = $Container->length();
    my $global_start   = $clone_based ? $Config->get('_settings','clone_start') : $Container->chr_start();
    my $global_end     = $global_start + $len - 1;

    #print STDERR "VC half length = $global_offset\n";
    #print STDERR "VC start = $global_start\n";
    #print STDERR "VC end = $global_end\n";

    my $divs = set_scale_division($len, $max_num_divs) || 0;
    
    $self->push(new Sanger::Graphics::Glyph::Rect({
        'x'         => 0,
        'y'         => 0,
        'width'     => $len,
        'height'    => 0,
        'colour'    => $feature_colour,
        'absolutey' => 1,
    }));
    $self->push(new Sanger::Graphics::Glyph::Rect({
        'x'         => 0,
        'y'         => 3,
        'width'     => $len,
        'height'    => 0,
        'colour'    => $feature_colour,
        'absolutey' => 1,
    }));

    for (my $i=0;$i<int($len/$divs); $i++){
        my $tick = new Sanger::Graphics::Glyph::Rect({
            'x'         => $i * $divs,
            'y'         => 0,
            'width'     => 0,
            'height'    => 5,
            'colour'    => $feature_colour,
            'absolutey' => 1,
        });
        $self->push($tick);
        $self->join_tag( $tick, "ruler_$i", $self->strand()==-1 ? 1 : 0, 0.5, 'grey80'  ) if($REGISTER_LINE); 
        if ($navigation eq 'on'){
            $self->interval( $param_string, $i * $divs, ($i+.2) * $divs, $global_start, $global_end-$global_start, $highlights);
        } elsif( $navigation eq 'zoom' ) {
            $self->zoom_interval( $param_string, $i * $divs, ($i+.2) * $divs, $global_start, $main_width, $highlights, $global_end-$global_start);
        }

        for( my $j = 1 ; $j < 5; $j ++ ) {
          my $t;
          if($j%2) {
              $t = new Sanger::Graphics::Glyph::Rect({
                 'x'         => ($i + $j/5) * $divs,
                 'y'         => 0,
                 'width'     => $divs / 5,
                 'height'    => 3,
                 'colour'    => 'black',
                 'absolutey' => 1,
              });
          } else {
              $t = new Sanger::Graphics::Glyph::Space({
                 'x'         => ($i + $j/5) * $divs,
                 'y'         => 0,
                 'width'     => $divs / 5,
                 'height'    => 3,
                 'absolutey' => 1,
              });
          }
           $self->push($t);
          $self->join_tag( $t, "ruler_$i"."_$j", 0, 0 , 'grey90'  ) if($REGISTER_LINE);  
          if ($navigation eq 'on'){
            $self->interval( $param_string,($i+$j/5)*$divs, ($i+$j/5+.2) * $divs, $global_start, $global_end-$global_start, $highlights);
          } elsif( $navigation eq 'zoom' ) {
            $self->zoom_interval( $param_string, ($i+$j/5) * $divs, ($i+$j/5+.2) * $divs, $global_start, $main_width, $highlights, $global_end-$global_start);
          }
        }
    }
        
    my $last_end = (int($len/$divs)+1) * $divs;
    # Add the last recentering imagemap-only glyphs
    if ($navigation eq 'on'){
        $self->interval(
            $param_string,
            $last_end,
            $global_end-$global_start,
            $global_start,
            $global_end-$global_start,
            $highlights
        );
    }
    
    if ($subdivs && $len > 1000){
        # label each division
        for (my $i=0;$i<int($len/$divs); $i++){
            my $text = int($i * $divs + $global_start);                
            if ($abbrev){
                $text = $self->bp_to_nearest_unit_by_divs(int($i * $divs + $global_start),$divs);                
            }
            my $tglyph = new Sanger::Graphics::Glyph::Text({
                'x'         => $i * $divs,
                'y'         => 8,
                'height'    => $fontheight,
                'font'      => $fontname,
                'colour'    => $feature_colour,
                'text'      => $text,
                'absolutey' => 1,
            });
            $self->push($tglyph);
        }

    } else {
        # label first and last
        my $text = $global_start;
        if ($abbrev && $len >1000){
            $text = $self->bp_to_nearest_unit($global_start,2);
        }
        my $tglyph = new Sanger::Graphics::Glyph::Text({
            'x'             => 0,
            'y'             => 8,
            'height'        => $fontheight,
            'font'          => $fontname,
            'colour'        => $feature_colour,
            'text'          => $text,
            'absolutey'     => 1,
        });
        $self->push($tglyph);
        
        my $im_width = $Config->image_width();
        $text = $global_end;
        if ($abbrev && $len >1000){
            $text = $self->bp_to_nearest_unit($global_end,2);
        }
        
        my $endglyph = new Sanger::Graphics::Glyph::Text({
            'x'             => $im_width -(length("$text ")*$fontwidth_bp),
            'y'             => 8,
            'height'        => $fontheight,
            'font'          => $fontname,
            'colour'        => $feature_colour,
            'text'          => $text,
            'absolutex'     => 1,
            'absolutey'     => 1,
        });
        $self->push($endglyph);
        
    }
        
    # last tick

    my $im_width = $Config->image_width();
    my $X = 0;
    my $j0 = int($len/$divs);
    foreach( my $j = int($len/$divs) * 5 ; $j < $len/$divs * 5 ; $j++ ) {
          last if ($j > 200 );
          my $t;
          my $w = $len < ($j+1)/5*$divs ? $len - $j/5*$divs : $divs/5;
          if(($j-$j0)%2) {
              $t = new Sanger::Graphics::Glyph::Space({
                 'x'         => $j/5 * $divs,
                 'y'         => 0,
                 'width'     => $w,
                 'height'    => 3,
                 'colour'    => 'black',
                 'absolutey' => 1,
              });
          } else {
              $t = new Sanger::Graphics::Glyph::Rect({
                 'x'         => $j/5 * $divs,
                 'y'         => 0,
                 'width'     => $w,
                 'height'    => 3,
                 'colour'    => 'black',
                 'absolutey' => 1,
              });
          }
          $self->push($t);
          $self->join_tag( $t, "ruler_99_$j", 0, 0.5, 'grey90'  ) if($REGISTER_LINE);
          if ($navigation eq 'on'){
            $self->interval( $param_string,$j/5*$divs, ($j/5+.2) * $divs, $global_start, $global_end-$global_start, $highlights);
          } elsif( $navigation eq 'zoom' ) {
            $self->zoom_interval( $param_string, $j/5 * $divs, ($j/5+.2) * $divs, $global_start, $main_width, $highlights, $global_end-$global_start);
          }
    }

    my $tick = new Sanger::Graphics::Glyph::Rect({
        'x'          => $im_width - 1,
        'y'          => 0,
        'width'      => 0,
        'height'     => 5,
        'colour'     => $feature_colour,
        'absolutex'  => 1,
        'absolutey'  => 1,
    });
    $self->join_tag( $tick, "ruler_99" , 0, 0.5, 'grey80' ) if($REGISTER_LINE); 
    $self->push($tick);
}

sub set_scale_division {
    my ($full_length, $max_num_divs) = @_;

    $max_num_divs = $max_num_divs <1 ? 1 : $max_num_divs;

    my $num_of_digits = length( int( $full_length / 10 ) );
    $num_of_digits--;

    my $division = 10**$num_of_digits;
    my $first_division = $division;

    my $num_of_divs = int( $full_length / $division );
    my $i=2;
    until ( $num_of_divs < $max_num_divs ) {
           $division = $first_division * $i;
           $num_of_divs = int( $full_length / $division );
           $i += 2;
    }

    return $division;
} 

sub interval {
    # Add the recentering imagemap-only glyphs
    my ( $self, $chr, $start, $end,
        $global_offset, $width,
        $highlights
    ) = @_;
    my $interval_middle = $global_offset + ($start + $end)/2;
    my $interval = new Sanger::Graphics::Glyph::Space({
        'x'         => $start,
        'y'         => 0,
        'width'     => $end - $start+1,
        'height'    => 18,
        'absolutey' => 1,
        'href'      => $self->zoom_URL($chr, $interval_middle, $width,  1  , $highlights),
        'zmenu'     => $self->zoom_zmenu( $chr, $interval_middle, $width, $highlights ),
    });
    $self->push($interval);
}

sub zoom_interval {
    # Add the recentering imagemap-only glyphs
    my ( $self, $chr, $start, $end, $global_offset, $width, $highlights, $zoom_width ) = @_;
    my $interval_middle = $global_offset + ($start + $end)/2;
    my $interval = new Sanger::Graphics::Glyph::Space({
        'x'         => $start,
        'y'         => 0,
        'width'     => $end - $start+1,
        'height'    => 18,
        'absolutey' => 1,
        'href'      => $self->zoom_URL($chr, $interval_middle, $width,  1  , $highlights),
        'zmenu'     => $self->zoom_zoom_zmenu( $chr, $interval_middle, $width, $highlights, $zoom_width )
    });
    $self->push($interval);
}

sub bp_to_nearest_unit_by_divs {
    my ($self,$bp,$divs) = @_;

    return $self->bp_to_nearest_unit($bp,0) if (!defined $divs);

    my $power_ranger = int( ( length( abs($bp) ) - 1 ) / 3 );
    my $value = $divs / ( 10 ** ( $power_ranger * 3 ) ) ;

    my $dp = $value < 1 ? length ($value) - 2 : 0; # 2 for leading "0."
    return $self->bp_to_nearest_unit ($bp,$dp);
}

sub bp_to_nearest_unit {
    my ($self,$bp,$dp) = @_;
    $dp = 1 unless defined $dp;
    
    my @units = qw( bp Kb Mb Gb Tb );
    my $power_ranger = int( ( length( abs($bp) ) - 1 ) / 3 );
    my $unit = $units[$power_ranger];

    my $value = int( $bp / ( 10 ** ( $power_ranger * 3 ) ) );
      
    $value = sprintf( "%.${dp}f", $bp / ( 10 ** ( $power_ranger * 3 ) ) ) if ($unit ne 'bp');      

    return "$value $unit";
}


1;
