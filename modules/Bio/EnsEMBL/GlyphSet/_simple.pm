package Bio::EnsEMBL::GlyphSet::_simple;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet_simple);

sub _das_type {  return 'simple'; }

sub features       { 
  my $self = shift;
  my $call = 'get_all_'.( $self->my_config( 'type' ) || 'SimpleFeatures' ); 
  my @F = map { @{$self->{'container'}->$call( $_ )||[]} }
          @{$self->my_config( 'logicnames' )||[]};
  return \@F;
}

sub colour_key {
  my( $self, $f ) = @_;
  return lc($f->analysis->logic_name);
}

sub feature_label {
  return undef;
}

sub title {
  my( $self, $f ) = @_;
  my($start,$end) = $self->slice2sr( $f->start(), $f->end() );
  return $f->analysis->logic_name.': '.$f->display_label.'; score: '.$f->score. "; bp: $start-$end";
}

sub href {
  my ($self, $f ) = @_;
  return undef;
}

sub tag {
  my ($self, $f ) = @_;
  return; 
}

sub export_feature {
  my $self = shift;
  my ($feature, $feature_type) = @_;
  
  my @label = $feature->can('display_label') ? split (/\s*=\s*/, $feature->display_label) : ();
  
  return $self->_render_text($feature, $feature_type, { 'headers' => [ $label[0] ], 'values' => [ $label[1] ] });
}

1;
