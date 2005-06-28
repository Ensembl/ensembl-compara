package Bio::EnsEMBL::GlyphSet_gene;

use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@Bio::EnsEMBL::GlyphSet_gene::ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use  Sanger::Graphics::Bump;
use Data::Dumper;

sub features {
    ## features are now returned by a subroutine, so that this can be 
    ## overridden by subclasses
    my ($self, $logic_name, $database) = @_;
    return $self->{'container'}->get_all_Genes($logic_name, $database);
}

sub init_label {
  my ($self) = @_;
  my $type = $self->check();
  return if( defined $self->{'config'}->{'_no_label'} );
  $self->label(new Sanger::Graphics::Glyph::Text({
    'text'      => $self->my_label(),
    'font'      => 'Small',
    'absolutey' => 1,
    'href'      => qq[javascript:X=hw('@{[$self->{container}{_config_file_name_}]}','$ENV{'ENSEMBL_SCRIPT'}','$type')],
    'zmenu'     => {
      'caption'                     => 'HELP',
      "01:Track information..."     => qq[javascript:X=hw(\'@{[$self->{container}{_config_file_name_}]}\',\'$ENV{'ENSEMBL_SCRIPT'}\',\'$type\')]
    }
  }));
}

sub my_label {    return 'Sometype of Gene'; }
sub my_captions { return {}; }

sub ens_ID {      return $_[1]->stable_id; }
sub gene_label {  return $_[1]->stable_id; }

sub _init {
  my ($self) = @_;

  return unless ($self->strand() == -1);

  my $vc      = $self->{'container'};
  my $type           = $self->check();
  return unless $type;
  my $Config         = $self->{'config'};
  my $h       = 8;
  
  my %highlights;
  @highlights{$self->highlights} = ();    # build hashkeys of highlight list
  my @bitmap         = undef;
  my $vc_length      = $vc->length;
  my $pix_per_bp     = $Config->transform->{'scalex'};
  my $bitmap_length  = int( $vc_length * $pix_per_bp );

  my $colours        = $Config->get($type,'colour_set' ) ? {$Config->{'_colourmap'}->colourSet( $Config->get($type,'colour_set' ) )} : $Config->get($type,'colours');

  my $max_length     = $Config->get($type,'threshold') || 1e6;
  my $max_length_nav = $Config->get($type,'navigation_threshold') || 50e3;
  my $navigation     = $Config->get($type,'navigation') || 'off';

  if( $vc_length > ($max_length*1001)) {
    $self->errorTrack("Genes only displayed for less than $max_length Kb.");
    return;
  }
  my $show_navigation = $navigation eq 'on' && ( $vc->length() < $max_length_nav * 1001 );
   
  #First of all let us deal with all the EnsEMBL genes....
  my $offset = $vc->start - 1;

  my %gene_objs;

  my $F = 0;

  my $fontname       = "Tiny";
  my ($font_w_bp,$h) = $Config->texthelper->px2bp($fontname);
  my $database = $Config->get($type,'database');

  my $used_colours = {};
  my $FLAG = 0;
## We need to store the genes to label...
  my @GENES_TO_LABEL = ();

  foreach my $logic_name (split /\s+/, $Config->get($type,'logic_name') ) {
   my $genes = $self->features( $logic_name, $database );
   foreach my $g (@$genes) {
    my $gene_label = $self->gene_label( $g );
    my $GT         = $self->gene_col( $g );
       $GT =~ s/XREF//g;
    my $gene_col   = ($used_colours->{ $GT } = $colours->{ $GT });
    my $ens_ID     = $self->ens_ID( $g );
    my $high = exists $highlights{ lc($gene_label) } || exists $highlights{ lc($g->stable_id) };
    warn ">>>>>>>>>>>>>>>>>>>>>>>>> $high <<<<<<<<<<<<<<<<<<<<<<<<<<<" if $high;
    my $type = $g->type();
    $type =~ s/HUMACE-//;
    my $start = $g->start;
    my $end   = $g->end;
    my ($chr_start, $chr_end) = $self->slice2sr( $start, $end );
    next if  $end < 1 || $start > $vc_length || $gene_label eq '';
    $start = 1 if $start<1;
    $end   = $vc_length if $end > $vc_length;

    my $start = $g->{'start'};
    my $end   = $g->{'end'};
		
    next if($end < 1 || $start > $vc_length);
    $start = 1 if $start<1;
    $end = $vc_length if $end > $vc_length;

    my $HREF;
    my $Z;
    my $rect = new Sanger::Graphics::Glyph::Rect({
      'x'         => $start-1,
      'y'         => 0,
      'width'     => $end - $start+1,
      'height'    => $h,
      'colour'    => $gene_col->[0],
      'absolutey' => 1,
    });

    if($show_navigation) {
      $Z = {
        'caption' 		              => $gene_label,
        "bp: $chr_start-$chr_end"             => '',
        "type: @{[$g->type]}"                 => '',
	"length: @{[$chr_end-$chr_start+1]}"  => ''
      }; 
      if( $ens_ID ne '' ) {
        $Z->{"Gene: $ens_ID"} = "/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$ens_ID&db=$database"; 
        $HREF= "/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$ens_ID&db=$database";
        $rect->{'href'}  = $HREF;
      }
      $rect->{'zmenu'} = $Z;
    }
    push @GENES_TO_LABEL , {
      'start' => $start,
      'label' => $gene_label,
      'end' => $end,
      'zmenu' => $Z,
      'href' => $HREF,
      'gene' => $g,
      'col' => $gene_col->[0],
      'highlight' => $high
    };
    my $bump_start = int($rect->x() * $pix_per_bp);
    $bump_start = 0 if ($bump_start < 0);
    my $bump_end = $bump_start + int($rect->width()*$pix_per_bp) +1;
       $bump_end = $bitmap_length if ($bump_end > $bitmap_length);
    my $row = & Sanger::Graphics::Bump::bump_row(
       $bump_start, $bump_end, $bitmap_length, \@bitmap);
    $rect->y($rect->y() + (6 * $row ));
    $rect->height(4);
    $self->push($rect);
    warn "$start, $end.................. $colours->{'hi'} .... ",$rect->y," ",$rect->height," ",1/$pix_per_bp if $high;
    $self->unshift(new Sanger::Graphics::Glyph::Rect({
      'x'         => $start -1 - 1/$pix_per_bp,
      'y'         => $rect->y()-1,
      'width'     => $end - $start  +1 + 2/$pix_per_bp,
      'height'    => $rect->height()+2,
      'colour'    => $colours->{'superhi'},
      'absolutey' => 1,
    })) if $high;
    $FLAG=1;
   }
  } 
  if($FLAG) { ## NOW WE NEED TO ADD THE LABELS_TRACK.... FOLLOWED BY THE LEGEND
    if( 1 || $Config->get( '_settings', 'opt_gene_labels' ) ) {
      my $START_ROW = @bitmap + 1;
      @bitmap = ();
      foreach my $gr ( @GENES_TO_LABEL ) {
        my $tglyph = new Sanger::Graphics::Glyph::Text({
          'x'         => $gr->{'start'}-1,
          'y'         => 0,
          'height'    => $h,
          'width'     => $font_w_bp * length(" $gr->{'label'} "),
          'font'      => $fontname,
          'colour'    => $gr->{'col'},
          'text'      => " $gr->{'label'}",
          'zmenu'     => $gr->{'zmenu'},
          'href'      => $gr->{'href'},
          'absolutey' => 1,
        });
      my $bump_start = int($tglyph->{'x'} * $pix_per_bp);
         $bump_start = 0 if ($bump_start < 0);
      my $bump_end = $bump_start + int($tglyph->width()*$pix_per_bp) +1;
         $bump_end = $bitmap_length if ($bump_end > $bitmap_length);
      my $row = & Sanger::Graphics::Bump::bump_row(
         $bump_start, $bump_end, $bitmap_length, \@bitmap );
      $tglyph->y($tglyph->{'y'} + $row * (2+$h) + 1 + ( $START_ROW * 6 ));
      $self->push( $tglyph );
    ##################################################
    # Draw little taggy bit to indicate start of gene
    ##################################################
      $self->push( new Sanger::Graphics::Glyph::Rect({
        'x'            => $gr->{'start'}-1,
        'y'            => $tglyph->y - 1,
        'width'        => 0,
        'height'       => 4,
        'bordercolour' => $gr->{'col'},
        'absolutey'    => 1,
      }));
      $self->push( new Sanger::Graphics::Glyph::Rect({
        'x'            => $gr->{'start'}-1,
        'y'            => $tglyph->y - 1 + 4,
        'width'        => $font_w_bp * 0.5,
        'height'       => 0,
        'bordercolour' => $gr->{'col'},
        'absolutey'    => 1,
      }));
      $self->unshift(new Sanger::Graphics::Glyph::Rect({
        'x'         => $gr->{'start'}-1 - 1/$pix_per_bp,
        'y'         => $tglyph->y()-1,
        'width'     => $tglyph->width()  +1 + 2/$pix_per_bp,
        'height'    => $tglyph->height()+2,
        'colour'    => $colours->{'superhi'},
        'absolutey' => 1,
      })) if $gr->{'highlight'};
      }
      }
    $Config->{'legend_features'}->{$type} = {
      'priority' => $Config->get( $type, 'pos' ),
      'legend'  => $self->legend( $used_colours )
    };
  }
}

sub legend {
  my( $self, $colours ) = @_;
  my @legend = ();
  my %X;
  foreach my $Y ( values %$colours ) { $X{$Y->[1]} = $Y->[0]; }
  my @legend = %X;
  return \@legend;
}

1;
