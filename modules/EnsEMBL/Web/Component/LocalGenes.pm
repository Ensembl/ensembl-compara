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

package EnsEMBL::Web::Component::LocalGenes;

use strict;

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self   = shift;
  my $hub    = $self->hub;
  my $object = $self->object;


  my ($feature_id,$label,$label_msg);
  if ($object->Obj->isa('Bio::EnsEMBL::Variation::Variation')) {
    $feature_id = $hub->param('vf');
    $label = 'Variation';
  } 
  elsif ($object->Obj->isa('Bio::EnsEMBL::Variation::StructuralVariation')) {
    $feature_id = $hub->param('svf');
    $label = 'StructuralVariation'; 
    $label_msg = 'structural ';
  }
  
  # first check we have uniquely determined variation
  return $self->_info("A unique location can not be determined for this $label_msg\variant", $object->not_unique_location) if $object->not_unique_location;
  
  my %mappings = %{$object->variation_feature_mapping($hub->param('recalculate'))};

  return [] unless keys %mappings;

  my $source = $object->source_name;
  my $name   = $object->name;
  my $html   = "<br />\n<h2>Genes in this region</h2>
<p>The following gene(s) in the region of this $label_msg\variant might have associated phenotype data:</p>";
 
  my $slice_adaptor = $hub->get_adaptor('get_SliceAdaptor');
  my $gene_adaptor  = $hub->get_adaptor('get_GeneAdaptor');
  my %genes;
  
  ## Get unique genes - select a good transcript for this each gene (not LRG unless that's all there is)
  foreach my $feature (grep $_ eq $feature_id, keys %mappings) {
    
    my $type   = $mappings{$feature}{Type};
    my $region = $mappings{$feature}{Chr};
    my $start  = $mappings{$feature}{start};
    my $end    = $mappings{$feature}{end};
    my $strand = $mappings{$feature}{strand}; 
    
    my $slice = $slice_adaptor->fetch_by_region($type, $region, $start, $end, $strand);
    
    foreach my $transcript (@{$slice->get_all_Transcripts}) {
    
      my $trans_name = $transcript->stable_id;
      
      my $gene = $gene_adaptor->fetch_by_transcript_stable_id($trans_name); 
      next unless $gene;
      next if $genes{$gene->stable_id};

      my $position = 'Overlaps variant';
      if ($gene->end < $mappings{$feature}{'start'}) { 
        $position = "Upstream from $label_msg\variant";
      }
      elsif ($gene->start > $mappings{$feature}{'end'}){
        $position = "Downstream from $label_msg\variant";
      }
      my $data = { 'gene'      => $gene,
                   'position'  => $position,
                 };

      if ($trans_name =~ /^LRG/) {
        $data->{'LRG'} = 1;
        $genes{$gene->stable_id} = $data;
      }
      else {
        $data->{'LRG'} = 0;
        $genes{$gene->stable_id} = $data;
        last;
      }
    }
  }
  
  if (keys %genes) {
    
    my $table = $self->new_table([], [], { data_table => 1 });
    my @data_row;

    $table->add_columns(
      { key => 'gene', title => 'Gene',      align => 'left', sort => 'html' },
      { key => 'hgnc', title => 'HGNC name', align => 'left', sort => 'html' },  
      { key => 'pos',  title => 'Position',  align => 'left', sort => 'html' },
    );
    
    while (my ($stable_id, $data) = each %genes) {
      my $gene      = $data->{'gene'};
      my $dxr       = $gene->can('display_xref') ? $gene->display_xref : undef;
      my $gene_name = $dxr && $dxr->display_id || '-';
      my $params    = {
        db     => 'core',
        r      => undef,
        v      => $name,
        source => $source,
      };

      if ($data->{'LRG'}) {
        $params->{'type'}   = 'LRG';
        $params->{'action'} = 'Variation_LRG/Table';
        $params->{'lrg'}    = $stable_id;
      } else {
        $params->{'type'}   = 'Gene';
        $params->{'action'} = 'Phenotype';
        $params->{'g'}      = $stable_id;
      }
      
      my $row = {
        gene  => sprintf ('<a href="%s">%s</a> ', $hub->url($params), $stable_id),
        hgnc  => $gene_name,
        pos   => $data->{'position'}
      };
      push @data_row, $row;
    }

    $table->add_rows(@data_row);
    
    return $html.$table->render;
  } else { 
    return $self->_info('', "<p>This $label_msg\variant has not been mapped to any Ensembl genes.</p>");
  }
}

1;
