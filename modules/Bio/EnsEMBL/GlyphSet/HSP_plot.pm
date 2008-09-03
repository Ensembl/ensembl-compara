#########
# Author: rmp
# Maintainer: rmp
# Created: 2003
# Last Modified: 2003-05-02
# ensembl-draw HSP plotting glyphset
#
package Bio::EnsEMBL::GlyphSet::HSP_plot;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;

@ISA = qw( Bio::EnsEMBL::GlyphSet );
#use Sanger::Graphics::GlyphSet;
#@ISA = qw(Sanger::Graphics::GlyphSet);
use Sanger::Graphics::Bump;

sub _init {
  my ($self)        = @_;
  my $container     = $self->{'container'};
  my $config        = $self->{'config'};
  my $mode          = ( $config->get('HSP_plot', 'mode') || 
                        $config->get('HSP_query_plot', 'mode') || 
                        "byhit" );

  my $opts = 
    {
     'pix_per_bp'    => $config->transform->{'scalex'},
     'bitmap_length' => int($container->length() * 
                            $config->transform->{'scalex'}),
     'id'            => $container->name,
     'db'            => $container->{'database'},
     'dep'           => ( $config->get('HSP_plot', 'dep') ||  
                          $config->get('HSP_query_plot', 'dep') || 10 ),
     'bitmap'        => [],
     'tally'         => {},
    };

  #########
  # track hsps for '<a name' links inside hits
  #
  #for my $hit (keys %{$container->{'hits'}}) {
  my @all_hsps = ();
  my $ori = $self->strand;
  foreach my $hsp( $container->hsps ){
    my $qori = $hsp->query->strand || 1;
    my $hori = $hsp->hit->strand   || 1;
    if( $qori * $hori != $ori ){next}
    push( @all_hsps, $hsp );
  }

  map{ $self->hsp($_, $opts) }
    sort{ $b->percent_identity <=> $a->percent_identity }
      @all_hsps;
}


sub hsp {
  my ($self, $hsp, $opts) = @_;
  my ($hspstart, $hspend) = $self->region($hsp);
#  my $hspjump             = "\#$opts->{'tally'}->{$hsp}->{'name'}.$opts->{'tally'}->{$hsp}->{'i'}";
#  my $hspseq              = qq(/cgi-bin/blast/getseq?db=$opts->{'db'};acc=$opts->{'tally'}->{$hsp}->{'name'};id=$opts->{'id'};format=no;start=$hspstart;end=$hspend\#Match);
  my $identity            = sprintf("%.2f", $hsp->percent_identity());
  my $colour              = "black";
  
  if($identity > 80) {
    $colour = "darkred";
    
  } elsif($identity > 60) {
    $colour = "firebrick";
    
  } elsif($identity > 40) {
    $colour = "chocolate";
    
  } elsif($identity > 20) {
    $colour = "orange";
    
  } elsif($identity > 0) {
    $colour = "gold";
  }

  my $h        = 5;
  my $score    = $hsp->score();
  my $evalue   = $hsp->evalue();
  my $glyph    = Sanger::Graphics::Glyph::Rect->new({
						     'x'            => $hspstart,
						     'y'            => 0,
						     'width'        => $hspend - $hspstart,
						     'height'       => $h,
						     'colour'       => $colour,
						     'bordercolour' => 'black',
						     'href'         => $self->href($hsp),
						     'zmenu'        => $self->zmenu($hsp),
						    });
  
  my $bump_start = int($glyph->x() * $opts->{'pix_per_bp'});
  $bump_start    = 0 if ($bump_start < 0);
  my $bump_end   = $bump_start + int($glyph->width() * $opts->{'pix_per_bp'}) +1;
  $bump_end      = $opts->{'bitmap_length'} if ($bump_end > $opts->{'bitmap_length'});
  my $row        = &Sanger::Graphics::Bump::bump_row(
						     $bump_start,
						     $bump_end,
						     $opts->{'bitmap_length'},
						     $opts->{'bitmap'},
						    );
  return if($opts->{'dep'} != 0 && $row >= $opts->{'dep'});
  $glyph->y($glyph->y() - (1.6 * $row * $h * $self->strand()));
  $self->push($glyph);
}

sub region {
  my ($self, $hsp) = @_;
  my $start = $hsp->hit->start();
  my $end   = $hsp->hit->end();
  return ($start, $end);
}

sub href {
    my ( $self, $hsp, $type ) = @_;
    my $ticket = $hsp->adaptor->ticket;
    my $hspid = $hsp->token;
    $type ||= 'ALIGN';
    my $htmpl = '/Multi/blastview?ticket=%s;hsp_id=%s;_display=%s';
    return sprintf($htmpl, $ticket, $hspid, $type);
}

sub zmenu {
  my $self = shift;
  my $zmenu = {};
  my $hsp = shift;

  if( $hsp ){
    my $caption = '';
    my $ltmpl = "%s:%s-%s(%s)";
    my $htmpl = '@/Multi/blastview?ticket=%s;hsp_id=%s;_display=ALIGN';
    $zmenu->{caption} = $hsp->query->seq_id." vs. ". $hsp->hit->seq_id;
    $zmenu->{"00:Alignment..."}        = "\@".$self->href($hsp,'ALIGN');
    $zmenu->{"01:Query Sequence..."}   = "\@".$self->href($hsp,'SEQUENCE');
    $zmenu->{"02:Genomic Sequence..."} = "\@".$self->href($hsp,'GSEQUENCE');
    $zmenu->{"03:Raw Score:     ". $hsp->score} = '';
    $zmenu->{"04:PercentID: ". $hsp->percent_identity} ='';
    $zmenu->{"05:Length:    ". $hsp->length } = '';
    my $pv = $hsp->pvalue;
    if( defined( $pv ) ){ $zmenu->{"06:P-value: $pv"} = '' };
    my $ev = $hsp->evalue; 
    if( defined( $ev ) ){ $zmenu->{"07:E-value: $ev"} = '' };
  }
  else{
    $zmenu->{caption} = "Missing HSP!";
  }

  return $zmenu;
}

1;
