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

package EnsEMBL::Web::Component::Gene::Alleles;

use strict;
use warnings;
use EnsEMBL::Web::Document::Table;

no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub content {
  my $self = shift;
  my $hub  = $self->hub;
  my $this_species = $hub->species;
  my $alleles = $self->object->get_alt_alleles;

  my $html;
  if (@$alleles) {
    my $table = EnsEMBL::Web::Document::Table->new([], [], { data_table => 1, sorting => [ 'id asc' ], exportable => 0 });  
    $table->add_columns(
      { key => 'chromosome',  title => 'Chromosome',  align => 'left', sort => 'string', width => '15%' },
      { key => 'id',      title => 'Stable ID',       align => 'left', sort => 'string', width => '25%' },
      { key => 'location',title => 'Location',        align => 'left', sort => 'position_html', width => '20%'  },
      { key => 'strand',  title => 'Strand',          align => 'left', sort => 'string', width => '10%' } ,
      { key => 'compare', title => 'Compare',         align => 'left', sort => 'none', width => '25%'  },
    );    

    my ($all_alleles,$c);
    foreach my $allele(sort { $a->seq_region_name cmp $b->seq_region_name } @$alleles) {
      my $allele_id       = $allele->stable_id;
      my $seq_region_name = $allele->seq_region_name;
      my $strand          =  $allele->seq_region_strand < 0 ? 'Reverse' : 'Forward';
      my $display_label   = $allele->display_xref->display_id;
      my $description = $allele->description || "";

      $c++;
      $all_alleles->{'g'.$c} = $allele_id;
      $all_alleles->{'s'.$c} = $this_species.'--'.$seq_region_name;
      my $loc_link = $hub->url({
	                              'type'   => 'Location',
	                              'action' => 'View',
	                              'r'      => $allele->seq_region_name.':'.$allele->seq_region_start.'-'.$allele->seq_region_end
      });
      my $loc_html = sprintf( qq(<a href="%s">%s: %s-%s</a>),
				   $loc_link,
				   $allele->seq_region_name,
				   $self->thousandify( $allele->seq_region_start ),
				   $self->thousandify( $allele->seq_region_end ),
				   $allele->seq_region_strand < 0 ? ' reverse strand' : 'forward strand'
				 );
      my $gene_summary_link = sprintf(
	qq(<a href="%s">%s</a><br />$display_label<br /><span class="small">$description</span>),
	$hub->url({
	  type   => 'Gene',
	  action => 'Summary',
	  g      => "$allele_id",
	}),
	$allele_id
      );
      my $mcv_link = sprintf(
	qq(<ul class="compact"> <li class="first"><a class="no text" href="%s">Region Comparison</a></li></ul>),
	$hub->url({
	  type   => 'Location',
	  action => 'Multi',
	  g1     => $allele_id,
	  s1     => $this_species.'--'.$seq_region_name,
	  r      => undef,
          config => 'opt_join_genes_bottom=on',
	}),
      );

      $table->add_row({
        chromosome => $allele->seq_region_name,
        id         => $gene_summary_link,
        compare    => $mcv_link,
	      location   => $loc_html,
        exref      => $display_label . "<br><span class=\"small\">".$description."</span>",
	      strand     => $strand
      });

    }
    $html .= q(</table>);

    $all_alleles->{'type'} = 'Location';
    $all_alleles->{'action'} = 'Multi';
    $all_alleles->{'r'} = undef;

    $html='<p>Genes are annotated on alternate sequences (haplotypes and patches) in addition to the primary genome assembly. These are shown in the table below:</p>'. $table->render;
    my $all_gene_link = $hub->url($all_alleles);
    $html .= qq(<a href="$all_gene_link">Compare regions for all gene alleles</a>) if $c > 2;
  }
  else {
    $html = 'No alleles have been curated for this gene';
  }
  return $html;
}

1;


