package Bio::EnsEMBL::GlyphSet_feature;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
use Sanger::Graphics::Glyph::Space;
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Composite;
use  Sanger::Graphics::Bump;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Data::Dumper;

sub init_label {
  my ($self) = @_;
  return if( defined $self->{'config'}->{'_no_label'} );
  my $HELP_LINK = $self->check();
 
  my $zmenu;
  if( my $econfig = $self->{'extras'}) {
      $zmenu->{'01:'.CGI::escapeHTML( $econfig->{'description'} )} = '';
      if ($econfig->{'useScore'} || ($econfig->{'type'} && $econfig->{'type'} =~ /wiggle/)) {
	my @features = sort {$b->score <=> $a->score} @{$self->features || []}; ### Sort by score in descending order - preparing for merge_features 
	my $min_score = defined ($econfig->{dataMin}) ? $econfig->{dataMin} : (@features ? $features[-1]->score : 0); 
	my $max_score = defined ($econfig->{dataMax}) ? $econfig->{dataMax} : (@features ? $features[0]->score : 100);
        $min_score = 0 if ($max_score == $min_score);
	$self->{_min_score} = $min_score;
	$self->{_max_score} = $max_score;
        if ($econfig->{'autoScale'} eq 'on') {
      	  $zmenu->{"05:Scores are scaled to the range $min_score .. $max_score"} = '';
        } else {
      	  $zmenu->{"05:Displaying scores in the range $min_score .. $max_score"} = '';
	  @features = grep { ($_->score >= $min_score) && ($_->score <= $max_score) } @features;
	}
	$self->{extras}->{_features} = \@features;
      }
  }
	
  if ($HELP_LINK || $zmenu) {
  	$self->{'label_colour'} = 'contigblue1';
 }
 
  $self->init_label_text( $self->my_label, $HELP_LINK, $zmenu);
  if( $self->can('das_link') ) {
    my $T = $self->das_link;
    $self->label->{'zmenu'}{'99:DAS Table View'} = $T if $T;
  }
  unless ($self->{'config'}->get($HELP_LINK, 'bump') eq 'always') {
    $self->bumped( $self->{'config'}->get($HELP_LINK, 'compact') ? 'no' : 'yes' );
  }
}

sub colour   { return $_[0]->{'feature_colour'}, $_[0]->{'label_colour'}, $_[0]->{'part_to_colour'}; }
sub my_label { return 'Missing label'; }
sub features { return (); } 
sub zmenu    { return { 'caption' => $_[0]->check(), "$_[1]" => "Missing caption" }; }
sub href     { return undef; }

## Returns the 'group' that a given feature belongs to. Features in the same
## group are linked together via an open rectangle. Can be subclassed.
sub feature_group{
  my( $self, $f ) = @_;
  return $f->display_id;
}

