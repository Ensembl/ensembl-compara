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
    return $id;
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
    if( $feature->has_tag('qname') ){ 
      my $qname  = ($feature->each_tag_value('qname'))[0] || 'UNKNOWN!';
      my $qstart = ( $feature->has_tag('qstart') ? 
		     ($feature->each_tag_value('qstart'))[0] : '' );
      my $qend   = ( $feature->has_tag('qend') ? 
		     ($feature->each_tag_value('qend'))[0] : '' );
      my $qstrand= ( $feature->has_tag('qstrand') ? 
		     ($feature->each_tag_value('qstrand'))[0] : '' );

      $caption .= $qname ." vs. ";
      $zmenu->{ "00:Qry: $qstart-$qend(". ( $qstrand<1 ? '-)' : '+)' ) } = '';
    }
    if( $feature->has_tag('hname') ){ 
      my $hname = ($feature->each_tag_value('hname'))[0] || 'UNKNOWN!';
      my $hstart = ( $feature->has_tag('hstart') ? 
		     ($feature->each_tag_value('hstart'))[0] : '' );
      my $hend   = ( $feature->has_tag('hend') ? 
		     ($feature->each_tag_value('hend'))[0] : '' );
      my $hstrand= ( $feature->has_tag('hstrand') ? 
		     ($feature->each_tag_value('hstrand'))[0] : '' );

      $caption .= $hname;
      $zmenu->{ "00:Hit: $hstart-$hend(". ( $hstrand<1 ? '-)' : '+)' ) } = '';
    }
    $zmenu->{caption} = $caption;
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
