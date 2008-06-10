package EnsEMBL::Web::Component::Location::SyntenyImage;

### Module to replace part of the former SyntenyView, in this case displaying 
### an image of the syntenous chromosome regions 

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);
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
    
  my $loc = $object->param('loc') ? $object->evaluate_bp($object->param('loc')) : undef ;
    
  my $other = $object->param('otherspecies')||$object->param('species') || ($species eq 'Homo_sapiens' ? 'Mus_musculus' : 'Homo_sapiens');
  my %synteny = $object->species_defs->multi('SYNTENY');
  my $chr = $object->seq_region_name;
  my %chr_1  =  map { ($_,1) } @{$object->species_defs->ENSEMBL_CHROMOSOMES||[]};
  my $chr_2 = scalar  @{$object->species_defs->other_species( $other , 'ENSEMBL_CHROMOSOMES' ) };
        
  unless ($synteny{ $other }){
    $object->problem('fatal', "Can't display synteny",  "There is no synteny data for these two species ($species and $other)") ;
    return undef;
  }
  unless ( $chr_1{$chr} && $chr_2>0){
    $object->problem( 'fatal', "Unable to display", "SyntenyView only displays synteny between real chromosomes - not fragments") ;
    return undef;
  }

  my $ka  = $object->get_adaptor('get_KaryotypeBandAdaptor', 'core', $species);
  my $ka2 = $object->get_adaptor('get_KaryotypeBandAdaptor', 'core', $other);
  my $raw_data = $object->Obj->get_all_compara_Syntenies($other);   

warn "#### Got data $raw_data";

  ## checks done ## 
  my $chr_length = $object->length;
  my ($localgenes,$offset) = $object->get_synteny_local_genes;
  $loc = ( @$localgenes ? $localgenes->[0]->start+$offset : 1 ); # Jump loc to the location of the genes
        
  my $Config = $object->get_userconfig( 'Vsynteny' );
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
  # $image->cacheable          = 'yes';
  $image->image_type         = 'syntenyview';
  $image->image_name         = $species.'-'.$chr.'-'.$other;

  #$panel->add_image( $image->render, $image->{'width'} );
  foreach my $o (@$raw_data) { ## prevents memory leak!
    $o->release_tree;
  }
  return $image->render;
}

1;