sub RENDER_colourgradient{
  my( $self, $configuration ) = @_;

  my @features = sort {$a->score <=> $b->score} @{$self->features ||[]};
  if (! @features) {
    $self->errorTrack( "No ".$self->my_label." features in this region" ) unless( $self->{'config'}->get('_settings','opt_empty_tracks')==0 );
    return 0;
  }
  my $rStart = $self->{'container'}->{'start'};
  my $rEnd= $self->{'container'}->{'end'};
  my ($min_score, $max_score) = ($self->{_min_score}, $self->{_max_score});
		   
				 
  my $row_height = $configuration->{'height'} || 20;
  my $cgGrades = $configuration->{cgGrades} || 20;
  my $score_per_grade =  ($max_score - $min_score)/ $cgGrades ;
  my @cgColours = map { $configuration->{$_} } grep { (($_ =~ /^cgColour/) && $configuration->{$_}) } sort keys %$configuration;
  if (my $ccount = scalar(@cgColours)) {
  	if ($ccount == 1) {
		unshift @cgColours, 'white';
	}
  } else {
    @cgColours = ('yellow', 'green', 'blue');
  }
  my $cm = new Sanger::Graphics::ColourMap;
  my @cg = $cm->build_linear_gradient($cgGrades, \@cgColours);

  $configuration->{h} = $row_height;
  $self->push( new Sanger::Graphics::Glyph::Line({
      'x'         => 0,
      'y'         => $row_height + 1,
      'width'     => $configuration->{'length'},
      'height'    => 0,
      'absolutey' => 1,
	'colour'    => 'red',
       'dotted'    => 1,
   }));
  foreach my $f (@features) {
     my $s = $f->start() < $rStart ? 1 : $f->start()- $rStart;
     my $e = $f->end()   > $rEnd  ? ($rEnd - $rStart) : ($f->end- $rStart);

     my $width = ($e- $s +1);
     my $score = $f->score || 0;
     $score = $min_score if ($score < $min_score);
     $score = $max_score if ($score > $max_score);
     my $grade = ($score >= $max_score) ? ($cgGrades - 1) : int(($score - $min_score) / $score_per_grade);
     my $col = $cg[$grade];	  

     my $Composite = new Sanger::Graphics::Glyph::Composite({
        'y'         => 0,
	'x'         => $s-1,
	'absolutey' => 1,
	'zmenu'    => $self->zmenu( $f->id, $f)
    });
    
    $Composite->push(new Sanger::Graphics::Glyph::Rect({
      'x'          => $s-1,
      'y'          => 0,
      'width'      => $width,
      'height'     => $row_height,
      'colour'     => $col,
      'absolutey'  => 1,
    }));
    $self->push( $Composite );
  }
  return 0;
}
sub RENDER_plot{
  my( $self, $configuration ) = @_;

  my @features = @{$self->features ||[]};
  if (! @features) {
    $self->errorTrack( "No ".$self->my_label." features in this region" ) unless( $self->{'config'}->get('_settings','opt_empty_tracks')==0 );
    return 0;
  }
  my $rStart = $self->{'container'}->{'start'};
  my $rEnd= $self->{'container'}->{'end'};
  my ($min_score, $max_score) = ($self->{_min_score}, $self->{_max_score});
      
  my $row_height = $configuration->{'height'} || 30;
  $configuration->{h} = $row_height;

  $self->push( new Sanger::Graphics::Glyph::Line({
        'x'         => 0,
        'y'         => ($min_score < 0) ? ($row_height + 1) : ($row_height * 2 + 1),
        'width'     => $configuration->{'length'},
        'height'    => 0,
        'absolutey' => 1,
	'colour'    => 'black',
        'dotted'    => 1,
  }));
  if ($min_score < 0) {
     my $peak_score = (abs($max_score) >  abs($min_score) ? abs($max_score) : abs($min_score));
     $max_score = abs($peak_score);
     $min_score = -$max_score;
  }

  my $pix_per_score = ($max_score - $min_score)  / $row_height;
  if ($min_score < 0) {
  	$pix_per_score /= 2;
  }

  $self->push( new Sanger::Graphics::Glyph::Line({
	'x'         => 0,
	'y'         => 0,
	'width'     => 0,
	'height'    => $row_height * 2 + 1,
	'absolutey' => 1,
	'absolutex' => 1,
	'colour'    => 'black',
	'dotted'    => 1,
  }));
  
  my $pX = -1;
  my $pY = -1;

  foreach my $f (sort { $a->start <=> $b->start } @features) {
     my $s = $f->start() < $rStart ? 1 : $f->start()- $rStart;
     my $e = $f->end()   > $rEnd  ? ($rEnd - $rStart) : ($f->end- $rStart);

     my $width = ($e- $s +1);
     my $score = $f->score;
     $score = $min_score if ($score < $min_score);
     $score = $max_score if ($score > $max_score);

     my $height = ($score - $min_score ) / $pix_per_score;
     my $y_offset =     ($row_height * 2 - $height);
     $y_offset-- if (! $score);
     my $Composite = new Sanger::Graphics::Glyph::Composite({
        'y'         => 0,
	'x'         => $s-1,
	'absolutey' => 1,
	'zmenu'    => $self->zmenu( $f->id, $f)
    });
    
    $Composite->push(new Sanger::Graphics::Glyph::Line({
      'x'          => $s-1,
      'y'          => $y_offset,
      'width'      => $width,
      'height'     => 0, #$height,
      'colour'     => $configuration->{'colour'},
      'absolutey'  => 1,
    }));



    my $hh = int(abs($y_offset - $pY));
    if (($s  == $pX) && ($hh > 1) ) {
      $Composite->push( new Sanger::Graphics::Glyph::Line({
        'x'         => $s - 1,
        'y'         =>  $y_offset > $pY ? $pY : $y_offset, #($score ? (($score > 0) ? 1 : ($row_height + 2)) : ($row_height + 1)),
        'width'     => 2,
        'height'    => $hh ,#20, #$score ? $row_height : 1,
        'colour' => $configuration->{'colour'},
        'absolutey' => 1,
       }) );
     }
     $pX = $e;
     $pY = $y_offset;
    
    $self->push( $Composite );
  }
  return 0;
}
sub RENDER_histogram{
  my( $self, $configuration ) = @_;

  my @features = sort {$a->score <=> $b->score} @{$self->features ||[]};
  if (! @features) {
    $self->errorTrack( "No ".$self->my_label." features in this region" ) unless( $self->{'config'}->get('_settings','opt_empty_tracks')==0 );
    return 0;
  }
  my $rStart = $self->{'container'}->{'start'};
  my $rEnd= $self->{'container'}->{'end'};
  my ($min_score, $max_score) = ($self->{_min_score}, $self->{_max_score});
  my $row_height = $configuration->{'height'} || 30;
  my $pix_per_score = ($max_score - $min_score) / $row_height;

  $configuration->{h} = $row_height;
  $self->push( new Sanger::Graphics::Glyph::Line({
      'x'         => 0,
      'y'         => $row_height + 1,
      'width'     => $rEnd - $rStart + 1,
      'height'    => 0,
      'absolutey' => 1,
	'colour'    => 'red',
       'dotted'    => 1,
   }));

  $self->push( new Sanger::Graphics::Glyph::Line({
	'x'         => 0,
	'y'         => 0,
	'width'     => 0,
	'height'    => $row_height + 1,
	'absolutey' => 1,
	'absolutex' => 1,
	'colour'    => 'red',
	'dotted'    => 1,
  }));
  foreach my $f (@features) {
     my $s = $f->start() < $rStart ? 1 : ($f->start()- $rStart + 1);
     my $e = $f->end()   > $rEnd  ? ($rEnd - $rStart) : ($f->end- $rStart + 1);

     my $width = ($e- $s +1);
     my $score = $f->score;

     $score = $min_score if ($score < $min_score);
     $score = $max_score if ($score > $max_score);
     my $height = ($score - $min_score) / $pix_per_score;
     my $y_offset =     $row_height - $height;
     $y_offset-- if (! $score);
#     warn join ' * ', $f->id, $s, $e, $score, $height, $y_offset;

     my $Composite = new Sanger::Graphics::Glyph::Composite({
        'y'         => 0,
	'x'         => $s-1,
	'absolutey' => 1,
	'zmenu'    => $self->zmenu( $f->id, $f)
    });
    
    $Composite->push(new Sanger::Graphics::Glyph::Rect({
      'x'          => $s-1,
      'y'          => $y_offset,
      'width'      => $width,
      'height'     => $height,
      'colour'     => $configuration->{'colour'},
      'absolutey'  => 1,
    }));
    $self->push( $Composite );
  }
  return 0;
}
sub RENDER_signalmap {
  my( $self, $configuration ) = @_;

  my @features = sort { $a->score <=> $b->score } @{$self->features ||[]};
  if (! @features) {
    $self->errorTrack( "No ".$self->my_label." features in this region" ) unless( $self->{'config'}->get('_settings','opt_empty_tracks')==0 );
    return 0;
  }
  my $rStart = $self->{'container'}->{'start'};
  my $rEnd= $self->{'container'}->{'end'};
  my ($min_score, $max_score) = ($self->{_min_score}, $self->{_max_score});
      
  my @positive_features = grep { $_->score >= 0 } @features;
  my @negative_features = grep { $_->score < 0 } reverse @features;
				 
  my $row_height = $configuration->{'height'} || 30;
  my $pix_per_score = (abs($max_score) >  abs($min_score) ? abs($max_score) : abs($min_score)) / $row_height;

  $configuration->{h} = $row_height;
  $self->push( new Sanger::Graphics::Glyph::Line({
      'x'         => 0,
      'y'         => $row_height + 1,
      'width'     => $configuration->{'length'},
      'height'    => 0,
      'absolutey' => 1,
	'colour'    => 'red',
       'dotted'    => 1,
   }));

  $self->push( new Sanger::Graphics::Glyph::Line({
	'x'         => 0,
	'y'         => 0,
	'width'     => 0,
	'height'    => $row_height * 2 + 1,
	'absolutey' => 1,
	'absolutex' => 1,
	'colour'    => 'red',
	'dotted'    => 1,
  }));
  foreach my $f (@negative_features, @positive_features) {
     my $s = $f->start() < $rStart ? 1 : $f->start()- $rStart;
     my $e = $f->end()   > $rEnd  ? ($rEnd - $rStart) : ($f->end- $rStart);

     my $width = ($e- $s +1);
     my $score = $f->score;
     $score = $min_score if ($score < $min_score);
     $score = $max_score if ($score > $max_score);
     my $height = abs($score) / $pix_per_score;
     my $y_offset =     ($score > 0) ?  $row_height - $height : $row_height+2;
     $y_offset-- if (! $score);
#     warn join ' * ', $s, $e, $score, $y_offset, $height;

     my $Composite = new Sanger::Graphics::Glyph::Composite({
        'y'         => 0,
	'x'         => $s-1,
	'absolutey' => 1,
	'zmenu'    => $self->zmenu( $f->id, $f)
    });
    
    $Composite->push(new Sanger::Graphics::Glyph::Rect({
      'x'          => $s-1,
      'y'          => $y_offset,
      'width'      => $width,
      'height'     => $height,
      'colour'     => $configuration->{'colour'},
      'absolutey'  => 1,
    }));
    $self->push( $Composite );
  }
  return 0;
}

