=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet::assemblyexception;

### Draw assembly exception track - patches, haplotypes, etc
### - on the Location Summary image (horizontal chromosome)

use strict;

use Bio::EnsEMBL::AssemblyExceptionFeature;
use Bio::EnsEMBL::Mapper::RangeRegistry;

use base qw(EnsEMBL::Draw::GlyphSet_simpler);

sub readable_strand { return $_[1] < 0 ? 'rev' : 'fwd'; }
sub my_label        { return undef; }

sub colour_key {
  my ($self, $f) = @_;
  (my $key = lc $f->type) =~ s/ /_/g;
  return $key;
}

sub features {
  my $self = shift;

  my $hub = $self->{'config'}{'hub'};
  return $hub->get_query('GlyphSet::AssemblyException')->go($self,{
    slice => $self->{'container'},
    species => $self->{'config'}{'species'},
  });
}

sub get_single_feature {
  my ($self, $f) = @_;
  
  if (!defined $self->{'single_features'}{$f}) {
    my $features = $f->{'__features'};
    my $feature;
    
    if ($features) {
      my ($s, $e) = map $f->$_, qw(start end);
      $features = [ grep $_->start == $s && $_->end == $e, @$features ];
      $feature  = scalar @$features == 1 ? $features->[0] : '';
    } else {
      $feature = $f;
    }
    
    $self->{'single_features'}{$f} = $feature;
  }
  
  return $self->{'single_features'}{$f};
}

sub feature_label {
  my ($self, $f) = @_;
  
  return '' if $self->{'display'} eq 'collapsed';
  
  my $feature = $self->get_single_feature($f);
  
  if (!$feature) {
    my $label  = $self->my_colour($self->colour_key($f), 'text');
       $label  =~ s/( \(ref\))$//;
    my $ref    = $1;
       $label .= $label =~ /(patch|fix)$/ ? 'es' : 's';
    
    return "$f->{'__overlaps'} $label$ref";
  }
  
  my $alternate_slice = $feature->alternate_slice;
  
  return $alternate_slice->seq_region_name if $self->my_config('short_labels');
  
  return sprintf(
    '%s: %s:%d-%d (%s)',
    $self->my_colour($self->colour_key($feature), 'text'),
    $alternate_slice->seq_region_name,
    $alternate_slice->start,
    $alternate_slice->end,
    $self->readable_strand($alternate_slice->strand)
  );
}

sub render_text {
  my $self = shift;
  $self->{'display'} = 'normal';
  return $self->SUPER::render_text(@_);
}

# XXX keep for genoverse
sub tag { return @{$_[1]->{'tag'}||[]}; }

sub export_feature {
  my $self = shift;
  my ($feature, $feature_type) = @_;
  
  return $self->_render_text($feature, $feature_type, { 
    headers => [ 'alternate_slice' ],
    values  => [ $feature->alternate_slice->seq_region_name ]
  });
}

1;
