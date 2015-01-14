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

package EnsEMBL::Draw::GlyphSet::assemblyexception;

### Draw assembly exception track - patches, haplotypes, etc
### - on the Location Summary image (horizontal chromosome)

use strict;

use Bio::EnsEMBL::AssemblyExceptionFeature;
use Bio::EnsEMBL::Mapper::RangeRegistry;

use base qw(EnsEMBL::Draw::GlyphSet_simple);

sub readable_strand { return $_[1] < 0 ? 'rev' : 'fwd'; }
sub my_label        { return undef; }

sub colour_key {
  my ($self, $f) = @_;
  (my $key = lc $f->type) =~ s/ /_/g;
  return $key;
}

sub features {
  my $self = shift;
  
  if (!$self->{'features'}) {
    my $all_features = $self->{'container'}->get_all_AssemblyExceptionFeatures;
    
    return $self->{'features'} = $all_features if $self->{'display'} eq 'normal';
    
    my $range = Bio::EnsEMBL::Mapper::RangeRegistry->new;
    my $i     = 0;
    my (%features, %order);
    
    foreach (@$all_features) {
      my $type    = $_->type;
      my ($s, $e) = ($_->start, $_->end);
      
      $range->check_and_register($type, $s, $e, $s, $e);
      
      push @{$features{$type}}, $_;
      $order{$type} ||= $i++;
    }
    
    # Make fake features that cover the entire range of overlapping AssemblyExceptionFeatures of the same type
    foreach my $type (sort { $order{$a} <=> $order{$b} } keys %order) {
      foreach my $r (@{$range->get_ranges($type)}) {
        my $f = Bio::EnsEMBL::AssemblyExceptionFeature->new(
          -start           => $r->[0],
          -end             => $r->[1],
          -strand          => $features{$type}[0]->strand,
          -slice           => $features{$type}[0]->slice,
          -alternate_slice => $features{$type}[0]->alternate_slice,
          -adaptor         => $features{$type}[0]->adaptor,
          -type            => $features{$type}[0]->type,
        );
        
        $f->{'__features'} = $features{$type};
        $f->{'__overlaps'} = scalar grep { $_->start >= $r->[0] && $_->end <= $r->[1] } @{$features{$type}};
        
        push @{$self->{'features'}}, $f;
      }
    }
    
    $self->{'features'} ||= [];
  }
  
  return $self->{'features'};
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

sub title {
  my ($self, $f) = @_;
  my $feature = $self->get_single_feature($f);
  my $title;
  
  foreach my $feat ($feature || @{$f->{'__features'}}) {
    my ($slice, $alternate_slice) = map $feat->$_, qw(slice alternate_slice);
  
    $title .= sprintf('%s; %s:%d-%d (%s); %s:%d-%d (%s)',
      $self->my_colour($self->colour_key($feat), 'text'),
      $slice->seq_region_name,
      $slice->start + $feat->start - 1,
      $slice->start + $feat->end   - 1,
      $self->readable_strand($slice->strand),
      $alternate_slice->seq_region_name,
      $alternate_slice->start,
      $alternate_slice->end,
      $self->readable_strand($alternate_slice->strand)
    );
  }
  
  return $title;
}

sub href {
  my ($self, $f) = @_;
  my $feature = $self->get_single_feature($f);
     $f       = $feature if $feature;
  my $slice   = $feature ? $feature->alternate_slice : undef;
 
  my $start = $f->start+$self->{'container'}->start-1; 
  my $end = $f->end+$self->{'container'}->start-1; 
  return $self->_url({
    species     => $f->species,
    action      => 'AssemblyException',
    feature     => $slice   ? sprintf('%s:%s-%s', $slice->seq_region_name, $slice->start, $slice->end) : undef,
    range       => $feature ? undef : sprintf('%s:%s-%s', $f->seq_region_name, $start, $end),
    target      => $f->slice->seq_region_name,
    target_type => $f->type,
    dbID        => $f->dbID,
  });
}

sub tag {
  my ($self, $f) = @_;
  
  return {
    style  => 'join',
    tag    => sprintf('%s:%s-%s', $f->alternate_slice->seq_region_name, $f->start, $f->end),
    colour => $self->my_colour($self->colour_key($f), 'join'),
    zindex => -20
  };
}

sub render_text {
  my $self = shift;
  $self->{'display'} = 'normal';
  return $self->SUPER::render_text(@_);
}

sub export_feature {
  my $self = shift;
  my ($feature, $feature_type) = @_;
  
  return $self->_render_text($feature, $feature_type, { 
    headers => [ 'alternate_slice' ],
    values  => [ $feature->alternate_slice->seq_region_name ]
  });
}

1;
