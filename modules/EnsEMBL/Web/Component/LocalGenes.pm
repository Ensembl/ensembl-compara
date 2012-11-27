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
  return $self->_info("A unique location can not be determined for this $label_msg\variation", $object->not_unique_location) if $object->not_unique_location;
  
  my %mappings = %{$object->variation_feature_mapping($hub->param('recalculate'))};

  return [] unless keys %mappings;

  my $source      = $object->source;
  my $name        = $object->name;
  my $html        = "<h2>Genes in this region</h2>
<p>The following genes in the region of this $label_msg\variant also have associated phenotype data:</p>";
 
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
    $html .= '<ul>';
    
    while (my ($stable_id, $data) = each %genes) {
      my $gene      = $data->{'gene'};
      my $dxr       = $gene->can('display_xref') ? $gene->display_xref : undef;
      my $gene_name = $dxr->display_id;
      my $text      = $gene_name ? "$gene_name ($stable_id)" : $stable_id;
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
      
      $html .= sprintf'<li><a href="%s">%s</a> (%s)</li>', $hub->url($params), $text, $data->{'position'};
    }

    $html .= '</ul>';

    return $html;
  } else { 
    return $self->_info('', "<p>This $label_msg\variation has not been mapped to any Ensembl genes.</p>");
  }
}

1;
