package EnsEMBL::Web::Object::Location;

use strict;
use warnings;
no warnings "uninitialized";
use Data::Dumper;

use EnsEMBL::Web::Object;
use EnsEMBL::Web::Proxy::Factory;
our @ISA = qw(EnsEMBL::Web::Object);
use POSIX qw(floor ceil);

sub centrepoint      { return ( $_[0]->Obj->{'seq_region_end'} + $_[0]->Obj->{'seq_region_start'} ) / 2; }
sub length           { return $_[0]->Obj->{'seq_region_end'} - $_[0]->Obj->{'seq_region_start'} + 1; }

sub slice            {
  my $self = shift;
  return $self->Obj->{'slice'} ||= $self->database('core',$self->real_species)->get_SliceAdaptor->fetch_by_region(
    $self->seq_region_type, $self->seq_region_name, $self->seq_region_start, $self->seq_region_end, $self->seq_region_strand );
}

sub alternative_object_from_factory {
  my( $self,$type ) =@_;
  my $t_fact = EnsEMBL::Web::Proxy::Factory->new( $type, $self->__data );
  if( $t_fact->can( 'createObjects' ) ) {
    $t_fact->createObjects;
    $self->__data->{lc($type)} = $t_fact->DataObjects;
    $self->__data->{'objects'} = $t_fact->__data->{'objects'};
  }
}

sub get_snp { return $_[0]->__data->{'snp'}[0] if $_[0]->__data->{'snp'}; }

sub attach_slice       { $_[0]->Obj->{'slice'} = $_[1];              }
sub real_species       :lvalue { $_[0]->Obj->{'real_species'};       }
sub raw_feature_strand :lvalue { $_[0]->Obj->{'raw_feature_strand'}; }
sub strand             :lvalue { $_[0]->Obj->{'strand'};             }
sub name               :lvalue { $_[0]->Obj->{'name'};               }
sub type               :lvalue { $_[0]->Obj->{'type'};               }
sub synonym            :lvalue { $_[0]->Obj->{'synonym'};            }
sub seq_region_name    :lvalue { $_[0]->Obj->{'seq_region_name'};    }
sub seq_region_start   :lvalue { $_[0]->Obj->{'seq_region_start'};   }
sub seq_region_end     :lvalue { $_[0]->Obj->{'seq_region_end'};     }
sub seq_region_strand  :lvalue { $_[0]->Obj->{'seq_region_strand'};  }
sub seq_region_type    :lvalue { $_[0]->Obj->{'seq_region_type'};    }
sub seq_region_length  :lvalue { $_[0]->Obj->{'seq_region_length'};  }

sub align_species {
    my $self = shift;
    if (my $add_species = shift) {
	$self->Obj->{'align_species'} = $add_species;
    }
    return $self->Obj->{'align_species'};
}

 
sub misc_set_code { 
  my $self = shift;
  if( @_ ) { 
    $self->Obj->{'misc_set_code'} = shift;
  }
  return $self->Obj->{'misc_set_code'};
}

sub setCentrePoint {
  my $self        = shift;
  my $centrepoint = shift;
  my $length      = shift || $self->length;
  $self->seq_region_start = $centrepoint - ($length-1)/2;
  $self->seq_region_end   = $centrepoint + ($length+1)/2;
}

sub setLength {
  my $self        = shift;
  my $length      = shift;
  $self->seq_region_start = $self->centrepoint - ($length-1)/2;
  $self->seq_region_end   = $self->seq_region_start + ($length-1)/2;
}

sub addContext {
  my $self = shift;
  my $context = shift;
  $self->seq_region_start -= int($context);
  $self->seq_region_end   += int($context);
}

######## LDVIEW CALLS ################################################

=head2 get_default_pop_id

   Arg[1]      : 
   Example     : my $pop_id = $self->DataObj->get_default_pop_id
   Description : returns population id for default population for this species
   Return type : population dbID

=cut

sub get_default_pop_id {
  my $self = shift;
  my $variation_db = $self->database('variation')->get_db_adaptor('variation');
  my $pop_adaptor = $variation_db->get_PopulationAdaptor;
  my $pop = $pop_adaptor->fetch_default_LDPopulation(); 
  return unless $pop;
  return $pop->dbID;
}

=head2 pop_obj_from_id

  Arg[1]      : Population ID
  Example     : my $pop_name = $self->DataObj->pop_obj_from_id($pop_id);
  Description : returns population name for the given population dbID
  Return type : population object

=cut

sub pop_obj_from_id {
  my $self = shift;
  my $pop_id = shift;
  my $variation_db = $self->database('variation')->get_db_adaptor('variation');
  my $pa  = $variation_db->get_PopulationAdaptor;
  my $pop = $pa->fetch_by_dbID($pop_id);
  return {} unless $pop;
  my %data;
  $data{$pop->dbID}{Name}    = $self->pop_name($pop);
  $data{$pop->dbID}{Size}    = $self->pop_size($pop);
  $data{$pop->dbID}{PopLink} = $self->pop_links($pop);
  $data{$pop->dbID}{Description}= $self->pop_description($pop);
  $data{$pop->dbID}{PopObject}= $pop;  ## ok maybe this is cheating..
  return \%data;
}

=head2 extra_pop

  Arg[1]      : Bio::EnsEMBL::Variation::Population object
  Arg[2]      : string "super", "sub"
  Example     : $genotype_freq = $self->DataObj->extra_pop($pop, "super");
  Description : gets any super/sub populations
  Return type : String

