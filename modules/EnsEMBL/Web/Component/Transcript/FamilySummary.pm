package EnsEMBL::Web::Component::Transcript::FamilySummary;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  return undef;
}


sub content {
  my $self = shift;
  my $object = $self->object;

  my $families = $object->get_families;
  return unless %$families;

  my $html;
  foreach my $family_id (keys %$families) {
    my $family_count = $families->{$family_id}{'count'};
    my $family_desc  = $families->{$family_id}{'description'};
    $html .= qq(<h3>$family_id</h3>
      <p><strong>Concensus annotation</strong>: $family_desc</p>
      <p><strong>Prediction method</strong>: Protein families were generated using the MCL (Markov CLustering)
    package available at <a href="http://micans.org/mcl/">http://micans.org/mcl/</a>.
    The application of MCL to biological graphs was initially proposed by Enright A.J.,
    Van Dongen S. and Ouzounis C.A. (2002) "An efficient algorithm for large-scale
    detection of protein families." Nucl. Acids. Res. 30, 1575-1584.</p>

      <h4>Ensembl genes containing peptides in this family</h4>);

      if (@{$object->species_defs->ENSEMBL_CHROMOSOMES}) {
        my $image = $self->_karyotype_map($family_id, $families->{$family_id}{'genes'});
        $html .= $image->render if $image;
      }
  }   

 return $html;
}

sub _karyotype_map {
  my ($self, $family_id, $genes) = @_;
  return unless $genes && ref($genes) eq 'ARRAY' && @$genes;
  my $object = $self->object;
  $object->param('aggregate_colour', 'red');

  my $species = $object->species;
  my $karyotype = undef;
  my $gene = $object->gene;

  my $image    = $object->new_karyotype_image();
  $image->cacheable  = 'yes';
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
      } else {
        $high{$chr} = [ $point ];
      }
    }
    $image->karyotype( $object, [ \%high ]);
  }
  return $image;
}

1;

