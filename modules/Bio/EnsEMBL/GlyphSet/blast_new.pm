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
    eval { 
      push @T, $self->{'container'}->get_all_SearchFeatures($1); 
    }; 
    warn $@ if $@;
  }
  return @T;
}

sub href {
    my ( $self, $id, $type ) = @_;
    my @bits = split( ':', $id );
    my $meta = pop @bits;
    my( $ticket,$hsp_id,$use_date ) = split( '!!', $meta );
    $use_date || return $id;
    if (!$type || (ref($type) eq 'ARRAY')){
        $type = 'ALIGN';
    };
    my $htmpl = '/Multi/blastview?ticket=%s;hsp_id=%s!!%s;_display=%s';
    return sprintf($htmpl, $ticket, $hsp_id, $use_date, $type);
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
  my $feature   = $boxes;

  if( $feature ){

    my $caption = '';
    my $ltmpl = "%s:%s-%s(%s)";
    my( $qryname, $hsptoken ) = split( ':', $feature->hseqname );
    my( $ticket, $hsp_id ) = split( "!!", $hsptoken, 2 );
    $zmenu->{caption} = $qryname." vs. ". $feature->seqname;
    $zmenu->{"00:Alignment..."} = "\@".$self->href($id,'ALIGN');
    $zmenu->{"01:Query Sequence..."} = "\@".$self->href($id,'SEQUENCE');
    $zmenu->{"02:Genomic Sequence..."} = "\@".$self->href($id,'GSEQUENCE');
    $zmenu->{"03:Score:     ". $feature->score} = '';
    $zmenu->{"04:PercentID: ". $feature->percent_id} ='';
    $zmenu->{"05:Length:    ". $feature->length } = '';
    my $pv = $feature->p_value;
    if( defined( $pv ) ){ $zmenu->{"06:P-value: $pv"} = '' };
#    my $ev = $feature->e_value; No e_value for Bio::EnsEMBL::BaseAlignFeature
#    if( defined( $ev ) ){ $zmenu->{"07:E-value: $ev"} = '' };
  }
  else{
    $zmenu->{caption} = $id;
  }

  return $zmenu;
}
1;
