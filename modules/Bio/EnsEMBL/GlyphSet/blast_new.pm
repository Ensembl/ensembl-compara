package Bio::EnsEMBL::GlyphSet::blast_new;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;

@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "Blast hits"; }

sub features {
    my ($self) = @_;
    return map {
       /BLAST_NEW:(.*)/? $self->{'container'}->get_all_SearchFeatures($1):()
    } $self->highlights;
}

sub href {
    my ( $self, $id ) = @_;
    return $id;
    #   return $self->ID_URL( 'SRS_PROTEIN', $id );
}

sub zmenu {
  my $self = shift;
  my $zmenu = {};

  $zmenu->{caption} = shift || 'UNKNOWN!';

  my $boxes     = shift || [];
  my $first_box = $boxes->[0] || [];
  my $feature   = $first_box->[2];
  
  if( $feature ){
    if( $feature->has_tag('qname') ){ 
      my $qstring = '';
      $qstring.= ($feature->each_tag_value('qname'))[0].":";
      $qstring.= ($feature->each_tag_value('qstart'))[0] ."-";
      $qstring.= ($feature->each_tag_value('qend'))[0];
      $zmenu->{"00:Qry: $qstring"} = '';
    }
    if( $feature->has_tag('hname') ){ 
      my $hstring = '';
      $hstring.= ($feature->each_tag_value('hname'))[0].":";
      $hstring.= ($feature->each_tag_value('hstart'))[0] ."-";
      $hstring.= ($feature->each_tag_value('hend'))[0];
      $zmenu->{"01:Hit: $hstring"} = '';
    }
    $zmenu->{"02:Score:     ". $feature->score} = '';
    $zmenu->{"03:PercentID: ". $feature->percent_id} ='';
    $zmenu->{"04:Length:    ". $feature->length } = '';
    my $ev = $feature->p_value;
    if( defined( $ev ) ){ $zmenu->{"05:P-value: $ev"} = '' };
  }

  return $zmenu;
}
1;
