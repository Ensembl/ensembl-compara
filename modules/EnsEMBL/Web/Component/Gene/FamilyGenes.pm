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

package EnsEMBL::Web::Component::Gene::FamilyGenes;

### Displays information about all genes belonging to a protein family

use strict;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $cdb          = shift || $hub->param('cdb') || 'compara';
  my $object       = $self->object;
  my $species      = $hub->species;
  my $species_defs = $hub->species_defs;
  my $family_id    = $hub->param('family');
  my $spath        = $species_defs->species_path($species);
  my $html         = undef;
  my $ckey         = $cdb eq 'compara_pan_ensembl' ? '_pan_compara' : '';

  if ($family_id) {
    my $families = $object->get_all_families($cdb);
    my $genes    = $families->{$family_id}{'info'}{'genes'} || [];
    my $proteins = $families->{$family_id}{'info'}{'proteins'} || {};

    ## Dedupe results
    my %seen;
    foreach (@$genes) {
      next if $seen{$_->stable_id};
      $seen{$_->stable_id} = $_;
    }
    my @unique_genes = values %seen;

    my $url_fam  = $hub->url({ species => 'Multi', type => "Family$ckey", action => 'Details', fm => $family_id, __clear => 1 });
    $html       .= sprintf qq(<h4>Ensembl genes containing proteins in family <a href="%s">$family_id</a></h4>\n), $url_fam;

    ## Karyotype (optional)
    if (@{$species_defs->ENSEMBL_CHROMOSOMES}) {
      $hub->param('aggregate_colour', 'red'); ## Fake CGI param - easiest way to pass this parameter
      
      my $karyotype    = undef;
      my $current_gene = $hub->param('g') || '';
      my %high         = ( style => 'arrow' );
      my $image        = $self->new_karyotype_image;

      $image->image_type = 'family';
      $image->image_name = "$species-$family_id";
      $image->imagemap   = 'yes';
      $image->set_button('drag', 'title' => 'Click or drag to jump to a region');
      
      foreach my $g (@unique_genes) {
        my $stable_id = $g->stable_id;
        my $chr       = $g->slice->seq_region_name;
        my $start     = $g->start;
        my $end       = $g->end;
        my $colour    = $stable_id eq $current_gene ? 'red' : 'blue';
        my $point     = {
          start => $start,
          end   => $end,
          col   => $colour,
          zmenu => {
            'caption'               => 'Genes',
            "00:$stable_id"         => "$spath/Gene/Summary?g=$stable_id",
            '01:Jump to contigview' => "$spath/Location/View?r=$chr:$start-$end;g=$stable_id"
          }
        };
        
        if (exists $high{$chr}) {
          push @{$high{$chr}}, $point;
        } else {
          $high{$chr} = [ $point ];
        }
      }
      
      $image->karyotype($self->hub, $object, [ \%high ]);

      $html .= $image->render if $image;
    }

    if (@unique_genes) {
      ## Table of gene info
      my $table = $self->new_table;
      
      $table->add_columns(
        { key => 'id',   title => 'Gene ID and Location',   width => '20%'},
        { key => 'name', title => 'Gene Name',              width => '20%'},
        { key => 'desc', title => 'Description (if known)', width => '40%'},
        { key => 'prot', title => 'Protein ID(s)',          width => '20%'},
      );
     
      my %shown;
 
      foreach my $gene (sort { $object->seq_region_sort($a->seq_region_name, $b->seq_region_name) || $a->seq_region_start <=> $b->seq_region_start } @unique_genes) {

        my $row = {};

        $row->{'id'} = sprintf(
              '<a href="%s/Gene/Summary?g=%s" title="More about this gene">%s</a><br /><a href="%s/Location/View?r=%s:%s-%s" title="View this location on the genome" class="small nodeco">%s: %s</a>',
              $spath, $gene->stable_id, $gene->stable_id,
              $spath, $gene->slice->seq_region_name, $gene->start, $gene->end,
              $self->neat_sr_name($gene->slice->coord_system->name, $gene->slice->seq_region_name), 
              $self->round_bp($gene->start)
        );
        
        my $xref = $gene->display_xref;
        
        if ($xref) {
          $row->{'name'} = $hub->get_ExtURL_link($xref->display_id, $xref->dbname, $xref->primary_id);
        } 
        else {
          $row->{'name'} = '-novel-';
        }
        
        $row->{'desc'} = $object->gene_description($gene);
        
        foreach my $protein (@{$proteins->{$gene->stable_id}||[]}) {
          #$row->{'prot'} .= sprintf('<p>%s</p>', $protein->stable_id);
          $row->{'prot'} .= sprintf('<p><a href="%s/Transcript/ProteinSummary?p=%s" title="More about this protein">%s</a></p>', $spath, $protein->stable_id, $protein->stable_id);
        }

        $table->add_row($row);
      }
      
      $html .= $table->render;
    }
  }
  
  return $html;
}

1;
