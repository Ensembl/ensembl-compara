package Bio::EnsEMBL::GlyphSet::histone_modifications;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump); 
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);
use Data::Dumper;

sub my_label { return "Histone modifications"; }

sub features {
  my ($self) = @_;

  # Dense features. Don't display if slice longer than 50kb
  my $type = $self->check();
  my $max_length     = $self->{'config'}->get( $type, 'threshold' )  || 1000;
  my $slice_length  = $self->{'container'}->length;
  if($slice_length > $max_length*1010) {
    $self->errorTrack('Histone modifications not displayed for more than '.$max_length.'Kb');
    return;
  }

  my $adaptor = $self->{'container'}->adaptor();
  if(!$adaptor) {
    warn('Cannot get histone modifications without attached adaptor');
    return [];
  }

  my $db = $adaptor->db->get_db_adaptor('funcgen');
  if (!$db) {
    warn ("Cannot connect to funcgen");
    return [];
  }
  my $pf_adaptor = $db->get_PredictedFeatureAdaptor();
  if( $pf_adaptor ) {
    my $features = $pf_adaptor->fetch_all_by_Slice($self->{'container'});
    return $features;
  } 
  else {
    warn("Funcgen database must be attached to core database to " .
	    "retrieve funcgen information" );
    return [];
  }
}


sub zmenu {
  my ($self, $f ) = @_;
  my $pos =  $f->start."-".$f->end;
  my %zmenu = ( 
  	       caption               => ($f->display_label || ''),
  	       "03:bp:   $pos"       => '',
  	       "04:type:        ".($f->type->name() || '-') => '',
  	       "05:description: ".($f->type->description() || '-') => '',
  	       "09:score: ".$f->score() => '',
 	      );

   return \%zmenu;
 }
1;
