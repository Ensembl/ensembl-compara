package Bio::EnsEMBL::GlyphSet::_oligo;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(Bio::EnsEMBL::GlyphSet::_alignment);

sub features { 
  my ($self) = @_;
  my $slice = $self->{'container'};
  
  my $fg_db = undef;
  my $db_type  = $self->my_config('db_type')||'funcgen';
  unless($self->{'container'}->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice")) {
    $fg_db = $self->{'container'}->adaptor->db->get_db_adaptor($db_type);
    if(!$fg_db) {
      warn("Cannot connect to $db_type db");
      return [];
    }
  }; 
  my $probe_feature_adaptor = $fg_db->get_ProbeFeatureAdaptor();

  $self->timer_push( 'Preped');
  my ($vendor_name, $array_name ) = split (/:/, $self->my_config('array'));
  my $T = $probe_feature_adaptor->fetch_all_by_Slice_array_vendor( $slice, $array_name, $vendor_name );
  $self->timer_push( 'Retrieved oligos', undef, 'fetch' );
  return ( $self->my_config('array') => [$T] );
}

sub feature_group {
  my( $self, $f ) = @_; 
  next unless ( $f && $f->isa('Bio::EnsEMBL::Funcgen::ProbeFeature'));
  my ($vendor_name, $array_name ) = split (/:/, $self->my_config('array')); 
  if ( $f->probeset_id) { 
    return $f->probe->probeset->name;
  } else { 
    return $f->probe->get_probename($array_name);
  }  
}

sub feature_label {
  my( $self, $f ) = @_;
  return $self->feature_group($f);
}

sub feature_title {
  my( $self, $f ) = @_; 
  return $self->feature_group($f);
#  return "Probe set: ".$f->probe->probeset->name;
}

sub href {
### Links to /Location/Feature with type of 'OligoProbe'
  my ($self, $f ) = @_;
  my ($vendor, $name ) = split (/:/, $self->my_config('array'));
  return;

#  return $self->_url({
#    'object' => 'Location',
#    'action' => 'Genome',
#    'db'     => 'funcgen',
#    'ftype'  => 'ProbeFeature',
#    'id'     => $f->probe->probeset->name,
#    'array'  => $name,
#  });
}

sub export_feature {
  my $self = shift;
  my ($feature, $source) = @_;
  return; 
#  return $self->_render_text($feature, 'Oligo', {
#    'headers' => [ 'probeset' ],
#    'values' => [ $feature->can('probeset') ? $feature->probeset : '' ]
#  }, { 'source' => $source });
}

1