sub _init {
  my ($self) = @_;
  my $type = $self->check();
  return unless defined $type;  ## No defined type arghhh!!

  my $strand = $self->strand;
  my $Config = $self->{'config'};
  my $strand_flag    = $Config->get($type, 'str');
  return if( $strand_flag eq 'r' && $strand != -1 || $strand_flag eq 'f' && $strand != 1 );
  if (my $wtype = $self->{'extras'}->{'type'} eq 'wiggle_0') {
     my $gtype = $self->{'extras'}->{'graphType'};
     if ($gtype eq 'points') {
       $self->{'extras'}->{'useScore'} = 4;
     } elsif ($gtype eq 'colour') {
       $self->{'extras'}->{'useScore'} = 2;
     } elsif ($gtype eq 'signal') {
       $self->{'extras'}->{'useScore'} = 1;
     } else {
       $self->{'extras'}->{'useScore'} = 3;
     }
  }
if (0) { 
warn "CONFIG $type : ", ;
foreach my $key (sort keys %{$self->{'extras'}}) {
  warn "$key =>", $self->{'extras'}->{$key};
}
}
  if (my $wdisplay = $self->{'extras'}->{'useScore'}) {
    return if ($strand != -1);
    $self->{'extras'}->{'length'} = $self->{'container'}->{'seq_region_length'};
    $self->{'extras'}->{'colour'} ||= 'contigblue1';
    $self->{'extras'}->{'maxbins'} =  $Config->get('_settings','width');
    $self->merge_features($self->{'extras'});
    return $self->RENDER_signalmap($self->{'extras'}) if ($wdisplay == 1);
    return $self->RENDER_colourgradient($self->{'extras'}) if ($wdisplay == 2);
    return $self->RENDER_histogram($self->{'extras'}) if ($wdisplay == 3);
    return $self->RENDER_plot($self->{'extras'}) if ($wdisplay == 4);
  }

  $self->{'colours'} = $Config->get( $type, 'colour_set' ) ? 
    { $Config->{'_colourmap'}->colourSet( $Config->get( $type, 'colour_set' ) ) } :
    $Config->get( $type, 'colours' );
  $self->{'feature_colour'} = $Config->get($type, 'col') || $self->{'colours'} && $self->{'colours'}{'col'};
  $self->{'label_colour'}   = $Config->get($type, 'lab') || $self->{'colours'} && $self->{'colours'}{'lab'};
  $self->{'part_to_colour'} = '';

  if( $Config->get($type,'compact') ) {
    $self->compact_init($type);
  } else {
    $self->expanded_init($type);
  }
}

