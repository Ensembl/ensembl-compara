package Bio::EnsEMBL::GlyphSet_transcript;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Intron;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Composite;
use Sanger::Graphics::Glyph::Line;
use  Sanger::Graphics::Bump;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end);

sub init_label {
    my ($self) = @_;
    return if( defined $self->{'config'}->{'_no_label'} );
    my $HELP_LINK = $self->check();
    my $label = new Sanger::Graphics::Glyph::Text({
        'text'      => $self->my_label(),
        'font'      => 'Small',
        'absolutey' => 1,
        'href'      => qq[javascript:X=window.open(\'/$ENV{'ENSEMBL_SPECIES'}/helpview?se=1&kw=$ENV{'ENSEMBL_SCRIPT'}#$HELP_LINK\',\'helpview\',\'height=400,width=500,left=100,screenX=100,top=100,screenY=100,resizable,scrollbars=yes\');X.focus();void(0)],

        'zmenu'     => {
            'caption'                     => 'HELP',
            "01:Track information..."     =>
qq[javascript:X=window.open(\\\'/$ENV{'ENSEMBL_SPECIES'}/helpview?se=1&kw=$ENV{'ENSEMBL_SCRIPT'}#$HELP_LINK\\\',\\\'helpview\\\',\\\'height=400,width=500,left=100,screenX=100,top=100,screenY=100,resizable,scrollbars=yes\\\');X.focus();void(0)]
        }
    });
    $self->label($label);
#    $self->bumped( $self->{'config'}->get($HELP_LINK, 'dep')==0 ? 'no' : 'yes' );
}

sub my_label {
    my $self = shift;
    return 'Missing label';
}


sub colours {  
  # Implemented by subclass 
  return {}; 
}

sub text_label {
  # Implemented by subclass
  return undef;
}


sub features {  
  my $self = shift;

  $self->warn("GlyphSet_transcript->features is deprecated");
  return []; 
}


sub features {
  my $self = shift;

  $self->throw("features not implemented by subclass of Glyphset_transcript\n");
}


sub transcript_type {
  my $self = shift;

 # Implemented by subclass 
}
  
sub _init {
    my ($self) = @_;

    my $type = $self->check();
    return unless defined $type;

    my $Config        = $self->{'config'};
    my $container     = exists $self->{'container'}{'ref'} ? $self->{'container'}{'ref'} : $self->{'container'};
    my $target        = $Config->{'_draw_single_Transcript'};
    my $target_gene   = $Config->{'geneid'};
    
    my $y             = 0;
    my $h             = $target ? 30 : 8;   #Single transcript mode - set height to 30 - width to 8!
    
    my %highlights;
    @highlights{$self->highlights} = ();    # build hashkeys of highlight list

    my @bitmap        = undef;
    my $colours       = $self->colours();

    my $fontname      = "Tiny";    
    my $pix_per_bp    = $Config->transform->{'scalex'};
    my $bitmap_length = int($Config->container_width() * $pix_per_bp);
 
    ($type) = reverse(split('::', ref( $self )));

    my $strand  = $self->strand();
    my $length  = $container->length;
    my $transcript_drawn = 0;
    
    foreach my $gene (@{$self->features()}) {
      # For alternate splicing diagram only draw transcripts in gene
        next if $target_gene && ($gene->stable_id() ne $target_gene);

        foreach my $transcript (@{$gene->get_all_Transcripts()}) {
	    #sort exons on their start coordinate
            my @exons = sort {$a->start <=> $b->start} grep { $_ } @{$transcript->get_all_Exons()};
            # Skip if no exons for this transcript
	    next if (@exons == 0);
	    # If stranded diagram skip if on wrong strand
	    next if (@exons[0]->strand() != $strand && $self->{'do_not_strand'}!=1 );
	    # For exon_structure diagram only given transcript
	    next if $target && ($transcript->stable_id() ne $target);

            $transcript_drawn=1;        
            my $Composite = new Sanger::Graphics::Glyph::Composite({'y'=>$y,'height'=>$h});
        
            $Composite->{'href'} = $self->href( $gene, $transcript );
	
	    $Composite->{'zmenu'} = $self->zmenu( $gene, $transcript ) unless $Config->{'_href_only'};
	
	    my($colour, $hilight) = $self->colour( $gene, $transcript, $colours, %highlights );

            my $coding_start = $transcript->coding_start() || $transcript->start();
            my $coding_end   = $transcript->coding_end()   || $transcript->end();
            my $Composite2 = new Sanger::Graphics::Glyph::Composite({'y'=>$y,'height'=>$h});
            for(my $i = 0; $i < @exons; $i++) {
	         my $exon = @exons[$i];
	         next unless defined $exon; #Skip this exon if it is not defined (can happen w/ genscans) 
	         my $next_exon = ($i < $#exons) ? @exons[$i+1] : undef;
	         #First draw the exon
	         # We are finished if this exon starts outside the slice
	         last if $exon->start() > $length;

	         my($box_start, $box_end);

	         # only draw this exon if is inside the slice
	         if($exon->end() > 0 ) { #calculate exon region within boundaries of slice
	             $box_start = $exon->start();
	             $box_start = 1 if $box_start < 1 ;
                     $box_end = $exon->end();
	             $box_end = $length if$box_end > $length;
	             if($box_start < $coding_start || $box_end > $coding_end ) {
	      # The start of the transcript is before the start of the coding
	      # region OR the end of the transcript is after the end of the
	      # coding regions.  Non coding portions of exons, are drawn as
	      # non-filled rectangles
	      #Draw a non-filled rectangle around the entire exon
	                 $Composite2->push(new Sanger::Graphics::Glyph::Rect({
                            'x'         => $box_start -1 ,
                            'y'         => $y,
                            'width'     => $box_end-$box_start +1,
                            'height'    => $h,
                            'bordercolour' => $colour,
                            'absolutey' => 1,
		        }));
            	     } 
	    # Calculate and draw the coding region of the exon
	             my $filled_start = $box_start < $coding_start ? $coding_start : $box_start;
	             my $filled_end   = $box_end > $coding_end  ? $coding_end   : $box_end;
	    # only draw the coding region if there is such a region
	             if( $filled_start <= $filled_end ) {
	    #Draw a filled rectangle in the coding region of the exon
        	        my $rect = new Sanger::Graphics::Glyph::Rect({
                        'x'         => $filled_start -1,
                        'y'         => $y,
                        'width'     => $filled_end - $filled_start + 1,
                        'height'    => $h,
                        'colour'    => $colour,
                        'absolutey' => 1 });
	                $Composite2->push($rect);
	             }
	          } 
	  #we are finished if there is no other exon defined
                last unless defined $next_exon;

	  #calculate the start and end of this intron
	        my $intron_start = $exon->end() + 1;
	        my $intron_end = $next_exon->start()-1;

	  #grab the next exon if this intron is before the slice
	        next if($intron_end < 0);
	  
	  #we are done if this intron is after the slice
	        last if($intron_start > $length);
	  
	  #calculate intron region within slice boundaries
	        $box_start = $intron_start < 1 ? 1 : $intron_start;
	        $box_end   = $intron_end > $length ? $length : $intron_end;

	        my $intron;

                if( $box_start == $intron_start && $box_end == $intron_end ) {
	    # draw an wholly in slice intron
	            $Composite2->push(new Sanger::Graphics::Glyph::Intron({
                    'x'         => $box_start -1,
                    'y'         => $y,
                    'width'     => $box_end-$box_start + 1,
                    'height'    => $h,
                    'colour'    => $colour,
                    'absolutey' => 1,
                    'strand'    => $strand,
                    }));
	        } else { 
	      # else draw a "not in slice" intron
                $Composite2->push(new Sanger::Graphics::Glyph::Line({
                     'x'         => $box_start -1 ,
                     'y'         => $y+int($h/2),
                     'width'     => $box_end-$box_start + 1,
                     'height'    => 0,
                     'absolutey' => 1,
                     'colour'    => $colour,
                     'dotted'    => 1,
                 }));
                 }
            }

            if($self->can('join')) {
                my @tags = $self->join( $gene->stable_id );
                foreach (@tags) {
                    warn( $gene->stable_id." -> $_" );
                    $self->tag( $Composite2, $_, 0, $self->strand==-1 ? 0 : 1, 'grey60' );
                    $self->tag( $Composite2, $_, 1, $self->strand==-1 ? 0 : 1, 'grey60' );
                }
            }
            $Composite->push($Composite2);
            my $bump_height = 1.5 * $h;
            if( $Config->{'_add_labels'} ) {
	        if(my $text_label = $self->text_label($gene, $transcript) ) {
                my($font_w_bp, $font_h_bp) = $Config->texthelper->px2bp($fontname);
	            my $width_of_label = $font_w_bp * 1.15 * (length($text_label) + 1);
	            my $tglyph = new Sanger::Graphics::Glyph::Text({
                    'x'         => $Composite->x(),
                    'y'         => $y+$h+2,
                    'height'    => $font_h_bp,
                    'width'     => $width_of_label,
                    'font'      => $fontname,
                    'colour'    => $colour,
                    'text'      => $text_label,
                    'absolutey' => 1,
                });
	            $Composite->push($tglyph);
	            $bump_height = 1.7 * $h + $font_h_bp;
	        }
            }
 
        ########## bump it baby, yeah! bump-nology!
            my $bump_start = int($Composite->x * $pix_per_bp);
            $bump_start = 0 if ($bump_start < 0);
    
            my $bump_end = $bump_start + int($Composite->width * $pix_per_bp)+1;
            $bump_end = $bitmap_length if $bump_end > $bitmap_length;
            my $row = & Sanger::Graphics::Bump::bump_row( $bump_start, $bump_end, $bitmap_length, \@bitmap);
    
        ########## shift the composite container by however much we're bumped
            $Composite->y($Composite->y() - $strand * $bump_height * $row);
            $Composite->colour($hilight) if(defined $hilight && !defined $target);
            $self->push($Composite);
        
            if($target) {     
	  # check the strand of one of the transcript's exons
	        my ($trans_exon) = @{$transcript->get_all_Exons};
	        if($trans_exon->strand() == 1) {
	            my $clip1 = new Sanger::Graphics::Glyph::Line({
                   'x'         => 0,
                   'y'         => -4,
                   'width'     => $length,
                   'height'    => 0,
                   'absolutey' => 1,
                   'colour'    => $colour
                });
	            $self->push($clip1);
	            $clip1 = new Sanger::Graphics::Glyph::Poly({
                	'points' => [
                        $length - 4/$pix_per_bp,-2,
                        $length                ,-4,
                        $length - 4/$pix_per_bp,-6],
			        'colour'    => $colour,
                	'absolutey' => 1,
                });
                $self->push($clip1);
	        } else {
	            my $clip1 = new Sanger::Graphics::Glyph::Line({
                   'x'         => 0,
                   'y'         => $h+4,
                   'width'     => $length,
                   'height'    => 0,
                   'absolutey' => 1,
                   'colour'    => $colour
                });
	            $self->push($clip1);
	            $clip1 = new Sanger::Graphics::Glyph::Poly({
                    'points'    => [ 4/$pix_per_bp,$h+6,
                                     0,              $h+4,
                                     4/$pix_per_bp,$h+2],
		            'colour'    => $colour,
                    'absolutey' => 1,
                });
	            $self->push($clip1);
	        }
           }  
      }
      }
          if($transcript_drawn) {
             my ($key, $priority, $legend) = $self->legend( $colours );
             $Config->{'legend_features'}->{$key} = {
                'priority' => $priority,
                'legend'   => $legend
	     } if defined($key);
      } elsif( $Config->get('_settings','opt_empty_tracks')!=0) {
          $self->errorTrack( "No ".$self->error_track_name()." in this region" );
     }

}
1;
