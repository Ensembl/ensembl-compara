package Bio::EnsEMBL::GlyphSet::blast_new;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;

@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "Blast hits"; }

sub features {
  my ($self) = @_;
  my @T = ();
  foreach my $T ( $self->highlights ) {
    next unless /BLAST_NEW:(.*)/;
    eval { push @T, $self->{'container'}->get_all_SearchFeatures($1); }; 
    warn $@ if $@;
  }
  return @T;
}

sub href {
    my ( $self, $id ) = @_;
    my @bits = split( ':', $id );
    my $meta = pop @bits;
    my( $ticket,$hsp_id,$use_date ) = split( '!!', $meta );
    $use_date || return $id;
    my $htmpl = '/Multi/blastview?ticket=%s&hsp_id=%s!!%s&_display=ALIGN';
    return sprintf($htmpl, $ticket, $hsp_id, $use_date);
    #   return $self->ID_URL( 'SRS_PROTEIN', $id );
}

# Overload SUPER::_init to suppress track if BLAST_NEW not in highlights param
sub _init{
  my $self = shift;
  map{
    /BLAST_NEW:(.*)/ && return $self->SUPER::_init(@_);
  } $self->highlights;
  return undef;
}

sub zmenu {
  my $self = shift;
  my $zmenu = {};

  my $id = shift || 'UNKNOWN!';

  my $boxes     = shift || [];
  my $first_box = $boxes->[0] || [];
  my $feature   = $first_box->[2];

  if( $feature ){

    my $caption = '';
    my $ltmpl = "%s:%s-%s(%s)";
    my $htmpl = '@/Multi/blastview?ticket=%s&hsp_id=%s&_display=ALIGN';
    my( $qryname, $hsptoken ) = split( ':', $feature->hseqname );
    my( $ticket, $hsp_id ) = split( "!!", $hsptoken, 2 );
    $zmenu->{caption} = $qryname." vs. ". $feature->seqname;
    $zmenu->{"00:Details..."} = $self->href($id);

#    $zmenu->{"01:".sprintf($ltmpl, "Hit", , 
#			   $feature->start, $feature->end, 
#			   ( $feature->strand<1 ? '-' : '+' ) ) } = '';
    $zmenu->{"02:Score:     ". $feature->score} = '';
    $zmenu->{"03:PercentID: ". $feature->percent_id} ='';
    $zmenu->{"04:Length:    ". $feature->length } = '';
    my $ev = $feature->p_value;
    if( defined( $ev ) ){ $zmenu->{"05:P-value: $ev"} = '' };
  }
  else{
    $zmenu->{caption} = $id;
  }

  return $zmenu;
}
1;
