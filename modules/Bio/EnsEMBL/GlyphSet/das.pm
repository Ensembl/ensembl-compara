package Bio::EnsEMBL::GlyphSet::das;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Composite;
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Intron;
use Sanger::Graphics::Bump;
use Data::Dumper;
use POSIX qw(floor);
use ExtURL;


sub init_label {
  my ($self) = @_;

  return if( defined $self->{'config'}->{'_no_label'} );


  my $params =  CGI::escapeHTML($ENV{QUERY_STRING});
  $params =~ s/\&$//;
  $params =~ s/\&/zzz/g;
  my $script = $ENV{ENSEMBL_SCRIPT};

  my $helplink = (defined($self->{'extras'}->{'helplink'})) ?  $self->{'extras'}->{'helplink'} :  qq(/@{[$self->{container}{_config_file_name_}]}/helpview?se=1&kw=$ENV{'ENSEMBL_SCRIPT'}#das);

												     
#  my $URL = $self->das_name =~ /^managed_extdas_(.*)$/ ? qq(javascript:X=window.open(\'/@{[$self->{container}{_config_file_name_}]}/externaldas?action=edit&key=$1\',\'dassources\',\'height=500,width=500,left=50,screenX=50,top=50,screenY=50,resizable,scrollbars=yes\');X.focus();void(0)) :  qq(javascript:X=window.open(\'$helplink\',\'helpview\',\'height=400,width=500,left=100,screenX=100,top=100,screenY=100,resizable,scrollbars=yes\');X.focus();void(0)) ;

  my $URL = $self->das_name =~ /^managed_extdas_(.*)$/ ? qq(javascript:X=window.open(\'/@{[$self->{container}{_config_file_name_}]}/dasconfview?_das_edit=$1&conf_script=$script&conf_script_params=$params\',\'dassources\',\'height=500,width=500,left=50,screenX=50,top=50,screenY=50,resizable,scrollbars=yes\');X.focus();void(0)) :  qq(javascript:X=window.open(\'$helplink\',\'helpview\',\'height=400,width=500,left=100,screenX=100,top=100,screenY=100,resizable,scrollbars=yes\');X.focus();void(0)) ;
																																	  
  my $track_label = $self->{'extras'}->{'caption'} || $self->{'extras'}->{'label'} || $self->{'extras'}->{'name'};
  $track_label =~ s/^(managed_|managed_extdas)//;

  $self->label( new Sanger::Graphics::Glyph::Text({
    'text'      => $track_label,
    'font'      => 'Small',
    'colour'    => 'contigblue2',
    'absolutey' => 1,
    'href'      => $URL,
    'zmenu'     => $self->das_name  =~/^managed_extdas/ ?
      { 'caption' => 'Configure', '01:Advanced configuration...' => $URL } :
      { 'caption' => 'HELP',      '01:Track information...'      => $URL }
  }) );
}

sub _initOLD {
  my ($self) = @_;
  ( my $das_name        = (my $das_config_key = $self->das_name() ) ) =~ s/managed_(extdas_)?//g;
  $das_config_key =~ s/^managed_das/das/;
  my $Config = $self->{'config'};
  my $strand = $Config->get($das_config_key, 'str');
  my $Extra  = $self->{'extras'};

# If strand is 'r' or 'f' then we display everything on one strand (either
# at the top or at the bottom!
  return if( $strand eq 'r' && $self->strand() != -1 || $strand eq 'f' && $self->strand() != 1 );
  my $h;
  $self->{'bitmap'} = [];    
  my $configuration = {
    'strand'   => $strand,
    'tstrand'  => $self->strand,
    'STRAND'   => $self->strand(),
    'cmap'     => $Config->colourmap(),
    'colour'   => $Config->get($das_config_key, 'col') || 'contigblue1',
    'depth'    => $Config->get($das_config_key, 'dep'),
    'use_style'=> $Config->get($das_config_key, 'stylesheet') eq 'Y',
    'length'   => $self->{'container'}->length() +1,
    'labelling'=> $Extra->{'labelflag'} =~ /^[ou]$/i ? 1 : 0,

  };
  $self->{'pix_per_bp'}    = $Config->transform->{'scalex'};
  $self->{'bitmap_length'} = int(($configuration->{'length'}+1) * $self->{'pix_per_bp'});
  ($self->{'textwidth'},$self->{'textheight'}) = $Config->texthelper()->real_px2bp('Tiny');
  $self->{'textwidth'}     *= (1 + 1/($configuration->{'length'}||1) );
  $configuration->{'h'} = $self->{'textheight'};

  my $dsn = $Extra->{'dsn'};
  
  my( $features, $styles ) = @{$self->{'container'}->get_all_DASFeatures->{$dsn}||[]};
  my @features = grep {
    $_->das_type_id() !~ /^(contig|component|karyotype)$/i && 
    $_->das_type_id() !~ /^(contig|component|karyotype):/i &&
    $_->das_start <= $configuration->{'length'} &&
    $_->das_end > 0
  } @{ $features || [] };

  $configuration->{'features'} = \@features;
  my %styles;
  if( $styles && @$styles && $configuration->{'use_style'} ) {
    foreach(@$styles) {
      $styles{$_->{'category'}}{$_->{'type'}} = $_ unless $_->{'zoom'};
      $configuration->{'h'} = $_->{'attrs'}{'height'} if exists $_->{'attrs'} && exists $_->{'attrs'}{'height'};
    } 
    $configuration->{'styles'} = \%styles;
  } else {
    $configuration->{'use_style'} = 0;
  }
  $self->{'link_text'}    = $Extra->{'linktext'} || 'Additional info';
  $self->{'ext_url'}      = ExtURL->new( $Extra->{'name'} =~ /^managed_extdas/ ? ($Extra->{'linkURL'} => $Extra->{'linkURL'}) : () );


  $self->{helplink} = $Config->get($das_config_key, 'helplink');
  my $renderer = $Config->get($das_config_key, 'renderer');
  $renderer = $renderer ? "RENDER_$renderer" : ($Config->get($das_config_key, 'group') ? 'RENDER_grouped' : 'RENDER_simple');


  return $self->$renderer( $configuration );
}


sub RENDER_simple {
  my( $self, $configuration ) = @_;
  my $old_end = -1e9;
  my $empty_flag = 1;

# flag to indicate if not all features have been displayed 
  my $more_features = 0;

  foreach my $f( sort { $a->das_start() <=> $b->das_start() } @{$configuration->{'features'}} ){
    if($f->das_type_id() eq '__ERROR__') {
      $self->errorTrack(
        'Error retrieving '.$self->{'extras'}->{'caption'}.' features ('.$f->das_id.')'
      );
      return -1 ;
    }
    $empty_flag = 0; # We have a feature (its on one of the strands!)
    next if $configuration->{'strand'} eq 'b' && ( $f->strand() !=1 && $configuration->{'STRAND'}==1 || $f->strand() ==1 && $configuration->{'STRAND'}==-1);
    my $ID    = $f->das_id;
    my $label = $f->das_group_label || $f->das_feature_label || $ID;
    my $label_length = $configuration->{'labelling'} * $self->{'textwidth'} * length(" $ID ") * 1.1; # add 10% for scaling text
    my $row = 0;
    my $START = $f->das_start() <  1       ? 1       : $f->das_start();
    my $END   = $f->das_end()   > $configuration->{'length'}  ? $configuration->{'length'} : $f->das_end();
    if( $configuration->{'depth'}>0 ) {
      $row = $self->bump( $START, $END, $label_length, $configuration->{'depth'} );
      if( $row < 0 ) { ## SKIP IF BUMPED...
	  $more_features = 1;
	  next;
      }
    } else {
      next if ( $END - $old_end) < 0.5 / $self->{'pix_per_bp'}; ## Skip the intron/exon if they will not be drawn...
    }
    my ($href, $zmenu ) = $self->zmenu( $f );
    $old_end = $START;
    my $Composite = new Sanger::Graphics::Glyph::Composite({
      'y'         => 0,
      'x'         => $START-1,
      'absolutey' => 1,
      'zmenu'     => $zmenu,
    });
    $Composite->{'href'} = $href if $href;
    my $display_type;
    my $style;
    my $colour;


    if($configuration->{'use_style'}) {
      $style = $configuration->{'styles'}{$f->das_type_category}{$f->das_type_id} || $configuration->{'styles'}{$f->das_type_category}{'default'} || $configuration->{'styles'}{'default'}{'default'};
      $colour = $style->{'attrs'}{'fgcolor'}||$configuration->{'colour'};
      $display_type = "draw_".$style->{'glyph'} || 'draw_box';
    } else {
      $colour = $configuration->{'colour'};
      $display_type = 'draw_box';
    }


# if it is a summary of non-positional features then just display a gene-wide line with a link to geneview where all annotations can be viewed
    if( ( "@{[$f->das_type_id()]}" ) =~ /(summary)/i ) { ## INFO Box
      my $f     = shift @{$configuration->{'features'}};
      my $START = $f->das_start() < 1        ? 1       : $f->das_start();
      my $END   = $f->das_end()   > $configuration->{'length'}  ? $configuration->{'length'} : $f->das_end();

      my $smenu = $self->smenu($f);
      $Composite->{zmenu} = $smenu;
      use integer;

      my $glyph = new Sanger::Graphics::Glyph::Line({
        'x'          => $START-1,
        'y'          => 0,
        'width'      => 0,
        'height'     => $configuration->{'h'},
        'colour'     => $colour,
        'absolutey'  => 1
      });

      $Composite->push($glyph);
      
      $glyph = new Sanger::Graphics::Glyph::Line({
        'x'          => $START,
        'y'          => 0,
        'width'      => 0,
        'height'     => $configuration->{'h'},
        'colour'     => $colour,
        'absolutey'  => 1,
        'absolutex'  => 1
      });

      $Composite->push($glyph);

      my $md = $configuration->{'h'} / 2; 

      $glyph = new Sanger::Graphics::Glyph::Rect({
        'x'          => $START-1,
        'y'          => $md - 1,
        'width'      => $END-$START+1,
        'height'     => 2,
        'colour'     => $colour,
        'absolutey'  => 1
      });

      $Composite->push($glyph);

      $glyph = new Sanger::Graphics::Glyph::Rect({
        'x'          => $END-1,
        'y'          => 0,
        'width'      => 1,
        'height'     => $configuration->{'h'},
        'colour'     => $colour,
        'absolutey'  => 1
      });

      $Composite->push($glyph);

  } else {
    $display_type = 'draw_box' unless $self->can( $display_type );
    if( $display_type eq 'draw_box') {
      $Composite->push( $self->$display_type( $configuration->{'h'}, $START, $END , $colour, $self->{'pix_per_bp'} ) );
    } else {
      $Composite->push( new Sanger::Graphics::Glyph::Space({
        'x'         => $START-1,
        'y'         => 0,
        'width'     => $END-$START+1,
        'height'    => $configuration->{'h'},
        'absolutey' => 1
      }) );
    }
}
    my $H =$self->feature_label( $Composite, $label, $colour, $START, $END );
    $Composite->y($Composite->y() - $configuration->{'tstrand'}*($configuration->{'h'}+2+$H) * $row) if $row;
    $self->push(  $self->$display_type( $configuration->{'h'}, $START, $END , $colour, $self->{'pix_per_bp'}, - $configuration->{'tstrand'}*($configuration->{'h'}+2+$H) * $row) ) unless $display_type eq 'draw_box';
    $self->push( $Composite );
  }
  $self->errorTrack( 'No '.$self->{'extras'}->{'caption'}.' features in this region' ) if $empty_flag;

  if($more_features) {
# There are more features to display : show the note
      my $yx = $configuration->{'depth'};
      my $ID = 'There are more '.$self->{'extras'}->{'label'}.' features in this region. Increase source depth to view them all ';
      $self->errorTrack($ID, undef, $configuration->{'tstrand'}*($configuration->{'h'}) * $yx);
  }    

  return $empty_flag ? 0 : 1 ;
}

sub RENDER_grouped {
  my( $self, $configuration ) = @_; 
  my %grouped;
  my $empty_flag = 1;

  ## GROUP THE FEATURES....
  foreach my $f(@{$configuration->{'features'}}){
    if($f->das_type_id() eq '__ERROR__') {
      $self->errorTrack( 'Error retrieving '.$self->{'extras'}->{'caption'}.' features ('.$f->id.')' );
      return -1; ## A "-1" return indicates no features drawn because DAS returned an error....
    }
    next if $configuration->{'strand'} eq 'b' && ( $f->strand() !=1 && $configuration->{'STRAND'}==1 || $f->strand() ==1 && $configuration->{'STRAND'}==-1);
    my $fid = $f->das_id;
    next unless $fid;
    $fid  = "G:".$f->das_group_id if $f->das_group_id;
    push @{$grouped{$fid}}, $f;
    $empty_flag = 0; # We have a feature (its on one of the strands!)
  }
  if($empty_flag) {
    $self->errorTrack( 'No '.$self->{'extras'}->{'caption'}.' features in this region' );
    return 0; ## A " 0 " return indicates no features drawn....
  }    


# Flag to indicate if not all features got displayed due to the small depth setting
  my $more_features = 0;

  foreach my $value (values %grouped) {
    my $f = $value->[0];
    ## Display if not stranded OR
    my @t_features = sort { $a->das_start <=> $b->das_start } @$value;
    my @features = (shift @t_features);
    foreach( @t_features ) { # Nasty hacky bit that ensures we don't have duplicate das features....
      if($_->das_start <= $features[-1]->das_end ) {
        $features[-1]->das_end( $_->das_end );
      } else {
        push @features, $_;
      } 
    }
    my $start = $features[0]->das_start;    # GET START AND END OF FEATURE....
    my $START = $start < 1 ? 1 : $start;
    my $end   = $features[-1]->das_end;
    ### A general list of features we don't want to draw via DAS ###
    # Compute the length of the label...
    my $ID    = $f->das_group_id || $f->das_id;
    my $label = $f->das_group_label || $f->das_feature_label || $ID;
    my $label_length = $configuration->{'labelling'} * $self->{'textwidth'} * length(" $label ") * 1.1; # add 10% for scaling text
    my $row = $configuration->{'depth'} > 0 ? $self->bump( $START, $end, $label_length, $configuration->{'depth'} ) : 0;

#	 warn("$ID:$label:$label_length:$row");
    if( $row < 0 ) { ## SKIP IF BUMPED...
	$more_features = 1;
	next;
    }
    my( $href, $zmenu ) = $self->zmenu( $f );
    my $Composite = new Sanger::Graphics::Glyph::Composite({
      'y'            => 0,
      'x'            => $START-1,
      'absolutey'    => 1,
      'zmenu'        => $zmenu,
    });
    $Composite->{'href'} = $href if $href;
    ## if we are dealing with a transcript (CDS/transcript/exon) then join with introns...
    my $style;
    my $colour;
    if($configuration->{'use_style'}) {
      $style = $configuration->{'styles'}{$f->das_type_category}{$f->das_type_id} || $configuration->{'styles'}{$f->das_type_category}{'default'} || $configuration->{'styles'}{'default'}{'default'};
      $colour = $style->{'attrs'}{'fgcolor'} || $configuration->{'colour'};
    } else {
      $colour = $configuration->{'colour'};
    }

# if it is a summary of non-positional features then just display a gene-wide line with a link to geneview where all annotations can be viewed
    if( ( "@{[$f->das_group_type]} @{[$f->das_type_id()]}" ) =~ /(summary)/i ) { ## INFO Box
      my $f     = shift @features;
      my $START = $f->das_start() < 1        ? 1       : $f->das_start();
      my $END   = $f->das_end()   > $configuration->{'length'}  ? $configuration->{'length'} : $f->das_end();

      my $smenu = $self->smenu($f);
      $Composite->{zmenu} = $smenu;
      use integer;

      my $glyph = new Sanger::Graphics::Glyph::Line({
        'x'          => $START-1,
        'y'          => 0,
        'width'      => 0,
        'height'     => $configuration->{'h'},
        'colour'     => $colour,
        'absolutey'  => 1
      });

      $Composite->push($glyph);
      
      $glyph = new Sanger::Graphics::Glyph::Line({
        'x'          => $START,
        'y'          => 0,
        'width'      => 0,
        'height'     => $configuration->{'h'},
        'colour'     => $colour,
        'absolutey'  => 1,
        'absolutex'  => 1
      });

      $Composite->push($glyph);

      my $md = $configuration->{'h'} / 2; 

      $glyph = new Sanger::Graphics::Glyph::Rect({
        'x'          => $START-1,
        'y'          => $md - 1,
        'width'      => $END-$START+1,
        'height'     => 2,
        'colour'     => $colour,
        'absolutey'  => 1
      });

      $Composite->push($glyph);

      $glyph = new Sanger::Graphics::Glyph::Rect({
        'x'          => $END-1,
        'y'          => 0,
        'width'      => 1,
        'height'     => $configuration->{'h'},
        'colour'     => $colour,
        'absolutey'  => 1
      });

      $Composite->push($glyph);



    }elsif( ( "@{[$f->das_group_type]} @{[$f->das_type_id()]}" ) =~ /(CDS|translation|transcript|exon)/i ) { ## TRANSCRIPT!
      my $f     = shift @features;
      my $START = $f->das_start() < 1        ? 1       : $f->das_start();
      my $END   = $f->das_end()   > $configuration->{'length'}  ? $configuration->{'length'} : $f->das_end();
      my $old_end   = $END;
      my $glyph = new Sanger::Graphics::Glyph::Rect({
        'x'          => $START-1,
        'y'          => 0,
        'width'      => $END-$START+1,
        'height'     => $configuration->{'h'},
        'colour'     => $colour,
        'absolutey'  => 1,
        'zmenu'      => $zmenu
      });
      $end = $old_end if $end <= $old_end;
      $Composite->push($glyph);
      foreach(@features) {
        my $END   = $_->das_end()   > $configuration->{'length'}  ? $configuration->{'length'} : $_->das_end();
        next if ($END - $old_end) < 0.5 / $self->{'pix_per_bp'}; ## Skip the intron/exon if they will not be drawn...
        my $f_start = $_->das_start;
        $Composite->push( new Sanger::Graphics::Glyph::Intron({
          'x'         => $old_end,
          'y'         => 0,
          'width'     => $f_start-$old_end,
          'height'    => $configuration->{'h'},
          'colour'    => $colour,
          'absolutey' => 1,
          'strand'    => $configuration->{'STRAND'},
        }) );
        $Composite->push( new Sanger::Graphics::Glyph::Rect({
          'x'         => $f_start-1,
          'y'         => 0,
          'width'     => $END-$f_start+1,
          'height'    => $configuration->{'h'},
          'colour'    => $colour,
          'absolutey' => 1,
        }) );
        $old_end = $END;
      }
    } else { ## GENERAL GROUPED FEATURE!
      my $Composite2 = new Sanger::Graphics::Glyph::Composite({
        'y'         => 0,
        'x'         => $START-1,
        'absolutey' => 1,
        'zmenu'     => $zmenu,
      });
      $Composite2->bordercolour($colour);
      my $old_end = -1e9;
      foreach(@features) {
        my $START = $_->das_start() <  1       ? 1 : $_->das_start();
        my $END   = $_->das_end()   > $configuration->{'length'} ? $configuration->{'length'} : $_->das_end();
        next if ($END - $old_end) < 0.5 / $self->{'pix_per_bp'}; ## Skip the intron/exon if they will not be drawn... # only if NOT BUMPED!
        $old_end = $END;
        $Composite2->push( new Sanger::Graphics::Glyph::Rect({
          'x'         => $START-1,
          'y'         => 0,
          'width'     => $END-$START+1,
          'height'    => $configuration->{'h'},
          'colour'    => $colour,
          'absolutey' => 1,
          'zmenu'     => $zmenu
        }) );
      }
      #$Composite2->{'href'} = $href if $href;
      $Composite->push($Composite2);
    }
    ## Now place the label....
    my $H =$self->feature_label( $Composite, $label , $colour, $start < 1 ? 1 : $start , $end > $configuration->{'length'} ? $configuration->{'length'} : $end );
    $Composite->y($Composite->y() - $configuration->{'tstrand'}*($configuration->{'h'}+2+$H) * $row) if $row;
    $self->push($Composite);
}

#  if we have displayed the specified number of rows and there are still some features left then display a note saying that.
      if($more_features) {
	  my $yx = $configuration->{'depth'};
	  my $ID = 'There are more '.$self->{'extras'}->{'caption'}.' features in this region. Increase source depth to view them all ';
	  $self->errorTrack($ID, undef, $configuration->{'tstrand'}*($configuration->{'h'}) * $yx);
      }    

  return 1; ## We have rendered at least one feature....
}

sub to_bin {
  my( $self, $BP, $bin_length, $no_of_bins ) = @_;
  my $bin = floor( $BP / $bin_length );
  my $offset = $BP - $bin_length * $bin;
  if( $bin < 0 ) {
    ($bin,$offset) = (0,0);
  } elsif( $bin >= $no_of_bins ) {
    ($bin,$offset) = ($no_of_bins-1,$bin_length);
  }
  return ($bin,$offset);
}

sub RENDER_density {
  my( $self, $configuration ) = @_;
  my $empty_flag = 1;
  my $no_of_bins = floor( $configuration->{'length'} * $self->{'pix_per_bp'} / 2);
  my $bin_length = $configuration->{'length'} / $no_of_bins;
  my $bins = [ map {0} 1..$no_of_bins ];
## First of all compute the bin values....
## If it is either average coverage or average count we need to compute bin totals first...
## It is trickier for the bases covered - which I'll look at later...
  foreach my $f( @{$configuration->{'features'}} ){
    if($f->das_type_id() eq '__ERROR__') {
      $self->errorTrack(
        'Error retrieving '.$self->{'extras'}->{'caption'}.' features ('.$f->das_id.')'
      );
      return -1 ;
    }
    my( $bin_start, $offset_start ) = $self->to_bin( $f->das_start -1, $bin_length, $no_of_bins );
    my( $bin_end,   $offset_end   ) = $self->to_bin( $f->das_end,      $bin_length, $no_of_bins );
    if( 0 ) { ## average coverage....
      $bins->[$bin_end]   += $offset_end;
      $bins->[$bin_start] -= $offset_start;
      if( $bin_end > $bin_start ) {
        foreach ( $bin_start .. ($bin_end-1) ) {
          $bins->[$_]     += $bin_length;
        }
      }
    } elsif( 1 ) { ## average count
      my $flen = $f->das_end - $f->das_start + 1;
      $bins->[$bin_end]   += $offset_end / $flen;
      $bins->[$bin_start] -= $offset_start / $flen;
      if( $bin_end > $bin_start ) {
        foreach ( $bin_start .. ($bin_end-1) ) {
          $bins->[$_]     += $bin_length / $flen;
        }
      }
    }
    $empty_flag = 0;
  }
  if($empty_flag) {
    $self->errorTrack( 'No '.$self->{'extras'}->{'caption'}.' features in this region' );
    return 0; ## A " 0 " return indicates no features drawn....
  }
## Now we have our bins we need to render the image...
  my $coloursteps  = 10;
  my $rmax  = $coloursteps;
  my @range = ( $configuration->{'colour'} );

  my $display_method = 'scale';
  # my $display_method = 'bars';
  if( $display_method eq 'scale' ) {
    @range = $self->{'config'}->colourmap->build_linear_gradient($coloursteps, 'white', $configuration->{'colour'} );
    $rmax = @range;
  }
  my $max = $bins->[0];
  my $min = $bins->[0];
  foreach( @$bins ) {
    $max = $_ if $max < $_;
    $min = $_ if $min > $_;
  }
  my $divisor = $max - $min;
  my $start = 0;
  foreach( @$bins ) {
    my $F = $divisor ? ($_-$min)/$divisor : 1;
    my $colour_number = $display_method eq 'scale' ? floor( ($rmax-1) * $F ) : 0;
    my $height        = floor( $configuration->{'h'} * ($display_method eq 'bars' ? $F  : 1)  );
    $self->push( new Sanger::Graphics::Glyph::Rect({
      'x'         => $start,
      'y'         => $configuration->{'h'}-$height,
      'width'     => $bin_length,
      'height'    => $height,
      'colour'    => $range[ $colour_number ],
      'absolutey' => 1,
      'zmenu'     => { 'caption' => $_ }
    }) );
    $start+=$bin_length;
  }
  return 1;
}

sub bump{
  my ($self, $start, $end, $length, $dep ) = @_;
  my $bump_start = int($start * $self->{'pix_per_bp'} );
  $bump_start --;
  $bump_start = 0 if ($bump_start < 0);
    
  $end = $start + $length if $end < $start + $length;
  my $bump_end = int( $end * $self->{'pix_per_bp'} );
    $bump_end = $self->{'bitmap_length'} if ($bump_end > $self->{'bitmap_length'});
  my $row = &Sanger::Graphics::Bump::bump_row(
    $bump_start,    $bump_end,   $self->{'bitmap_length'}, $self->{'bitmap'}, $dep 
  );
  return $row > $dep ? -1 : $row;
}

sub zmenu {
  my( $self, $f ) = @_;
  my $id = $f->das_feature_label() || $f->das_group_label() || $f->das_group_id() || $f->das_id();
  my $zmenu = {
    'caption'         => $self->{'extras'}->{'label'},
  };
  $zmenu->{"02:TYPE: ". $f->das_type_id()           } = '' if $f->das_type_id() && uc($f->das_type_id()) ne 'NULL';
  $zmenu->{"03:SCORE: ". $f->das_score()            } = '' if $f->das_score() && uc($f->das_score()) ne 'NULL';
  $zmenu->{"04:GROUP: ". $f->das_group_id()         } = '' if $f->das_group_id() && uc($f->das_group_id()) ne 'NULL' && $f->das_group_id ne $id;

  $zmenu->{"05:METHOD: ". $f->das_method_id()       } = '' if $f->das_method_id() && uc($f->das_method_id()) ne 'NULL';
  $zmenu->{"06:CATEGORY: ". $f->das_type_category() } = '' if $f->das_type_category() && uc($f->das_type_category()) ne 'NULL';
  $zmenu->{"07:DAS LINK: ".$f->das_link_label()     } = $f->das_link() if $f->das_link() && uc($f->das_link()) ne 'NULL';
  $zmenu->{"08:".$f->das_note()     } = '' if $f->das_note() && uc($f->das_note()) ne 'NULL';

  my $href = undef;
  if($self->{'extras'}->{'fasta'}) {
    foreach my $string ( @{$self->{'extras'}->{'fasta'}}) {
    my ($type, $db ) = split /_/, $string, 2;
      $zmenu->{ "20:$type sequence" } = $self->{'ext_url'}->get_url( 'FASTAVIEW', { 'FASTADB' => $string, 'ID' => $id } );
      $href = $zmenu->{ "20:$type sequence" } unless defined($href);
    }
  }
  $href = $f->das_link() if $f->das_link() && !$href;
  if($id && uc($id) ne 'NULL') {
    $zmenu->{"01:ID: $id"} = '';
    if($self->{'extras'}->{'linkURL'}){
      $href = $zmenu->{"08:".$self->{'link_text'}} = $self->{'ext_url'}->get_url( $self->{'extras'}->{'linkURL'}, $id );
    } 
  } 
  return( $href, $zmenu );
}


## feature_label 
## creates and pushes the label 
## and returns the height of the label created
sub feature_label {
  my( $self, $composite, $ID, $feature_colour, $start, $end ) = @_;
  if( uc($self->{'extras'}->{'labelflag'}) eq 'O' ) {
    my $bp_textwidth = $self->{'textwidth'} * length($ID) * 1.2; # add 10% for scaling text
    return unless $bp_textwidth < ($end - $start);
    my $tglyph = new Sanger::Graphics::Glyph::Text({
      'x'          => ( $end + $start - 1 - $bp_textwidth)/2,
      'y'          => 1,
      'width'      => $bp_textwidth,
      'height'     => $self->{'textheight'},
      'font'       => 'Tiny',
      'colour'     => $self->{'config'}->colourmap->contrast($feature_colour),
      'text'       => $ID,
      'absolutey'  => 1,
    });
    $composite->push($tglyph);
    return 0;
  } elsif( uc($self->{'extras'}->{'labelflag'}) eq 'U') {
    my $bp_textwidth = $self->{'textwidth'} * length($ID) * 1.2; # add 10% for scaling text
    my $tglyph = new Sanger::Graphics::Glyph::Text({
      'x'          => $start -1,
      'y'          => $self->{'textheight'} + 2,
      'width'      => $bp_textwidth,
      'height'     => $self->{'textheight'},
      'font'       => 'Tiny',
      'colour'     => $feature_colour,
      'text'       => $ID,
      'absolutey'  => 1,
    });
    $composite->push($tglyph);
    return $self->{'textheight'} + 4;
  } else {
    return 0;
  }
}

sub das_name     { return $_[0]->{'extras'}->{'name'}; }
sub managed_name { return $_[0]->{'extras'}->{'name'}; }

################################################################################
## "Glyph" renderers...                                                      ###
################################################################################

sub draw_box { # Box -- ####
  my( $self, $h, $START, $END, $colour, $pix_per_bp ) =@_;
  return new Sanger::Graphics::Glyph::Rect({
    'x'          => $START-1,
    'y'          => 0,
    'width'      => $END-$START+1,
    'height'     => $h,
    'colour'     => $colour,
    'absolutey' => 1
  });
}

sub draw_farrow { # Forward arrow -- ###>
  my( $self, $h, $START, $END, $colour, $pix_per_bp, $OFFSET ) =@_;
  my $slope = $h/2/$pix_per_bp;
  my $points = ( $END - $START + 1 > $slope ) ?
    [
      $START - 1,    $OFFSET,
      $START - 1,    $OFFSET + $h,
      $END - $slope, $OFFSET + $h,
      $END,          $OFFSET + $h/2,
      $END - $slope, $OFFSET
    ] : [
      $START-1,      $OFFSET,
      $START-1,      $OFFSET + $h,
      $END,          $OFFSET + $h/2
    ];
  return new Sanger::Graphics::Glyph::Poly({
    'points'    => $points,
    'colour'    => $colour,
    'absolutey' => 1
  });
}

sub draw_rarrow { # Reverse arrow -- <###
  my( $self, $h, $START, $END, $colour, $pix_per_bp, $OFFSET ) =@_;
  my $slope = $h/2/$pix_per_bp;
  my $points = ( $END - $START + 1 > $slope ) ?
    [
      $END,                $OFFSET,
      $END,                $OFFSET + $h,
      $START - 1 + $slope, $OFFSET + $h,
      $START - 1,          $OFFSET + $h/2,
      $START - 1 + $slope, $OFFSET
    ] : [
      $END,                $OFFSET,
      $END,                $OFFSET + $h,
      $START-1,            $OFFSET + $h/2
    ];
  return new Sanger::Graphics::Glyph::Poly({
    'points'    => $points,
    'colour'    => $colour,
    'absolutey' => 1
  });
}

sub _init {
  my ($self) = @_;
  ( my $das_name        = (my $das_config_key = $self->das_name() ) ) =~ s/managed_(extdas_)?//g;
  $das_config_key =~ s/^managed_das/das/;
  my $Config = $self->{'config'};
  my $strand = $Config->get($das_config_key, 'str');
  my $Extra  = $self->{'extras'};

# If strand is 'r' or 'f' then we display everything on one strand (either
# at the top or at the bottom!
  return if( $strand eq 'r' && $self->strand() != -1 || $strand eq 'f' && $self->strand() != 1 );
  my $h;
  my $container_length =  $self->{'container'}->length() + 1;
 
 
  $self->{'bitmap'} = [];    
  my $configuration = {
    'strand'   => $strand,
    'tstrand'  => $self->strand,
    'STRAND'   => $self->strand(),
    'cmap'     => $Config->colourmap(),
    'colour'   => $Config->get($das_config_key, 'col') || 'contigblue1',
    'depth'    => $Config->get($das_config_key, 'dep') || 4,
    'use_style'=> $Config->get($das_config_key, 'stylesheet') eq 'Y',
    'labelling'=> $Extra->{'labelflag'} =~ /^[ou]$/i ? 1 : 0,

  };



  my $dsn = $Extra->{'dsn'};
  my $url = defined($Extra->{'url'}) ? $Extra->{'url'}."/$dsn" :  $Extra->{'protocol'}.'://'. $Extra->{'domain'} ."/$dsn";

  my $srcname = $Extra->{'label'} || $das_name;
  $srcname =~ s/^(managed_|mananged_extdas)//;
  my $dastype = $Extra->{'type'} || 'ensembl_location';
  my @das_features = ();
#  warn("TYPE: $dastype\n".Dumper($Extra));
  $Extra->{labelflag} = 'u';
  $configuration->{colour} = $Config->get($das_config_key, 'col') || $Extra->{color} || 'contigblue1';
  $configuration->{depth} =  $Config->get($das_config_key, 'dep') || $Extra->{depth}  || 4;
  $configuration->{use_style} = $Extra->{stylesheet} ? $Extra->{stylesheet} eq 'y' : $Config->get($das_config_key, 'stylesheet') eq 'Y';
  $configuration->{labelling} = $Extra->{labelflag} =~ /^[ou]$/i ? 1 : 0;
  $configuration->{length} = $container_length;

  $self->{'pix_per_bp'}    = $Config->transform->{'scalex'};
  $self->{'bitmap_length'} = int(($configuration->{'length'}+1) * $self->{'pix_per_bp'});
  ($self->{'textwidth'},$self->{'textheight'}) = $Config->texthelper()->real_px2bp('Tiny');
  $self->{'textwidth'}     *= (1 + 1/($container_length||1) );
  $configuration->{'h'} = $self->{'textheight'};

  my $styles;

  if ($dastype ne 'ensembl_location') {
      my $ga =  $self->{'container'}->adaptor->db->get_GeneAdaptor();
      my $genes = $ga->fetch_all_by_Slice( $self->{'container'});
      my $name = $das_name || $url;
      foreach my $gene (@$genes) {
#			 warn("GENE:$gene:".$gene->stable_id);	
	  my $dasf = $gene->get_all_DASFeatures;
	  my %dhash = %{$dasf};

	 
	  my $fcount = 0;
	  my %fhash = ();
	  my @aa = @{$dhash{$name}};
	  foreach my $f (grep { $_->das_type_id() !~ /^(contig|component|karyotype)$/i &&  $_->das_type_id() !~ /^(contig|component|karyotype):/i } @{ $aa[1] || [] }) {
	      if ($f->das_end) {
		  if ($f->das_start <= $configuration->{'length'}) {
		      push(@das_features, $f);
		      
		  }
	      } else {
		  if (exists $fhash{$f->das_segment->ref}) {
		      $fhash{$f->das_segment->ref}->{count} ++;
		  } else {
		      $fhash{$f->das_segment->ref}->{count} = 1;
		      $fhash{$f->das_segment->ref}->{feature} = $f;
		  }
	      }
	  }
	  
	  foreach my $key (keys %fhash) {
#				  warn("FT:$key:".$fhash{$key}->{count});
	      my $ft = $fhash{$key}->{feature}; 
	      if ((my $count = $fhash{$key}->{count}) > 1) {
		  $ft->{das_feature_label} = "$key/$count";

		  $ft->{das_note} = "Found $count annotations for $key";
		  $ft->{das_link_label}  = 'View annotations in geneview';
		  $ft->{das_link} = "/$ENV{ENSEMBL_SPECIES}/geneview?db=core&gene=$key&:DASselect_${srcname}=0&DASselect_${srcname}=1#$srcname";
		  
	      }
	      $ft->{das_type_id}->{id} = 'summary';
	      $ft->{das_start} = $gene->start;
	      $ft->{das_end} = $gene->end;
	      $ft->{das_orientation} = $gene->strand;
	      $ft->{_gsf_strand} = $gene->strand;
	      $ft->{das_strand} = $gene->strand;
	      
	      #	  warn(Dumper($ft));
	      push(@das_features, $ft);
	  }
      }
  } else {
#      warn("EL:($dsn)".$self->{'container'});
      my( $features, $das_styles ) = @{$self->{'container'}->get_all_DASFeatures->{$dsn}||[]};
      $styles = $das_styles;
      @das_features = grep {
	  $_->das_type_id() !~ /^(contig|component|karyotype)$/i && 
	      $_->das_type_id() !~ /^(contig|component|karyotype):/i &&
	      $_->das_start <= $configuration->{'length'} &&
	      $_->das_end > 0
	  } @{ $features || [] };
  }

#  foreach my $f (@das_features) {
#		my $str = join('==', $f->das_feature_label, $f->das_type_id, $f->das_start, $f->das_end);
#		warn("$str");
#  }
# warn("RET:".@das_features);
  $configuration->{'features'} = \@das_features;
  my %styles;
  if( $styles && @$styles && $configuration->{'use_style'} ) {
    foreach(@$styles) {
      $styles{$_->{'category'}}{$_->{'type'}} = $_ unless $_->{'zoom'};
      $configuration->{'h'} = $_->{'attrs'}{'height'} if exists $_->{'attrs'} && exists $_->{'attrs'}{'height'};
    } 
    $configuration->{'styles'} = \%styles;
  } else {
    $configuration->{'use_style'} = 0;
  }
  $self->{'link_text'}    = $Extra->{'linktext'} || 'Additional info';
  $self->{'ext_url'}      = ExtURL->new( $Extra->{'name'} =~ /^managed_extdas/ ? ($Extra->{'linkURL'} => $Extra->{'linkURL'}) : () );


  $self->{helplink} = $Config->get($das_config_key, 'helplink');
  my $renderer = $Config->get($das_config_key, 'renderer');
  my $group = $Config->get($das_config_key, 'group') || 'y';

#  $renderer = $renderer ? "RENDER_$renderer" : ($Config->get($das_config_key, 'group') ? 'RENDER_grouped' : 'RENDER_simple');
  $renderer = $renderer ? "RENDER_$renderer" : ($group eq 'n' ? 'RENDER_simple' : 'RENDER_grouped');
  $renderer =~ s/RENDER_RENDER/RENDER/;

#  warn("RENDER:[$das_config_key: $group] $renderer");
  return $self->$renderer( $configuration );
}

sub smenu {
  my( $self, $f ) = @_;
  my $note = $f->das_note();
  my $zmenu = {
    'caption'         => $self->{'extras'}->{'label'},
  };
  $zmenu->{"02:TYPE: ". $f->das_type_id()           } = '' if $f->das_type_id() && uc($f->das_type_id()) ne 'NULL';
  $zmenu->{"03:".$f->das_link_label()     } = $f->das_link() if $f->das_link() && uc($f->das_link()) ne 'NULL';

  if($note && uc($note) ne 'NULL') {
    $zmenu->{"01:INFO: $note"} = '';
  } 
  return( $zmenu );
}

1;
