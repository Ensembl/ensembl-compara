package Bio::EnsEMBL::GlyphSet::supporting_evidence;

use strict;
use vars qw(@ISA);

use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Space;
use Sanger::Graphics::Glyph::Intron;
use Bio::EnsEMBL::GlyphSet_simple;   
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label {  # no labbel
  my $self = shift;
  return ;
}

sub href {
  my ($self, $hit, $exon_count) = @_;
  my $alignment = '';
  my $seq_type = 'P';
  my $Container = $self->{'container'};
   #links to alignview
    
  $seq_type = 'N' if ( $Container->{'hits'}{$hit}{'datalib'} !~ /swir/i ) ;
   
  if ( $Container->{'hits'}{$hit}{'datalib'} !~ /pfamfrag/i && $hit !~ /^WP.+[A-Z]$/i ) {
    $alignment =
        "/@{[$self->{container}{_config_file_name_}]}/alignview?transcript=".$Container->{'transcript'}{'ID'}.";exon=".@{$Container->{'hits'}{$hit}{'exon_ids'}}[$exon_count].";sequence=".$hit.";seq_type=$seq_type;db=".
  $Container->{'transcript'}{'db'} ;
  }
 
  return $alignment;
}

sub _init {
    my ($self) = @_;
    
    my $Container   = $self->{'container'};
    my $Config      = $self->{'config'};
    my $display_limit = 0; 
  
  my( $fontname_i, $fontsize_i ) = $self->get_font_details( 'innertext' );
  my @res_i = $self->get_text_width( 0, 'X', '', 'font'=>$fontname_i, 'ptsize' => $fontsize_i );
  my $th_i = $res_i[3];
  my( $fontname_o, $fontsize_o ) = $self->get_font_details( 'innertext' );
  my @res_o = $self->get_text_width( 0, 'X', '', 'font'=>$fontname_o, 'ptsize' => $fontsize_o );
  my $th_o = $res_o[3];

  my $pix_per_bp = $self->{'config'}->transform()->{'scalex'};

    my $BOX_HEIGHT    = 10;  # exon height
    my $BOX_WIDTH     = 25;  # exon width
    my $INTRON_HEIGHT = 10;  # intron height
    my $INTRON_WIDTH  = 15;  # intron width
    my $TEXT_HEIGHT   = 10;  # label height
    my $TEXT_WIDTH    = 70;  # label width

    my $CONT_LENGTH   = $Config->get('_settings','width') ;    # get container lenght  
    my $LOW_SCORE = $Config->get('supporting_evidence', 'low_score'); # low score colour
    my $HIGH_SCORE = $Config->get('supporting_evidence', 'colours', '100'); # high score colour  
    my $down = -7;
    my $exon_colour;
    my $NO_OF_COLUMNS = $Container->{'transcript'}->{'exon_count'} ;   
    my $track_width = $NO_OF_COLUMNS * ($BOX_WIDTH + $INTRON_WIDTH) + $TEXT_WIDTH + 10;

# Make box smaller if not enough exons to fill the pre-set size box (1200)    
    if ($track_width < $CONT_LENGTH ){
      $track_width = $track_width > 600 ? $track_width : 600 ; # don't do smaller than 800
      $Config->set('_settings','width', $track_width) ;
      $CONT_LENGTH   = $track_width ;
    }
    
# If large number of exons then make container bigger (might do optional show)
      if ($NO_OF_COLUMNS > 50){
        my $new_width = int(($NO_OF_COLUMNS * 30) + $TEXT_WIDTH + 10);
   $Config->set('_settings','width',$new_width);
        $CONT_LENGTH = $Config->get('_settings','width') ;
      }
    
# re-size the introns and exon proportionally regarding to no of exons  
    if ($track_width > $CONT_LENGTH ){
     my $new_column_width = ($CONT_LENGTH - $TEXT_WIDTH + 10) / ($NO_OF_COLUMNS + 1) ;
     my $intron_exon_prop = ($INTRON_WIDTH + $BOX_WIDTH) / $new_column_width; 
     $BOX_WIDTH   =  $BOX_WIDTH / $intron_exon_prop ;
     $INTRON_WIDTH =  $INTRON_WIDTH / $intron_exon_prop ;
    }

# header containing exon number
my $x = $TEXT_WIDTH + 10 + ($BOX_WIDTH / 2);    
for (my $j=1; $j <= $NO_OF_COLUMNS; $j++){
 
    my @res = $self->get_text_width( 0, "$j",'', 'font'=>$fontname_o, 'ptsize' => $fontsize_o );
    my $tmp_width = $res[2]/$pix_per_bp;

    my $header = new Sanger::Graphics::Glyph::Text({
      'x'          => $x - $tmp_width/2,
      'y'          => 0,
      'width'      => $tmp_width,
      'textwidth'  => $res[2],
      'height'     => $th_o,
      'font'       => $fontname_o,
      'ptsize'     => $fontsize_o,
      'colour'     => 'darkred',
      'text'       => $j ,
      'absolutey'  => 1,
      'absolutex'  => 1,'absolutewidth'=>1,
    });  
$self->push($header);
$x = $x + $BOX_WIDTH + $INTRON_WIDTH;
 
 }
        
# sort hits by top score , num exons hit, total score and then the data lib type    
for my $hit (sort { $Container->{'hits'}{$b}{'top_score'} <=> $Container->{'hits'}{$a}{'top_score'} ||
                    $Container->{'hits'}{$b}{'num_exon_hits'} <=> $Container->{'hits'}{$a}{'num_exon_hits'} ||
                    $Container->{'hits'}{$b}{'total_score'} <=> $Container->{'hits'}{$a}{'total_score'} ||
        $Container->{'hits'}{$a}{'datalib'} cmp $Container->{'hits'}{$b}{'datalib'} }
        keys %{$Container->{'hits'}}){

   if (!$Config->get('supporting_evidence','hide_hits')){
  $display_limit++;
   }
   last if ($display_limit > 10);

# the whole image is a single track !! so count row blocks to move down   
    my ($x, $y) = (($TEXT_WIDTH + 10), (20 + $down));
    $down = $down + $INTRON_HEIGHT + 20;
 
# Print the db acc for each hit     
   my $db_acc = new Sanger::Graphics::Glyph::Text({
                    'x'          => 1 ,
                  'y'          => $y,
                  'width'      => $TEXT_WIDTH,
                  'height'     => $th_o,
                    'font'       => $fontname_o,
                    'ptsize'     => $fontsize_o,
                    'halign'     => 'left', 
                    'colour'     => 'blue',
                 'text'       => $hit,
        'href'       => $Container->{'hits'}{$hit}{'link'},
                'absolutey'  => 1,
  });
   $self->push($db_acc);
   
# print the description (add full decription) under the exons
   my $desc_text = $Container->{'hits'}{$hit}{'description'}; 
   my $cont = '';
   my @res;
   @res = $self->get_text_width( ($CONT_LENGTH-$TEXT_WIDTH-30), $desc_text, '', 'font' => $fontname_i, 'ptsize' => $fontsize_i );
   while( $res[0] eq '' && $desc_text ne '' ) {
     $desc_text =~ s/ ([^ ]*)$//;
     @res = $self->get_text_width( ($CONT_LENGTH-$TEXT_WIDTH-30), "$desc_text...", '', 'font' => $fontname_i, 'ptsize' => $fontsize_i );
   };
   my $desc = new Sanger::Graphics::Glyph::Text({
     'x'          => $x ,
     'y'          => $y + 12,
     'width'      => ($BOX_WIDTH + $INTRON_WIDTH) * $NO_OF_COLUMNS,
     'height'     => $th_i,
     'font'       => $fontname_i,
     'ptsize'     => $fontsize_i,
     'halign'     => 'left',
     'text'       => $res[0], 
     'colour'     => 'Black',
     'absolutey'  => 1,
     'absolutex'  => 1,'absolutewidth'=>1,
   });
$self->push($desc);

# for each hit (with score) add an exon onto the hit line   
   for (my $exon_count = 0; $exon_count < $NO_OF_COLUMNS; $exon_count++){
      my $score = $Container->{'hits'}{$hit}{'scores'}[$exon_count];   
      my $datalib = $Container->{'hits'}{$hit}{'datalib'};
      if ($score){
        my $score_group;
  if ($score >=100 ){$score_group = '100' ;}
  elsif ($score >=99 ){$score_group = '99' ;}
  elsif ($score >=97 ){$score_group = '97' ;}
  elsif ($score >=90 ){$score_group = '90' ;}
  elsif ($score >=75 ){$score_group = '75' ;}
  elsif ($score >=50 ){$score_group = '50' ;}
  
  $exon_colour = $Config->get('supporting_evidence', $score_group );
  
  
  if  (($score < 25 && $datalib =~ /pfamfrag/i) || 
       ($score < 80 && $datalib !~ /pfamfrag/i)){
    $exon_colour = $LOW_SCORE;}

      my $alignment_href = $self->href($hit, $exon_count) ;

    my $rect = new Sanger::Graphics::Glyph::Rect({
       'x'         => $x ,
       'y'         => $y ,
       'width'     => $BOX_WIDTH , 
       'height'    => $BOX_HEIGHT,
       'colour'    => $exon_colour,
       'absolutey' => 1,
       'absolutex' => 1 ,'absolutewidth'=>1,
       'href'      => "$alignment_href",
       'zmenu'     => {
         'caption'                     => "Supporting Evidence",
         "00:Data Source: ".$datalib   => '',
      "01:Score: $score"     => '',
      "02:Accession: $hit"         => $Container->{'hits'}{$hit}{'link'},
            "03:View Exon Alignment"     => "$alignment_href",
      }, 
    });
   $self->push($rect); 
   
  }else{
  my $blank = new Sanger::Graphics::Glyph::Rect({
    'x'            => $x ,
    'y'            => $y ,
    'width'       => $BOX_WIDTH , 
    'height'      => $BOX_HEIGHT,
    'bordercolour'    => $LOW_SCORE,
    'absolutey'    => 1,
    'absolutex'    => 1 ,'absolutewidth'=>1, 
  });
  $self->push($blank);
  
  }

# colour introns the right colour if no hit before or after  
  my $intron_col = $Container->{'hits'}{$hit}{'scores'}[$exon_count + 1] && $Container->{'hits'}{$hit}{'scores'}[$exon_count] ? $exon_colour : $LOW_SCORE;

  unless ($exon_count +1 >= $NO_OF_COLUMNS){     # don't draw intron on end of transcript
  my $intron = new Sanger::Graphics::Glyph::Intron({
    'x'          => $x + $BOX_WIDTH ,
    'y'          => $y , 
    'width'      => $INTRON_WIDTH ,
    'strand'     => 1,
    'height'     => $INTRON_HEIGHT,
    "colour"     => $intron_col,
    'absolutey'  => 1,
    'absolutex'  => 1 ,'absolutewidth'=>1,
  });
  $self->push($intron);
}
# Move along the 'track'  

  $x = $x + $BOX_WIDTH + $INTRON_WIDTH ;

   }  
  }
}

1;
        