sub expanded_init {
  my($self,$type) = @_;

## Information about the container...
  my $length = $self->{'container'}->length();
  my $strand = $self->strand;
## And now about the drawing configuration
  my $Config = $self->{'config'};
  my $strand_flag    = $Config->get($type, 'str');
  my $pix_per_bp     = $Config->transform()->{'scdataalex'};
  my $DRAW_CIGAR     = ( $Config->get($type,'force_cigar') eq 'yes' )|| ($pix_per_bp > 0.2) ;
## Highlights...
  my %highlights = map { $_,1 } $self->highlights;

  my $hi_colour = $Config->get($type, 'hi');
  $hi_colour  ||= $self->{'colours'} ? $self->{'colours'}{'hi'} : 'black';

## Bumping bitmap...
  my @bitmap         = undef;
  my $bitmap_length  = int($length * $pix_per_bp);

  my %id             = ();
  my $dep            = $Config->get(  $type, 'dep' );
  my $h              = $Config->get('_settings','opt_halfheight') ? 4 : 8;
  if( $self->{'extras'} && $self->{'extras'}{'height'} ) {
    warn
    $h = $self->{'extras'}{'height'};
  }

  my ($T,$C1,$C) = (0, 0, 0 );

## Get array of features and push them into the id hash...
  foreach my $features ( grep { ref($_) eq 'ARRAY' } $self->features ) {
    foreach my $f ( @$features ){
      my $hstrand  = 1; #$f->can('hstrand')  ? $f->hstrand : 1;
      my $fgroup_name = $self->feature_group( $f );
      next if $strand_flag eq 'b' && $strand != ( $hstrand*$f->strand || -1 ) || $f->end < 1 || $f->start > $length ;
      push @{$id{$fgroup_name}}, [$f->start,$f->end,$f];
    }
  }

## Now go through each feature in turn, drawing them
  my $y_pos;
  my $n_bumped = 0;
  my $regexp = $pix_per_bp > 0.1 ? '\dI' : ( $pix_per_bp > 0.01 ? '\d\dI' : '\d\d\dI' );
  foreach my $i (keys %id){
    $T+=@{$id{$i}}; ## Diagnostic report....
    my @F = sort { $a->[0] <=> $b->[0] } @{$id{$i}};
    my $START = $F[0][0] < 1 ? 1 : $F[0][0];
    my $END   = $F[-1][1] > $length ? $length : $F[-1][1];
    my $bump_start = int($START * $pix_per_bp) - 1;
       $bump_start = 0 if $bump_start < 0;
    my $bump_end   = int($END * $pix_per_bp);
       $bump_end   = $bitmap_length if $bump_end > $bitmap_length;
    my $row = & Sanger::Graphics::Bump::bump_row( $bump_start, $bump_end, $bitmap_length, \@bitmap, $dep );
    if( $row > $dep ) {
      $n_bumped++;
      next;
    }
    $y_pos = $row * int( - $h - 2 ) * $strand;
    $C1 += @{$id{$i}}; ## Diagnostic report....
    my $Composite = new Sanger::Graphics::Glyph::Composite({
      'href'  => $self->href( $i, $id{$i} ),
      'x'     => $F[0][0]> 1 ? $F[0][0]-1 : 0,
      'width' => 0,
      'y'     => 0,
      'title' => $i,
      'zmenu'    => $self->zmenu( $i, $id{$i} ),
    });
    my $X = -1000000;
    #my ($feature_colour, $label_colour, $part_to_colour) = $self->colour( $F[0][2]->display_id );
    my ($feature_colour, $label_colour, $part_to_colour) = $self->colour( $F[0][2]->display_id, $F[0][2] );
    $feature_colour ||= 'black';
    foreach my $f ( @F ){
      next if int($f->[1] * $pix_per_bp) <= int( $X * $pix_per_bp );
      $C++;
      my $cigar;
      eval { $cigar = $f->[2]->cigar_string; };
      if($DRAW_CIGAR || $cigar =~ /$regexp/ ) {
         my $START = $f->[0] < 1 ? 1 : $f->[0];
         my $END   = $f->[1] > $length ? $length : $f->[1];
         $X = $END;
         $Composite->push(new Sanger::Graphics::Glyph::Space({
           'x'          => $START-1,
           'y'          => 0, # $y_pos,
           'width'      => $END-$START+1,
           'height'     => $h,
           'absolutey'  => 1,
        }));
        $self->draw_cigar_feature($Composite, $f->[2], $h, $feature_colour, 'black', $pix_per_bp, $strand_flag eq 'r'  );
      } else {
        my $START = $f->[0] < 1 ? 1 : $f->[0];
        my $END   = $f->[1] > $length ? $length : $f->[1];
        $X = $END;
        $Composite->push(new Sanger::Graphics::Glyph::Rect({
          'x'          => $START-1,
          'y'          => 0, # $y_pos,
          'width'      => $END-$START+1,
          'height'     => $h,
          'colour'     => $feature_colour,
          'absolutey'  => 1,
        }));
      }
    }
    $Composite->y( $Composite->y + $y_pos );
    $Composite->bordercolour($feature_colour);
    $self->push( $Composite );
    if(exists $highlights{$i}) {
      $self->unshift( new Sanger::Graphics::Glyph::Rect({
        'x'         => $Composite->{'x'} - 1/$pix_per_bp,
        'y'         => $Composite->{'y'} - 1,
        'width'     => $Composite->{'width'} + 2/$pix_per_bp,
        'height'    => $h + 2,
        'colour'    => $hi_colour,
        'absolutey' => 1,
      }));
    }
  }
## No features show "empty track line" if option set....
  $self->errorTrack( "No ".$self->my_label." features in this region" ) unless( $C || $Config->get('_settings','opt_empty_tracks')==0 );
  if( $Config->get('_settings','opt_show_bumped') && $n_bumped ) {
    my $ypos = 0;
    if( $strand < 0 ) {
      $y_pos = ($dep+1) * ( $h + 2 ) + 2;
    } else {
      $y_pos  = 2 + $self->{'config'}->texthelper()->height($self->{'config'}->species_defs->ENSEMBL_STYLE->{'GRAPHIC_FONT'});
    }
    $self->errorTrack( "$n_bumped ".$self->my_label." omitted", undef, $y_pos );
  }
  0 && warn( ref($self), " $C out of a total of ($C1 unbumped) $T glyphs" );
}

