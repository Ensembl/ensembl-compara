package Bio::EnsEMBL::GlyphSet_genelabel;

use strict;
use Bio::EnsEMBL::GlyphSet;
@Bio::EnsEMBL::GlyphSet_genelabel::ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Bump;

sub features {
    ## features are now returned by a subroutine, so that this can be 
    ## overridden by subclasses
    my ($self, $logic_name, $database) = @_;
    return $self->{'container'}->get_all_Genes($logic_name, $database);
}

sub _init {
  my $self = shift;

##############################################################################
# Unstranded (on reverse strand!)                                            #
##############################################################################
# May want to change this so that it works on the forward strand, and also   #
# as a stranded version as well!!!                                           #
##############################################################################
  return unless ($self->strand() == -1);

##############################################################################
# Stage 1a: Firstly the configuration hash!                                  #
##############################################################################
  my $type           = $self->check();
  return unless $type;
  my $Config         = $self->{'config'};
#  my $parent_track   = $Config->get($type,'parent') || $type;
  my $pix_per_bp     = $Config->transform->{'scalex'};
  my $fontname       = "Tiny";
  my ($font_w_bp,$h) = $Config->texthelper->px2bp($fontname);
  my $w              = $Config->texthelper->width($fontname);
     $h              = $Config->texthelper->height($fontname);
  my $colours        = $Config->get($type,'colours');
  my $max_length     = $Config->get($type,'threshold') || 1e6;
  my $max_length_nav = $Config->get($type,'navigation_threshold') || 50e3;
  my $navigation     = $Config->get($type,'navigation') || 'off';

##############################################################################
# Stage 1b: Now the virtual contig                                           #
##############################################################################
  my $vc              = $self->{'container'};
  my $vc_length       = $vc->length;
  if( $vc_length > ($max_length*1001)) {
    $self->errorTrack("Gene labels only displayed for less than $max_length Kb.");
    return;
  }
  my $show_navigation = $navigation eq 'on' && ( $vc_length < $max_length_nav * 1001 );
  my $bitmap_length   = int($vc_length * $pix_per_bp);
  my $vc_start        = $vc->start();
  my $offset = $vc_start-1;
##############################################################################
# Stage 1c: Initialize other arrays/numbers                                  #
##############################################################################
  my %highlights = map { $_, 1 } $self->highlights;
  my @bitmap        = undef;
##############################################################################
# Stage 2: Retrieve the gene information from the databases                  #
##############################################################################

  my $database = $Config->get($type,'database');
  foreach my $logic_name ( split /\s+/, $Config->get($type,'logic_name') ) { 
  foreach my $g (@{$self->features( $logic_name, $database )}) {
    my $gene_label = $self->gene_label( $g );
    my $gene_col   = $colours->{ $self->gene_col( $g ) };
    my $ens_ID     = $self->ens_ID( $g );
    my $high = exists $highlights{ $gene_label } || $highlights{ $g->stable_id };
    my $start = $g->start;
    my $end   = $g->end;
    my $chr_start = $start + $offset;
    my $chr_end   = $end   + $offset;
    next if  $end < 1 || $start > $vc_length || $gene_label eq '';
    $start = 1 if $start<1;
    $end   = $vc_length if $end > $vc_length;
    my $tglyph = new Sanger::Graphics::Glyph::Text({
      'x'         => $start-1,	
      'y'         => 0,
      'height'    => $h,
      'width'     => $font_w_bp * length(" $gene_label "),
      'font'      => $fontname,
      'colour'    => $gene_col,
      'text'      => " $gene_label",
      'absolutey' => 1,
    });
    if($show_navigation) {
      $tglyph->{'zmenu'} = {
        'caption'                            => $gene_label,
	"bp: $chr_start-$chr_end"            => '',
        "length: @{[$chr_end-$chr_start+1]}" => ''
      }; 
      if( $ens_ID ne '' ) {
        $tglyph->{'zmenu'}->{"Gene: $ens_ID"} = "/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$ens_ID&db=$database";
        $tglyph->{'href'} = "/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$ens_ID&db=$database" ;
      }
    }
    my $bump_start = int($tglyph->{'x'} * $pix_per_bp);
       $bump_start = 0 if ($bump_start < 0);
    my $bump_end = $bump_start + int($tglyph->width()*$pix_per_bp) +1;
       $bump_end = $bitmap_length if ($bump_end > $bitmap_length);
    my $row = & Sanger::Graphics::Bump::bump_row(
       $bump_start, $bump_end, $bitmap_length, \@bitmap );
       $tglyph->y($tglyph->{'y'} + $row * (2+$h) + 1);
    $self->push( $tglyph );
    ##################################################
    # Draw little taggy bit to indicate start of gene
    ##################################################
    $self->push( new Sanger::Graphics::Glyph::Rect({
      'x'            => $start-1,
      'y'            => $tglyph->y - 1,
      'width'        => 0,
      'height'       => 4,
      'bordercolour' => $gene_col,
      'absolutey'    => 1,
    }));
    $self->push( new Sanger::Graphics::Glyph::Rect({
      'x'            => $start-1,
      'y'            => $tglyph->y - 1 + 4,
      'width'        => $font_w_bp * 0.5,
      'height'       => 0,
      'bordercolour' => $gene_col,
      'absolutey'    => 1,
    }));
    ##################################################
    # Highlight label if required.....
    ##################################################
    $self->unshift( new Sanger::Graphics::Glyph::Rect({
      'x'         => $tglyph->x() + $font_w_bp,
      'y'         => $tglyph->y(),
      'width'     => $tglyph->width() - $font_w_bp,
      'height'    => $tglyph->height(),
      'colour'    => $colours->{'hi'},
      'absolutey' => 1,
    })) if $highlights{$gene_label} || $highlights{$g->stable_id};
   }
  }
}

1;
