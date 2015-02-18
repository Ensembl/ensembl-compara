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

package EnsEMBL::Web::ZMenu::Gene;

use strict;

use EnsEMBL::Web::ZMenu::Transcript;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  
  if ($self->click_location) {
    my $hub    = $self->hub;
    my $object = $self->object;
    
    push @{$self->{'features'}}, @{EnsEMBL::Web::ZMenu::Transcript->new($hub, $self->new_object('Transcript', $_, $object->__data))->{'features'}} for @{$object->Obj->get_all_Transcripts};
  } else {
    return $self->_content;
  }
}

sub _content {
  my $self        = shift;
  my $hub         = $self->hub;
  my $object      = $self->object;
  my @xref        = $object->display_xref;
  my $gene_desc   = $object->gene_description =~ s/No description//r =~ s/\[.+\]\s*$//r;
  
  $self->caption($xref[0] ? "$xref[3]: $xref[0]" : 'Novel transcript');
  
  if($gene_desc) {
    $self->add_entry({
      type  => 'Gene',
      label => $gene_desc
    });
    
    $self->add_entry({
      type  => ' ',
      label => $object->stable_id,
      link  => $hub->url({ type => 'Gene', action => 'Summary' })
    }); 
  } else {
    $self->add_entry({
      type  => 'Gene',
      label => $object->stable_id,
      link  => $hub->url({ type => 'Gene', action => 'Summary' })
    });     
  }
  
  $self->add_entry({
    type  => 'Location',
    label => sprintf(
      '%s: %s-%s',
      $self->neat_sr_name($object->seq_region_type, $object->seq_region_name),
      $self->thousandify($object->seq_region_start),
      $self->thousandify($object->seq_region_end)
    ),
    link  => $hub->url({
      type   => 'Location',
      action => 'View',
      r      => $object->seq_region_name . ':' . $object->seq_region_start . '-' . $object->seq_region_end
    })
  });
  
  $self->add_entry({
    type  => 'Gene type',
    label => $object->gene_type
  });
  
  $self->add_entry({
    type  => 'Strand',
    label => $object->seq_region_strand < 0 ? 'Reverse' : 'Forward'
  });
  
  if ($object->analysis) {
    my $label = $object->analysis->display_label . ' Gene';
    $self->add_entry({
      type  => 'Analysis',
      label => $label
    });    
  }

  my $alt_allele_link = $object->get_alt_allele_link('Location');
  $self->add_entry({
                    'type'       => 'Gene alleles',
                    'label_html' => $alt_allele_link,
                  }) 
    if $alt_allele_link;
  
}

1;