sub compact_init {
  my($self,$type) = @_;
  my $length = $self->{'container'}->length();
  my $strand = $self->strand;
  my $Config = $self->{'config'};
  my $strand_flag    = $Config->get($type, 'str');
  my $pix_per_bp     = $Config->transform()->{'scalex'};
  my $DRAW_CIGAR     = ( $Config->get($type,'force_cigar') eq 'yes' )|| ($pix_per_bp > 0.2) ;

  my $h              = 8;

  my ($T,$C1,$C) = (0, 0, 0 );

  my $X = -1e8;
  my $regexp = $pix_per_bp > 0.1 ? '\dI' : ( $pix_per_bp > 0.01 ? '\d\dI' : '\d\d\dI' );
  foreach my $f (
    sort { $a->[0] <=> $b->[0]      }
    map  { [$_->start, $_->end,$_ ] }
#    grep { !($strand_flag eq 'b' && $strand != ( ( $_->can('hstrand') ? $_->hstrand : 1 ) * $_->strand||-1) || $_->start > $length || $_->end < 1) } 
    grep { !($strand_flag eq 'b' && $strand != ( ( $_->can('hstrand') ? 1           : 1 ) * $_->strand||-1) || $_->start > $length || $_->end < 1) } 
    map  { @$_                      }
    grep { ref($_) eq 'ARRAY'       } $self->features
  ) {
    my $START   = $f->[0];
    my $END     = $f->[1];
    ($START,$END) = ($END, $START) if $END<$START; # Flip start end YUK!
    $START      = 1 if $START < 1;
    $END        = $length if $END > $length;
    $T++; $C1++;
    my ($feature_colour, $label_colour, $part_to_colour) = $self->colour( $f->[2]->display_id() );
    next if( $END * $pix_per_bp ) == int( $X * $pix_per_bp );
    $X = $START;
    $C++;
    my $cigar;
    eval { $cigar = $f->[2]->cigar_string; };
    if($DRAW_CIGAR || $cigar =~ /$regexp/ ) {
      $self->draw_cigar_feature($self, $f->[2], $h, $feature_colour, 'black', $pix_per_bp, $strand_flag eq 'r' );
    } else {
      $self->push(new Sanger::Graphics::Glyph::Rect({
        'x'          => $X-1,
        'y'          => 0, # $y_pos,
        'width'      => $END-$X+1,
        'height'     => $h,
        'colour'     => $feature_colour,
        'absolutey'  => 1,
      }));
    }
  }
  $self->errorTrack( "No ".$self->my_label." features in this region" ) unless( $C || $Config->get('_settings','opt_empty_tracks')==0 );

  0 && warn( ref($self), " $C out of a total of ($C1 unbumped) $T glyphs" );
}

sub merge_features {
  my $self = shift;
  my ($econfig) = @_;
  my $maxbins    = $econfig->{'maxbins'} or return;
  my $gStart = $self->{'container'}->start;
  my $gEnd= $self->{'container'}->end;
  my $resolution = (($gEnd - $gStart+1) / $maxbins);
  my @fA = ();
  my @fBitmap;
  my $fHash;
 # Features should sorted by score in descending order by now 
  foreach my $f ( @{$self->features || []}) {
    my ($s, $e, $score) = ($f->start, $f->end, $f->score); 
    my $pS = int(($s - $gStart) / $resolution); # start of the region
    my $pE = int(($e - $gStart) / $resolution); # end of the region
    for (my $i = $pS; $i <= $pE; $i++) {
      if ( ! $fBitmap[$i] || ($fBitmap[$i] < $score)) {
	$fBitmap[$i] = $score;
	if (! exists $fHash->{$f->id}) {
	  push @fA, $f;
	  $fHash->{ $f->id } = 1;
	}
      }
    }
  }
  return $self->{extras}->{_features} = \@fA;
}

1;
