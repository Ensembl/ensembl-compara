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

package EnsEMBL::Web::ZMenu::Gene;

use strict;

use EnsEMBL::Web::ZMenu::Transcript;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  my $hub    = $self->hub;
  my $collapsed = ($hub->param('display') && $hub->param('display') eq 'collapsed');
  
  if ($self->click_location && !$collapsed) {
    my $object = $self->object;
    push @{$self->{'features'}}, @{EnsEMBL::Web::ZMenu::Transcript->new($hub, $self->new_object('Transcript', $_, $object->__data))->{'features'}} for @{$object->Obj->get_all_Transcripts};
  } else {
    my @genes = split(/,/, $hub->param('g'));
    return scalar @genes > 1 ? $self->_multi_genes_content : $self->_content;
  }
}

sub _content {
  my $self        = shift;
  my $hub         = $self->hub;
  my $object      = $self->object || $hub->core_object('gene') || $hub->create_object('gene');
  return unless $object;
  my @xref        = $object->display_xref;
  my $gene_desc   = $object->gene_description =~ s/No description//r =~ s/\[.+\]\s*$//r;
  
  $self->caption($xref[0] ? "$xref[3]: $xref[0]" : 'Gene');
  
  if($gene_desc) {
    $self->add_entry({
      type  => 'Gene Symbol',
      label => $gene_desc
    });
  }
  
  $self->add_entry({
    type  => 'Gene ID',
    label => $object->stable_id,
    link  => $hub->url({ type => 'Gene', action => 'Summary' })
  });

  
  $self->add_entry({
    type  => 'Location',
    label => sprintf(
      '%s: %s-%s',
      $self->neat_sr_name($object->seq_region_type, $object->seq_region_name),
      $self->thousandify($object->seq_region_start),
      $self->thousandify($object->seq_region_end)
    ),
    link_class => '_location_change _location_mark',
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

sub _multi_genes_content {
  # hack for ENSWEB-1706
  my $self  = shift;
  my $hub   = $self->hub;

  my @ids   = split ',', $hub->param('g');

  $self->caption('Multiple Genes:');

  for (@ids) {
    $self->add_entry({
      'label_html' => sprintf '<a href="%s" class="_zmenu">%s</a><a class="_zmenu_link" href="%s"></a>',
                        $hub->url({'type' => 'Gene', 'action' => 'Summary', 'g' => $_, '__clear' => 1}),
                        $_,
                        $hub->url('ZMenu', {'g' => $_, 'ftype' => $hub->param('ftype') || '', 'config' => $hub->param('config') || ''})
    });
  }
}

1;
