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
use ExtURL;


sub init_label {
    my ($self) = @_;
    return if( defined $self->{'config'}->{'_no_label'} );

    my $URL = $self->das_name =~ /^managed_extdas_(.*)$/ ?
qq[javascript:X=window.open(\'/@{[$self->{container}{_config_file_name_}]}/externaldas?action=edit&key=$1\',\'dassources\',\'height=500,width=500,left=50,screenX=50,top=50,screenY=50,resizable,scrollbars=yes\');X.focus();void(0)] : qq[javascript:X=window.open(\'/@{[$self->{container}{_config_file_name_}]}/helpview?se=1&kw=$ENV{'ENSEMBL_SCRIPT'}#das\',\'helpview\',\'height=400,width=500,left=100,screenX=100,top=100,screenY=100,resizable,scrollbars=yes\');X.focus();void(0)] ;

    (my $T = $URL)=~s/\'/\\\'/g;
    #####'###### 
    $self->label( new Sanger::Graphics::Glyph::Text({
        'text'      => $self->{'extras'}->{'caption'},
        'font'      => 'Small',
        'colour'    => 'contigblue2',
        'absolutey' => 1,
        'href'      => $URL,
        'zmenu'     => $self->das_name  =~/^managed_extdas/ ?
            {   'caption'                       => 'Configure' ,
                '01:Advanced configuration...'  => $T }:
            {   'caption'                       => 'HELP', 
                "01:Track information..."       => $T }
    }) );
}


sub _init {
    my ($self) = @_;

    my $Config          = $self->{'config'};
    ( my $das_name        = (my $das_config_key = $self->das_name() ) ) =~ s/managed_(extdas_)?//g;
    $das_config_key =~ s/^managed_das/das/;

    my $strand          = $Config->get($das_config_key, 'str');
# If strand is 'r' or 'f' then we display everything on one strand (either
# at the top or at the bottom!

    return if( $strand eq 'r' && $self->strand() != -1 || $strand eq 'f' && $self->strand() != 1 );

    $self->{'bitmap'} = [];    
    my $tstrand = $self->strand;
    my $cmap            = $Config->colourmap();
    my $feature_colour  = $Config->get($das_config_key, 'col') || 'contigblue1';
    my $dep             = $Config->get($das_config_key, 'dep');
    my $group           = $Config->get($das_config_key, 'group');
    my $use_style       = $Config->get($das_config_key, 'stylesheet') eq 'Y';
    my $vc              = $self->{'container'};
    my $border          = 'black' ;
    my $red             = 'red' ;
    ($self->{'textwidth'},$self->{'textheight'}) = $Config->texthelper()->real_px2bp('Tiny');
    my $length          = $vc->length() +1;

    $self->{'pix_per_bp'}    = $Config->transform->{'scalex'};
    $self->{'bitmap_length'} = int(($length+1) * $self->{'pix_per_bp'});

    $self->{'textwidth'}    *= ($length+1)/$length;
    my $h = $self->{'textheight'};
    
    my @features;
    my ( $features, $styles ) = @{ $vc->get_all_DASFeatures()->{$self->{'extras'}{'dsn'}}||[] };
    $use_style = 0 unless $styles && @{$styles};
    
    #print STDERR "STYLE: $use_style\n";

    eval{
        @features = grep { $_->das_type_id() !~ /(contig|component|karyotype)/i } @{$features||[]};
    };
    my %styles = ();
    if( $use_style ) {
        #print STDERR Dumper($styles);
        
       foreach(@$styles) {
          $styles{$_->{'category'}}{$_->{'type'}} = $_ unless $_->{'zoom'};
       } 
    }
    # warn map { "DAS: ". $_->das_dsn. ": ". $_->das_start."-".$_->das_end."|\n"}  @features;
    if($@) {
        print STDERR "----------\n",$@,"---------\n";
        return;
    }
    $self->{'link_text'}    = $self->{'extras'}->{'linktext'} || 'Additional info';
    $self->{'ext_url'}      = $self->{'extras'}->{'name'} =~ /^managed_extdas/ ? 
        ExtURL->new( $self->{'extras'}->{'linkURL'} => $self->{'extras'}->{'linkURL'} ) :
        ExtURL->new();        
    
    my $empty_flag  = 1;
    ## Set a 1/0 flag to find out whether or not we are adding labels....
    
    my $labelling = uc($self->{'extras'}->{'labelflag'}) eq 'O' || uc($self->{'extras'}->{'labelflag'}) eq 'U' ? 1 : 0;
    my $STRAND = $self->strand();
    my $T = 0; my $C = 0; my $C1 = 0;
    if($group==1) {
        my %grouped;
        foreach my $f(@features){
            if($f->das_type_id() eq '__ERROR__') {
                $self->errorTrack( 'Error retrieving '.$self->{'extras'}->{'caption'}.' features ('.$f->id.')' );
                return;
            }
            next if $strand eq 'b' && ( $f->strand() !=1 && $STRAND==1 || $f->strand() ==1 && $STRAND==-1);
            my $fid = $f->das_id;
            next unless $fid;
            $fid  = "G:".$f->das_group_id if $f->das_group_id;
            push @{$grouped{$fid}}, $f;
            $empty_flag = 0; # We have a feature (its on one of the strands!)
        }

        if($empty_flag) {
            $self->errorTrack( 'No '.$self->{'extras'}->{'caption'}.' features in this region' );
            return;
        }    
        
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
            
            $T += @features;
            $T += @features-1 if ( $f->das_group_type || $f->das_type_id() ) =~ /(CDS|translation|transcript|exon)/i;
            ### A general list of features we don't want to draw via DAS ###
            # Compute the length of the label...
            my $ID    = $f->das_group_id || $f->das_id;
            my $label = $f->das_group_label || $f->das_feature_label || $ID;
            my $label_length = $labelling * $self->{'textwidth'} * length(" $label ") * 1.1; # add 10% for scaling text

            my $row = $dep > 0 ? $self->bump( $START, $end, $label_length, $dep ) : 0;

            next if( $row < 0 ); ## SKIP IF BUMPED...
            
            my ($href, $zmenu ) = $self->zmenu( $f );
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
                if($use_style) {
                  $style = $styles{$f->das_type_category}{$f->das_type_id} || $styles{$f->das_type_category}{'default'} || $styles{'default'}{'default'};
                  $colour = $style->{'attrs'}{'fgcolor'}||$feature_colour;
                } else {
                  $colour = $feature_colour;
                }
            #warn "@{[$f->das_id]} - @{[$f->das_group_type]} - @{[$f->das_type_id]}";
            if( ( "@{[$f->das_group_type]} @{[$f->das_type_id()]}" ) =~ /(CDS|translation|transcript|exon)/i ) { ## TRANSCRIPT!
                my $f     = shift @features;
                my $START = $f->das_start() < 1        ? 1       : $f->das_start();
                my $END   = $f->das_end()   > $length  ? $length : $f->das_end();
                my $old_end   = $END;
             #   print STDERR "DAS: E ",$f->das_start,"-",$f->das_end," (",$f->das_id,"-",$f->das_group_id,")\n";
                $C1 ++; 
                $C ++; 
                my $glyph = new Sanger::Graphics::Glyph::Rect({
                    'x'          => $START-1,
                    'y'          => 0,
                    'width'      => $END-$START+1,
                    'height'     => 8,
                    'colour'     => $colour,
                    'absolutey'  => 1,
                    'zmenu'      => $zmenu
                });
            #$glyph->{'href'} = $href if $href;
                $end = $old_end if $end <= $old_end;
                $Composite->push($glyph);
                
                foreach(@features) {
                    my $END   = $_->das_end()   > $length  ? $length : $_->das_end();
                    $C1 +=2; 
                    next if ($END - $old_end) < 0.5 / $self->{'pix_per_bp'}; ## Skip the intron/exon if they will not be drawn...
                    $C +=2; 
                    my $f_start = $_->das_start;
                    $Composite->push( new Sanger::Graphics::Glyph::Intron({
                        'x'         => $old_end,
                        'y'         => 0,
                        'width'     => $f_start-$old_end,
                        'height'    => 8,
                        'colour'    => $colour,
                        'absolutey' => 1,
                        'strand'    => $STRAND,
                    }) );
                    $Composite->push( new Sanger::Graphics::Glyph::Rect({
                        'x'          => $f_start-1,
                        'y'          => 0,
                        'width'      => $END-$f_start+1,
                        'height'     => 8,
                        'colour'     => $colour,
                        'absolutey' => 1,
                    }) );
                    $old_end = $END;
                }
            } else { ## GENERAL GROUPED FEATURE!
                my $Composite2 = new Sanger::Graphics::Glyph::Composite({
                    'y'            => 0,
                    'x'            => $START-1,
                    'absolutey'    => 1,
                    'zmenu'        => $zmenu,
                });
                $Composite2->bordercolour($colour);
                my $old_end = -1e9;
                foreach(@features) {
             #       print STDERR "DAS: F ",$_->das_start,"-",$_->das_end," (",$_->das_id,"-",$_->das_group_id,")\n";
                    my $START = $_->das_start() <  1       ? 1 : $_->das_start();
                    my $END   = $_->das_end()   > $length  ? $length : $_->das_end();
                    $C1 ++; 
                    next if ($END - $old_end) < 0.5 / $self->{'pix_per_bp'}; ## Skip the intron/exon if they will not be drawn... # only if NOT BUMPED!
                    $C ++; 
                    $old_end = $END;
                    $Composite2->push( new Sanger::Graphics::Glyph::Rect({
                        'x'          => $START-1,
                        'y'          => 0,
                        'width'      => $END-$START+1,
                        'height'     => 8,
                        'colour'     => $colour,
                        'absolutey' => 1,
                        'zmenu'     => $zmenu
                    }) );
                }
                #$Composite2->{'href'} = $href if $href;
                $Composite->push($Composite2);
            }
            my $H =$self->feature_label( $Composite, $label , $colour, $start < 1 ? 1 : $start , $end > $length ? $length : $end );
#            $Composite->{'zmenu'}->{"SHIFT ($row) ".$tstrand*(1.4*$h+$H) * $row } = '';
            $Composite->y($Composite->y() - $tstrand*(1.4*$h+$H) * $row) if $row;
            $self->push($Composite);
        }
    } else {
        my $old_end = -1e9;
        foreach my $f( sort { $a->das_start() <=> $b->das_start() } @features){
            if($f->das_type_id() eq '__ERROR__') {
                $self->errorTrack(
                    'Error retrieving '.$self->{'extras'}->{'caption'}.' features ('.$f->das_id.')'
                );
                return;
            }
            $empty_flag = 0; # We have a feature (its on one of the strands!)
            next if $strand eq 'b' && ( $f->strand() !=1 && $STRAND==1 || $f->strand() ==1 && $STRAND==-1);
            my $ID    = $f->das_id;
            my $label = $f->das_group_label || $f->das_feature_label || $ID;
            my $label_length = $labelling * $self->{'textwidth'} * length(" $ID ") * 1.1; # add 10% for scaling text

            my $row = 0;
            my $START = $f->das_start() <  1       ? 1       : $f->das_start();
            my $END   = $f->das_end()   > $length  ? $length : $f->das_end();
	    $T++;
            if($dep>0) {
                $row = $self->bump( $START, $END, $label_length, $dep );
                next if $row < 0;
                $C1++;
            } else {
	        $C1++;
                next if ( $END - $old_end) < 0.5 / $self->{'pix_per_bp'}; ## Skip the intron/exon if they will not be drawn...
            }
	    $C++;
                
            my ($href, $zmenu ) = $self->zmenu( $f );
            $old_end = $START;
            my $Composite = new Sanger::Graphics::Glyph::Composite({
                'y'            => 0,
                'x'            => $START-1,
                'absolutey'    => 1,
                'zmenu'        => $zmenu,
            });
            $Composite->{'href'} = $href if $href;
                my $display_type;
                my $style;
                my $colour;
                if($use_style) {
                  $style = $styles{$f->das_type_category}{$f->das_type_id} || $styles{$f->das_type_category}{'default'} || $styles{'default'}{'default'};
                  $colour = $style->{'attrs'}{'fgcolor'}||$feature_colour;
                  $display_type = "draw_".$style->{'glyph'} || 'draw_box';
                } else {
                  $colour = $feature_colour;
                  $display_type = 'draw_box';
                }
                $display_type = 'draw_box' unless $self->can( $display_type );
                if( $display_type eq 'draw_box') {
                  $Composite->push( $self->$display_type( $START, $END , $colour, $self->{'pix_per_bp'} ) );
                } else {
                  $Composite->push(
                     new Sanger::Graphics::Glyph::Space({
    'x'          => $START-1,
    'y'          => 0,
    'width'      => $END-$START+1,
    'height'     => 8,
    'absolutey' => 1
                }) );
                }
            #$glyph->{'href'} = $href if $href;
            # DONT DISPLAY IF BUMPING AND BUMP HEIGHT TOO GREAT
            my $H =$self->feature_label( $Composite, $label, $colour, $START, $END );
#            $Composite->{'zmenu'}->{"SHIFT ($row) ".$tstrand*(1.4*$h+$H) * $row } = '';
            $Composite->y($Composite->y() - $tstrand*(1.4*$h+$H) * $row) if $row;
            $self->push(  $self->$display_type( $START, $END , $colour, $self->{'pix_per_bp'}, - $tstrand*(1.4*$h+$H) * $row) ) unless $display_type eq 'draw_box';
            $self->push($Composite);
        }
    
        $self->errorTrack( 'No '.$self->{'extras'}->{'caption'}.' features in this region' ) if $empty_flag;
    }   
    #warn( $self->{'extras'}->{'caption'}." $C glyphs drawn from $T ( $C1 )" );
}

sub draw_box {
  my( $self, $START, $END, $colour, $pix_per_bp ) =@_;
  return new Sanger::Graphics::Glyph::Rect({
    'x'          => $START-1,
    'y'          => 0,
    'width'      => $END-$START+1,
    'height'     => 8,
    'colour'     => $colour,
    'absolutey' => 1
  });
}

sub draw_farrow {
  my( $self, $START, $END, $colour, $pix_per_bp, $OFFSET ) =@_;

  my $points;
  if( ($END - $START+1) > 4 / $pix_per_bp ) {
     $points = [ $START-1, $OFFSET, $START-1, $OFFSET+8, $END - 4/$pix_per_bp, $OFFSET+8, $END, $OFFSET+4, $END - 4/$pix_per_bp, $OFFSET ];
  } else {
     $points = [ $START-1, $OFFSET, $START-1, $OFFSET+8, $END, $OFFSET+4 ];
  }
  return new Sanger::Graphics::Glyph::Poly({
    'points' => $points,
    'colour'     => $colour,
    'absolutey' => 1
  });
}

sub draw_rarrow {
  my( $self, $START, $END, $colour, $pix_per_bp, $OFFSET ) =@_;
  my $points;
  if( ($END - $START+1) > 4 / $pix_per_bp ) {
     $points = [ $END, $OFFSET, $END, $OFFSET+8, $START -1 + 4/$pix_per_bp, $OFFSET+8, $START - 1, $OFFSET + 4, $START - 1 + 4/$pix_per_bp, $OFFSET ];
  } else {
     $points = [ $END, $OFFSET, $END, $OFFSET + 8, $START-1, $OFFSET+4 ];
  }
  return new Sanger::Graphics::Glyph::Poly({
    'points' => $points,
    'colour'     => $colour,
    'absolutey' => 1
  });
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
  #warn "@{[$f->das_group_id]} - @{[$f->das_id]}";
  my $zmenu = {
    'caption'         => $self->{'extras'}->{'label'},
#   "DAS source info" => $self->{'extras'}->{'url'},
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
            # print STDERR "XXX> $ID $self->{'textheight'} XX\n";
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
            return $self->{'textheight'} + 4
        } else {
            return 0;
    }
}

sub das_name {
    my ($self) = @_;
    return $self->{'extras'}->{'name'};
}

sub managed_name {
    my ($self) = @_;
    return $self->{'extras'}->{'name'}
}

1;
