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

package EnsEMBL::Web::Query::GlyphSet::AssemblyException;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::Query::Generic::GlyphSet);

our $VERSION = 4;

sub precache {
  return {
    assemblyexceptions => {
      parts => 10,
      loop => ['species','genome'],
      args => {
      }
    }
  };
}

sub fixup {
  my ($self) = @_;

  $self->fixup_location('start','slice',0);
  $self->fixup_location('end','slice',1);
  $self->fixup_slice('slice','species',1000000000);
  $self->fixup_slice('alternate_slice','species');
  $self->fixup_href('href');
  $self->fixup_colour('colour');
  $self->fixup_colour('tag/*/colour',undef,'join');

  # Fix titles (They have text which depend on my_colour!)
  if($self->phase eq 'post_process') {
    my $data = $self->data;
    my $gs = $self->context;
    foreach my $f (@$data) {
      my $in = $self->{'title'};
      my $title = '';
      foreach my $e (@$in) {
        $title .= sprintf('%s; %s',$gs->my_colour($e->[0],'text'),$e->[1]);
      }
      $f->{'title'} = $title;
    }
  }

  $self->SUPER::fixup();
}

sub colour_key {
  my ($self, $f) = @_;
  if($f->can('type')) {
    (my $key = lc $f->type) =~ s/ /_/g;
    return $key;
  }
  (my $key = lc $f->{'type'}) =~ s/ /_/g;
  return $key;
}

sub tag {
  my ($self, $f) = @_; 
  
  return {
    style  => 'join',
    tag    => sprintf('%s:%s-%s', $f->alternate_slice->seq_region_name, $f->start, $f->end),
    colour => $self->colour_key($f),
    zindex => -20 
  };  
}

sub readable_strand { return $_[1] < 0 ? 'rev' : 'fwd'; }

sub get_single_feature {
  my ($self, $f) = @_;

  my $features = $f->{'__features'};
  my $feature;

  if ($features) {
    my ($s, $e) = map $f->$_, qw(start end);
    $features = [ grep $_->start == $s && $_->end == $e, @$features ];
    $feature  = scalar @$features == 1 ? $features->[0] : '';
  } else {
    $feature = $f;
  }
   
  return $feature;
}

#sub post_process_title {
#  my ($self,$gs,$key,$ff) = @_;
#
#  foreach my $f (@$ff) {
#    my $in = $self->{$key};
#    my $title = '';
#    foreach my $e (@$in) {
#      $title .= sprintf('%s; %s',$gs->my_colour($e->[0],'text'),$e->[1]);
#    }
#    $f->{$key} = $title;
#  }
#}

sub href {
  my ($self, $f, $args) = @_;
  my $feature = $self->get_single_feature($f);
     $f       = $feature if $feature;
  my $slice   = $feature ? $feature->alternate_slice : undef;
 
  my $start = $f->start+$args->{'slice'}->start-1;
  my $end = $f->end+$args->{'slice'}->start-1; 
  return {
    species     => $f->species,
    action      => 'AssemblyException',
    feature     => $slice   ? sprintf('%s:%s-%s', $slice->seq_region_name, $slice->start, $slice->end) : undef, 
    range       => $feature ? undef : sprintf('%s:%s-%s', $f->seq_region_name, $start, $end),       
    target      => $f->slice->seq_region_name,
    target_type => $f->type,
    dbID        => $f->dbID,
  };
}

sub title {
  my ($self, $f) = @_;
  my $feature = $self->get_single_feature($f);

  my @title;
  foreach my $feat ($feature || @{$f->{'__features'}}) {
    my ($slice, $alternate_slice) = map $feat->$_, qw(slice alternate_slice);
    push @title,[$self->colour_key($feat),
      sprintf('%s:%d-%d (%s); %s:%d-%d (%s)',
        $slice->seq_region_name,
        $slice->start + $feat->start - 1,
        $slice->start + $feat->end   - 1,
        $self->readable_strand($slice->strand),
        $alternate_slice->seq_region_name,
        $alternate_slice->start,
        $alternate_slice->end,
        $self->readable_strand($alternate_slice->strand)
      )
    ];
  }
 
  return \@title;
}

sub _plainify {
  my ($self,$f,$args) = @_;

  return {
    start => $f->start,
    end => $f->end,
    strand => $f->strand,
    tag => [$self->tag($f)],
    colour_key => $self->colour_key($f),
    colour => $self->colour_key($f),
    title => $self->title($f),
    href => $self->href($f,$args),
  };
}

sub get {
  my ($self,$args) = @_;

  my $all_features = $args->{'slice'}->get_all_AssemblyExceptionFeatures;
  
  if($self->{'display'}||'' eq 'normal') {
    return [map { $self->_plainify($_,$args) } @$all_features];
  }
  
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
  
  my @out; 
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
      
      push @out, $self->_plainify($f,$args);
    }     
  }     
  return \@out;
}

1;
