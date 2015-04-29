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

package EnsEMBL::Web::Component::DAS::Annotation;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Component::DAS);

sub features {
  my $self     = shift;
  my $object   = $self->object;
  my $features = $object->Features;
  my $url      = $object->species_defs->ENSEMBL_BASE_URL . encode_entities($ENV{'REQUEST_URI'});
  my $xml      = qq{<GFF href="$url" version="1.0">};

  my $feature_template = qq{
  <FEATURE id="%s"%s>
    <START>%d</START>
    <END>%d</END>
    <TYPE id="%s"%s>%s</TYPE>
    <METHOD id="%s">%s</METHOD>
    <SCORE>%s</SCORE>
    <ORIENTATION>%s</ORIENTATION>%s
  </FEATURE>};
  
  foreach my $segment (@{$features || []}) {
    if ($segment->{'TYPE'} && $segment->{'TYPE'} eq 'ERROR') {
      $xml .= qq{\n<ERRORSEGMENT id="$segment->{'REGION'}" start="$segment->{'START'}" stop="$segment->{'STOP'}" />};
      next;
    }
    
    $xml .= sprintf qq{\n<SEGMENT id="$segment->{'REGION'}" start="$segment->{'START'}" stop="$segment->{'STOP'}">};
    
    foreach my $feature (@{$segment->{'FEATURES'} || []}) {
      my $extra_tags;

      foreach my $g (@{$feature->{'GROUP'}||[]}) {
        $extra_tags .= sprintf qq{\n    <GROUP id="$g->{'ID'}"%s%s>}, $g->{'TYPE'} ? qq{ type="$g->{'TYPE'}"} : '', $g->{'LABEL'} ? qq{ label="$g->{'LABEL'}"}  : '';
        $extra_tags .= sprintf qq{\n      <LINK href="%s">%s</LINK>}, encode_entities($_->{'href'}), encode_entities($_->{'text'} || $_->{'href'}) for @{$g->{'LINK'} || []};
        $extra_tags .= sprintf qq{\n      <NOTE>%s</NOTE>}, encode_entities($_) for @{$g->{'NOTE'} || []};
        $extra_tags .= "\n    </GROUP>";
      }
      
      $extra_tags .= sprintf qq{\n    <LINK href="%s">%s</LINK>}, encode_entities($_->{'href'}), encode_entities($_->{'text'} || $_->{'href'}) for @{$feature->{'LINK'} || []};
      $extra_tags .= sprintf qq{\n    <NOTE>%s</NOTE>}, encode_entities($_) for @{$feature->{'NOTE'} || []};
      $extra_tags .= sprintf qq{\n    <TARGET id="%s" start="$feature->{'TARGET'}{'START'}" stop="$feature->{'TARGET'}{'STOP'}" />}, encode_entities($feature->{'TARGET'}{'ID'}) if exists $feature->{'TARGET'};
      
      $xml .= sprintf($feature_template, 
        $feature->{'ID'}          || '',
        exists $feature->{'LABEL'} ? qq{ label="$feature->{'LABEL'}"} : '',
        $feature->{'START'}       || '',
        $feature->{'END'}         || '',
        $feature->{'TYPE'}        || '',
        $feature->{'CATEGORY'}     ? qq{ category="$feature->{'CATEGORY'}"} : '',
        $feature->{'TYPE'}        || '',
        $feature->{'METHOD'}      || '',
        $feature->{'METHOD'}      || '',
        $feature->{'SCORE'}       || '-',
        $feature->{'ORIENTATION'} || '.',
        $extra_tags
      );
    }
    
    $xml .= "\n</SEGMENT>";
  }
  
  $xml .= "\n</GFF>\n";
  
  return $xml;
}

1;
