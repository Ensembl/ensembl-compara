package EnsEMBL::Web::Component::Location::SyntenyImage;

### Module to replace part of the former SyntenyView, in this case displaying 
### an image of the syntenous chromosome regions 

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);
use Data::Dumper;

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $species = $object->species;
    
  my %synteny = $object->species_defs->multi('SYNTENY');
  my $other = $object->param('otherspecies') || $object->param('species') || $self->default_otherspecies;
 
  my $chr = $object->seq_region_name;
  my %chr_1  =  map { ($_,1) } @{$object->species_defs->ENSEMBL_CHROMOSOMES||[]};
  my $chr_2 = scalar  @{$object->species_defs->other_species( $other , 'ENSEMBL_CHROMOSOMES' ) };
        
  unless ($synteny{ $other }){
    $object->problem('fatal', "Can't display synteny",  "There is no synteny data for these two species ($species and $other)") ;
    return undef;
  }
  unless ( $chr_1{$chr} && $chr_2>0){
    $object->problem( 'fatal', "Unable to display", "Synteny view only displays synteny between real chromosomes - not fragments") ;
    return undef;
  }

  my $ka  = $object->get_adaptor('get_KaryotypeBandAdaptor', 'core', $species);
  my $ka2 = $object->get_adaptor('get_KaryotypeBandAdaptor', 'core', $other);
  my $compara_db = $object->database('compara');
  my $raw_data = $object->chromosome->get_all_compara_Syntenies($other, undef, $compara_db);   

  ## checks done ## 
  my $chr_length = $object->chromosome->length;
  my ($localgenes,$offset) = $object->get_synteny_local_genes;
  my $loc = ( @$localgenes ? $localgenes->[0]->start + $object->seq_region_start : 1 ); # Jump loc to the location of the genes
        
  my $Config = $object->get_imageconfig( 'Vsynteny' );
  $Config->{'other_species_installed'} = $synteny{ $other };
  $Config->container_width( $chr_length );

  my $image = $object->new_vimage(
    {   'chr'           => $chr,
        'ka_main'       => $ka,
        'sa_main'       => $object->get_adaptor('get_SliceAdaptor'),
        'ka_secondary'  => $ka2,
        'sa_secondary'  => $object->get_adaptor('get_SliceAdaptor', 'core', $other),
        'synteny'       => $raw_data,
        'other_species' => $other,
        'line'          => $loc
    }, 
    $Config
  );
  $image->imagemap           = 'yes';
  $image->image_type         = 'syntenyview';
  $image->image_name         = $species.'-'.$chr.'-'.$other;
  $image->set_button( 'drag', 'title' => 'Click or drag to change region' );

  foreach my $o (@$raw_data) { ## prevents memory leak!
    $o->release_tree;
  }
  return $image->render;
}

1;
