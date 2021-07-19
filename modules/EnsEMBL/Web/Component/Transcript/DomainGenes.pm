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

package EnsEMBL::Web::Component::Transcript::DomainGenes;

use strict;

use base qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub caption {
  my $self = shift;
  my $accession = $self->hub->param('domain');
  
  return "Other genes with domain $accession" if $accession;
}

sub content {
  my $self    = shift;
  my $hub     = $self->hub;
  my $species = $hub->species;
  
  return unless $hub->param('domain');
  
  my $object = $self->object;
  my $genes  = $object->get_domain_genes;
  
  return unless @$genes;
  
  my $html;

  ## Karyotype showing genes associated with this domain (optional)
  my $gene_stable_id = $object->gene ? $object->gene->stable_id : 'xx';
  
  if (@{$hub->species_defs->ENSEMBL_CHROMOSOMES}) {
    $hub->param('aggregate_colour', 'red'); ## Fake CGI param - easiest way to pass this parameter
    
    my $wuc   = $hub->get_imageconfig('Vkaryotype');
    my $image = $self->new_karyotype_image($wuc);
    
    $image->image_type = 'domain';
    $image->image_name = "$species-" . $hub->param('domain');
    $image->imagemap   = 'yes';
    
    my %high = ( style => 'arrow' );
    
    foreach my $gene (@$genes) {
      my $stable_id = $gene->stable_id;
      my $chr       = $gene->seq_region_name;
      my $colour    = $gene_stable_id eq $stable_id ? 'red' : 'blue';
      my $point     = {
        start => $gene->seq_region_start,
        end   => $gene->seq_region_end,
        col   => $colour,
        href  => $hub->url({ type => 'Gene', action => 'Summary', g => $stable_id })
      };
      
      if (exists $high{$chr}) {
        push @{$high{$chr}}, $point;
      } else {
        $high{$chr} = [ $point ];
      }
    }
    
    $image->set_button('drag');
    $image->karyotype($hub, $object, [ \%high ]);
    $html .= sprintf '<div style="margin-top:10px">%s</div>', $image->render;
  }

  ## Now do table
  my $table = $self->new_table([], [], { data_table => 1 });

  $table->add_columns(
    { key => 'id',   title => 'Gene',                   width => '15%', align => 'left' },
    { key => 'loc',  title => 'Genome Location',        width => '20%', align => 'left' },
    { key => 'name', title => 'Name',                   width => '10%', align => 'left' },
    { key => 'desc', title => 'Description (if known)', width => '55%', align => 'left' }
  );
  
  my $row_index = -1;
  foreach my $gene (sort { $object->seq_region_sort($a->seq_region_name, $b->seq_region_name) || $a->seq_region_start <=> $b->seq_region_start } @$genes) {
    # the result of the sorting is the same as sorting by Genome Location column in the data table on the client; so we want to preserve this sorting order in a data attribute of the 'loc' column
    $row_index += 1;
    my $row       = {};
    my $xref_id   = $gene->display_xref ? $gene->display_xref->display_id : '-';
    my $stable_id = $gene->stable_id;
    
    $row->{'id'} = sprintf '<a data-order="%s" href="%s">%s</a>', $stable_id, $hub->url({ type => 'Gene', action => 'Summary', g => $stable_id }), $stable_id;
    $row->{'name'} = $xref_id;
    my $readable_location = sprintf(
      '%s:%s-%s',
      $self->neat_sr_name($gene->slice->coord_system->name, $gene->slice->seq_region_name),
      $gene->start,
      $gene->end
    );
    
    my $url_for_gene_location = $hub->url({ type => 'Location', action => 'View', g => $stable_id, __clear => 1});
    my $gene_location_order_number = sprintf("%05d", $row_index); # pad index with up to 4 zeros to enable correct ordering by DataTable based on string comparison
    $row->{'loc'}= sprintf '<a data-order="%s" href="%s">%s</a>', $gene_location_order_number, $url_for_gene_location, $readable_location;
    
    my %description_by_type = ( bacterial_contaminant => 'Probable bacterial contaminant' );
    
    $row->{'desc'} = $gene->description || $description_by_type{$gene->biotype} || 'No description';
    
    $table->add_row($row);
  }
  
  $html .= $table->render;

  return $html;
}

1;

