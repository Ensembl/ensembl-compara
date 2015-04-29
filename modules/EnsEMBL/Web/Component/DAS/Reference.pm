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

package EnsEMBL::Web::Component::DAS::Reference;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Component::DAS);

sub entry_points {
  my $self     = shift;
  my $object   = $self->object;
  my $features = $object->EntryPoints;
  my $url      = $object->species_defs->ENSEMBL_BASE_URL . encode_entities($ENV{'REQUEST_URI'});
  my $template = qq{<SEGMENT id="%s" start="%s" stop="%s" orientation="%s">%s</SEGMENT>\n};
  my $xml      = qq{<ENTRY_POINTS href="$url" version="1.0">};
  $xml        .= sprintf $template, @$_ for @{$features || []};
  $xml        .= "</ENTRY_POINTS>\n";
  
  return $xml;
}

sub dna {
  my $self     = shift;
  my $object   = $self->object;
  my $features = $object->DNA;
  my $xml;

  foreach my $segment (@{$features || []}) {    
    if ($segment->{'TYPE'} && $segment->{'TYPE'} eq 'ERROR') {
      $xml .= qq{<ERRORSEGMENT id="$segment->{'REGION'}" start="$segment->{'START'}" stop="$segment->{'STOP'}" />\n};
      next;
    }
    
    $xml .= qq{<SEQUENCE id="$segment->{'REGION'}" start="$segment->{'START'}" stop="$segment->{'STOP'}" version="1.0">\n};
    $xml .= sprintf qq{<DNA length="%d">\n}, $segment->{'STOP'} - $segment->{'START'} + 1; 
    $xml .= $self->get_sequence($segment);
    $xml .= "</DNA>\n</SEQUENCE>\n";
  }
  
  return $xml;
}

sub sequence {
  my $self     = shift;
  my $object   = $self->object;
  my $features = $object->DNA;
  my $xml;
  
  foreach my $segment (@{$features || []}) {
    if ($segment->{'TYPE'} && $segment->{'TYPE'} eq 'ERROR') {
      $xml .= qq{<ERRORSEGMENT id="$segment->{'REGION'}" start="$segment->{'START'}" stop="$segment->{'STOP'}" />\n};
      next;
    }
    
    $xml .= qq{<SEQUENCE id="$segment->{'REGION'}" start="$segment->{'START'}" stop="$segment->{'STOP'}" version="1.0">\n};
    $xml .= $self->get_sequence($segment);
    $xml .= "</SEQUENCE>\n";
  }
  
  return $xml;
}

sub get_sequence {
  my $self        = shift;
  my $segment     = shift;
  my $object      = $self->object;
  my $block_start = $segment->{'START'};
  my $sequence;
  
  while ($block_start <= $segment->{'STOP'}) {
    my $block_end = $block_start - 1 + 600000; # do in 600K chunks to simplify memory usage
    $block_end    = $segment->{'STOP'} if $block_end > $segment->{'STOP'};
    
    my $slice = $object->subslice($segment->{'REGION'}, $block_start, $block_end);
    my $seq   = $slice->seq;
    $seq      =~ s/(.{60})/$1\n/g;
    
    $sequence .= lc $seq;
    $sequence .= "\n" unless $seq =~ /\n$/;
    
    $block_start = $block_end + 1;
  }
  
  return $sequence;
}

1;
