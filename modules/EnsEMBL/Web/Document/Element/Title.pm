=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Document::Element::Title;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Document::Element);

sub set       { $_[0]{'title'} = $_[1]; }
sub get       { return $_[0]{'title'};  }
sub set_short { $_[0]{'short'} = $_[1]; }
sub get_short { return $_[0]{'short'};  }

sub content {
  my $self  = shift;
  my $title = encode_entities($self->strip_HTML($self->get));
  return "<title>$title</title>\n";
}

sub init {
  my $self       = shift;
  my $controller = shift;
  
  if ($controller->request eq 'ssi') {
    $self->set($controller->content =~ /<title>(.*?)<\/title>/sm ? $1 : 'Untitled: ' . $controller->r->uri);
  } else {
    my $node = $controller->node;
    
    return unless $node;
    
    my $object       = $controller->object;
    my $hub          = $self->hub;
    my $species_defs = $hub->species_defs;
    my $title        = $node->data->{'title'} || $node->data->{'concise'} || $node->data->{'caption'};
       $title        =~ s/\s*\(.*\[\[.*\]\].*\)\s*//;
    my $caption;
    
    if ($object) {
      if (ref $object->caption eq 'ARRAY') {
        $caption  = $object->caption->[0];
        $caption .= ' (' . $object->caption->[1] . ')' if $object->caption->[1];
      } else {
        $caption = $object->caption;
      }
    }

    $self->set(sprintf '%s %s', join(' - ', grep $_, $caption, $title, $species_defs->SPECIES_URL, $species_defs->ENSEMBL_SITE_NAME), $species_defs->SITE_RELEASE_VERSION || $species_defs->ENSEMBL_VERSION);

    ## Short title to be used in the bookmark link
    if ($hub->user) {
      my $type = $hub->type;
    
      if ($type eq 'Location' && $caption =~ /: ([\d,-]+)/) {
        (my $strip_commas = $1) =~ s/,//g;
        $caption =~ s/: [\d,-]+/:$strip_commas/;
      }
      
      $caption =~ s/Chromosome //          if $type eq 'Location';
      $caption =~ s/Regulatory Feature: // if $type eq 'Regulation';
      $caption =~ s/$type: //;
      $caption =~ s/\(.+\)$//;
      
      $self->set_short(join ' - ', grep $_, $caption, $title, $species_defs->SPECIES_DISPLAY_NAME);
    }
  }
}

1;
