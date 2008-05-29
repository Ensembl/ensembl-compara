package EnsEMBL::Web::Component::Transcript::FamilyGenes;

### Displays information about all genes belonging to a protein family

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);
use CGI qw(escapeHTML);
sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $species = $object->species;
  my $family_id = $object->param('family');

  my $html = undef;
  if ($family_id && @{$object->species_defs->ENSEMBL_CHROMOSOMES}) {

    $html .= "<h4>Ensembl genes containing peptides in family $family_id</h4>\n";

    my $families = $object->get_families;
    my $genes = $families->{$family_id}{'genes'};

    $object->param('aggregate_colour', 'red');
    my $karyotype = undef;
    my $gene = $object->gene;

    my $image    = $object->new_karyotype_image();
    $image->cacheable  = 'no';
    $image->image_type = "family";
    $image->image_name = "$species-".$family_id;
    $image->imagemap = 'yes';
    unless( $image->exists ) {
      my %high = ( 'style' => 'arrow' );
      foreach my $g (@$genes){
        my $stable_id = $g->stable_id;
        my $chr       = $g->slice->seq_region_name;
        my $start     = $g->start;
        my $end       = $g->end;
        my $colour = $stable_id eq $gene->stable_id ? 'red' : 'blue';
        my $point = {
            'start' => $start,
            'end'   => $end,
            'col'   => $colour,
            'zmenu' => {
            'caption'               => 'Genes',
            "00:$stable_id"         => "/$species/Gene/Summary?g=$stable_id",
            '01:Jump to contigview' => "/$species/Location/View?r=$chr:$start-$end;g=$stable_id"
          }
        };
        if(exists $high{$chr}) {
          push @{$high{$chr}}, $point;
        } 
        else {
          $high{$chr} = [ $point ];
        }
      }
      $image->karyotype( $object, [ \%high ]);
    }
    $html .= $image->render if $image;
  }

  return $html;
}

1;
