package Bio::EnsEMBL::GlyphSet_gene;

use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@Bio::EnsEMBL::GlyphSet_gene::ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use  Sanger::Graphics::Bump;
use EnsWeb;
use Data::Dumper;

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

sub my_label { return 'Sometype of Gene'; }
sub my_captions { return {}; }

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

  my $colours        = $Config->get($type,'colours');

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

  my $database = $Config->get($type,'database');

  my $used_colours = {};
  my $FLAG = 0;
  foreach my $logic_name (split /\s+/, $Config->get($type,'logic_name') ) {
   my $genes = $vc->get_all_Genes( $logic_name, $database );
   foreach my $g (@$genes) {
    my $gene_label = $self->gene_label( $g );
    my $GT         = $self->gene_col( $g );
       $GT =~ s/XREF//g;
    my $gene_col   = ($used_colours->{ $GT } = $colours->{ $GT });
    my $ens_ID     = $self->ens_ID( $g );
    my $high = exists $highlights{ $gene_label } || $highlights{ $g->stable_id };
    my $type = $g->type();
    $type =~ s/HUMACE-//;
    my $start = $g->start;
    my $end   = $g->end;
    my $chr_start = $start + $offset;
    my $chr_end   = $end   + $offset;
    next if  $end < 1 || $start > $vc_length || $gene_label eq '';
    $start = 1 if $start<1;
    $end   = $vc_length if $end > $vc_length;

    my $start = $g->{'start'};
    my $end   = $g->{'end'};
		
    next if($end < 1 || $start > $vc_length);
    $start = 1 if $start<1;
    $end = $vc_length if $end > $vc_length;

    my $rect = new Sanger::Graphics::Glyph::Rect({
      'x'         => $start-1,
      'y'         => 0,
      'width'     => $end - $start+1,
      'height'    => $h,
      'colour'    => $gene_col,
      'absolutey' => 1,
    });

    if($show_navigation) {
      $rect->{'zmenu'} = {
        'caption' 		              => $gene_label,
        "bp: $chr_start-$chr_end"             => '',
	"length: @{[$chr_end-$chr_start+1]}"  => ''
      }; 
      if( $ens_ID ne '' ) {
        $rect->{'zmenu'}->{"Gene: $g->{'ens_ID'}"} = "/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$ens_ID&db=$database"; 
        $rect->{'href'} = "/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$ens_ID&db=$database";
      }
    }
    my $bump_start = int($rect->x() * $pix_per_bp);
    $bump_start = 0 if ($bump_start < 0);
    my $bump_end = $bump_start + int($rect->width()*$pix_per_bp) +1;
       $bump_end = $bitmap_length if ($bump_end > $bitmap_length);
    my $row = & Sanger::Graphics::Bump::bump_row(
       $bump_start, $bump_end, $bitmap_length, \@bitmap);
    $rect->y($rect->y() + (6 * $row ));
    $rect->height(4);
    $self->push($rect);
    $self->unshift(new Sanger::Graphics::Glyph::Rect({
      'x'         => $start -1 - 1/$pix_per_bp,
      'y'         => $rect->y()-1,
      'width'     => $end - $start  +1 + 2/$pix_per_bp,
      'height'    => $rect->height()+2,
      'colour'    => $colours->{'hi'},
      'absolutey' => 1,
    })) if $highlights{$gene_label} || $highlights{$g->stable_id};
    $FLAG=1;
   }
  } 
  if($FLAG) {
    $Config->{'legend_features'}->{$type} = {
      'priority' => $Config->get( $type, 'pos' ),
      'legend'  => $self->legend( $used_colours )
    };
  }
}

sub legend {
  my( $self, $colours ) = @_;
  my @legend = ();
  my $lcap = $self->legend_captions();
  foreach my $key ( %{$lcap} ) {
    push @legend, $lcap->{$key} => $colours->{$key} if exists $colours->{$key};
  } 
  return \@legend;
}

1;