=cut

sub extra_pop {  ### ALSO IN SNP DATA OBJ
  my ($self, $pop_obj, $type)  = @_;
  return {} unless $pop_obj;
  my $call = "get_all_$type" . "_Populations";
  my @populations = @{ $pop_obj->$call};

  my %extra_pop;
  foreach my $pop ( @populations ) {
    $extra_pop{$pop->dbID}{Name}       = $self->pop_name($pop);
    $extra_pop{$pop->dbID}{Size}       = $self->pop_size($pop);
    $extra_pop{$pop->dbID}{PopLink}    = $self->pop_links($pop);
    $extra_pop{$pop->dbID}{Description}= $self->pop_description($pop);
  }
  return \%extra_pop;
}


=head2 pop_name

  Arg[1]      : Bio::EnsEMBL::Variation::Population object
  Example     : $self->DataObj->pop_name($pop);
  Description : gets the Population name
  Return type : String

=cut

sub pop_name {
  my ($self, $pop_obj)  = @_;
  return unless $pop_obj;
  return $pop_obj->name;
}

=head2 ld_for_slice

   Arg[1]      :
   Example     : my $container = $self->ld_for_slice;
   Description : returns all LD values on this slice as a
                 Bio::EnsEMBL::Variation::LDFeatureContainer
   ReturnType  :  Bio::EnsEMBL::Variation::LDFeatureContainer

=cut


sub ld_for_slice {
  my $self = shift; 
  my $pop_id = shift;
  my $width = $self->param('w') || "50000";
  my ($seq_region, $start, $seq_type ) = ($self->seq_region_name, $self->seq_region_start, $self->seq_region_type);
  return [] unless $seq_region;

  my $end   = $start + ($width/2);
  $start -= ($width/2);
  my $slice =
    $self->database('core')->get_SliceAdaptor()->fetch_by_region(
    $seq_type, $seq_region, $start, $end, 1
  );

  return {} unless $slice;
  return  $slice->get_all_LD_values() || {};
}



=head2 pop_links

  Arg[1]      : Bio::EnsEMBL::Variation::Population object
  Example     : $genotype_freq = $self->DataObj->pop_links($pop);
  Description : gets the Population description
  Return type : String

=cut

sub pop_links {
  my ($self, $pop_obj)  = @_;
  return $pop_obj->get_all_synonyms("dbSNP");
}


=head2 pop_size

  Arg[1]      : Bio::EnsEMBL::Variation::Population object
  Example     : $genotype_freq = $self->DataObj->pop_size($pop);
  Description : gets the Population size
  Return type : String

=cut

sub pop_size {
  my ($self, $pop_obj)  = @_;
  return $pop_obj->size;
}


=head2 pop_description

  Arg[1]      : Bio::EnsEMBL::Variation::Population object
  Example     : $genotype_freq = $self->DataObj->pop_description($pop);
  Description : gets the Population description
  Return type : String

=cut

sub pop_description {
  my ($self, $pop_obj)  = @_;
  return $pop_obj->description;
}

=head2 location

    Arg[1]      : (optional) String
                  Name of slice
    Example     : my $location = $self->DataObj->name;
    Description : getter/setter for slice name
    Return type : String for slice name

=cut

sub location { return $_[0]; }

sub generate_query_hash {
  my $self = shift;
  return {
    'c' => $self->seq_region_name.':'.$self->centrepoint.':'.$self->seq_region_strand,
    'w' => $self->length,
    'h' => $self->highlights_string()
  };
}

=head2 get_variation_features

  Arg[1]      : none
  Example     : my @vari_features = $self->get_variation_features;
  Description : gets the Variation features found  on a slice
  Return type : Arrayref of Bio::EnsEMBL::Variation::VariationFeatures

=cut

sub get_variation_features {
   my $self = shift;
   my $slice = $self->slice_cache;
   return unless $slice;
   return $slice->get_all_VariationFeatures || [];
}

sub slice_cache {
  my $self = shift;
  my( $type, $region, $start, $end, $strand ) = @_;
  $type   ||= $self->seq_region_type;
  $region ||= $self->seq_region_name;
  $start  ||= $self->seq_region_start;
  $end    ||= $self->seq_region_end;
  $strand ||= $self->seq_region_strand;

  my $key = join '::', $type, $region, $start, $end, $strand;
  unless ($self->__data->{'slice_cache'}{$key}) {
    $self->__data->{'slice_cache'}{$key} =
      $self->database('core')->get_SliceAdaptor()->fetch_by_region(
        $type, $region, $start, $end, $strand
      );
  }
  return $self->__data->{'slice_cache'}{$key};
}


sub current_pop_id {
  my $self = shift;
  #  my $default_pop = "PERLEGEN:AFD_CHN_PANEL";
  my $param_pop   = $self->param('pop');
  return $param_pop if $param_pop;
  my $default_pop =  $self->get_default_pop_id;
  warn "*****[ERROR]: NO DEFAULT POPULATION DEFINED.\n\n" unless $default_pop;
  return $default_pop;
}


=head2 pops_for_slice

   Arg[1]      :
   Example     : my $data = $self->DataObj->ld_for_slice;
   Description : returns all population IDs with LD data for this slice
   ReturnType  : array ref of population dbIDs
=cut


sub pops_for_slice {
  my $self = shift;
  my $pop  = shift  || "";
  my $ld_container = $self->ld_for_slice($pop);
  return [] unless $ld_container;
  return $ld_container->get_all_populations();
}

1;
