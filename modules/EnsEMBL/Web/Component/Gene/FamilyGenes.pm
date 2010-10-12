# $Id$

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

  if ($family_id) {
    my $families = $object->get_all_families($cdb);
    my $genes    = $families->{$family_id}{'info'}{'genes'} || [];
    $html       .= "<h4>Ensembl genes containing proteins in family $family_id</h4>\n";

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
      
      foreach my $g (@$genes) {
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

    if (@$genes) {
      ## Table of gene info
      my $table = $self->new_table([], [], { margin => '1em 0px' });
      
      $table->add_columns(
        { key => 'id',   title => 'Gene ID and Location',  width => '30%', align => 'center' },
        { key => 'name', title => 'Gene Name',             width => '20%', align => 'center' },
        { key => 'desc', title => 'Description(if known)', width => '50%', align => 'left'   }
      );
      
      foreach my $gene (sort { $object->seq_region_sort($a->seq_region_name, $b->seq_region_name) || $a->seq_region_start <=> $b->seq_region_start } @$genes) {
        my $row = {};
        $row->{'id'} = sprintf(
          '<a href="%s/Gene/Summary?g=%s" title="More about this gene">%s</a><br /><a href="%s/Location/View?r=%s:%s-%s" title="View this location on the genome" class="small" style="text-decoration:none">%s: %s</a>',
          $spath, $gene->stable_id, $gene->stable_id,
          $spath, $gene->slice->seq_region_name, $gene->start, $gene->end,
          $self->neat_sr_name($gene->slice->coord_system->name, $gene->slice->seq_region_name), 
          $self->round_bp($gene->start)
        );
        
        my $xref = $gene->display_xref;
        
        if ($xref) {
          $row->{'name'} = $hub->get_ExtURL_link($xref->display_id, $xref->dbname, $xref->primary_id);
        } else {
          $row->{'name'} = '-novel-';
        }
        
        $row->{'desc'} = $object->gene_description($gene);
        $table->add_row($row);
      }
      
      $html .= $table->render;
    }
  }
  
  return $html;
}

1;
