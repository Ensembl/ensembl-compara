package Bio::EnsEMBL::GlyphSet::_simple;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet_simple);

sub features { 
  my $self     = shift;
  my $call     = 'get_all_' . ($self->my_config('type') || 'SimpleFeatures'); 
  my $db_type       = $self->my_config('db');
  my @features = map @{$self->{'container'}->$call($_, undef, $db_type)||[]}, @{$self->my_config('logic_names')||[]};
  
  return \@features;
}

sub colour_key { return lc $_[1]->analysis->logic_name; }
sub _das_type  { return 'simple'; }

sub title {
  my ($self, $f)    = @_;
  my ($start, $end) = $self->slice2sr($f->start, $f->end);
  my $score = length($f->score) ? sprintf('score: %s;', $f->score) : '';
  return sprintf '%s: %s; %s bp: %s', $f->analysis->logic_name, $f->display_label, $score, "$start-$end";
}

sub href {
  my ($self, $f) = @_;
  my $ext_url = $self->my_config('ext_url');
  
  return undef unless $ext_url;
  
  my ($start, $end) = $self->slice2sr($f->start, $f->end);
  
  return $self->_url({
    action        => 'SimpleFeature',
    logic_name    => $f->analysis->logic_name,
    display_label => $f->display_label,
    score         => $f->score,
    bp            => "$start-$end",
    ext_url       => $ext_url
  }); 
}

sub export_feature {
  my ($self, $feature, $feature_type) = @_;
  
  my @label = $feature->can('display_label') ? split /\s*=\s*/, $feature->display_label : ();
  
  return $self->_render_text($feature, $feature_type, { 'headers' => [ $label[0] ], 'values' => [ $label[1] ] });
}

1;
