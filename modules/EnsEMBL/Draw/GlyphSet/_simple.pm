=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Draw::GlyphSet::_simple;

### Standard rendering of data from simple_feature table (or similar)

##################
# DEPRECATED!
##################

use strict;

use base qw(EnsEMBL::Draw::GlyphSet_simple);

sub features { 
  warn "############# DEPRECATED MODULE - USE GlyphSet::marker instead";
  warn "This module will be removed in release 82";
  my $self     = shift;
  my $call     = 'get_all_' . ($self->my_config('type') || 'SimpleFeatures'); 
  my $db_type       = $self->my_config('db');
  my @features = map @{$self->{'container'}->$call($_, undef, $db_type)||[]}, @{$self->my_config('logic_names')||[]};
  
  return \@features;
}

sub colour_key { return lc $_[1]->analysis->logic_name; }
sub _das_type  { return 'simple'; }

sub feature_label { my ($self, $f) = @_; return $f->display_id; }
sub render_normal {$_[0]->SUPER::render_normal(1);}
sub render_labels {$_[0]->SUPER::render_normal();}

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
