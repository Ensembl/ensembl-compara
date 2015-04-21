=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::MethodLinkSpeciesSet -
Relates every method_link with the species_set for which it has been used

=head1 SYNOPSIS

  use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
  my $method_link_species_set = Bio::EnsEMBL::Compara::MethodLinkSpeciesSet->new(
                       -adaptor             => $method_link_species_set_adaptor,
                       -method              => Bio::EnsEMBL::Compara::Method->new( -type => 'MULTIZ'),
                       -species_set_obj     => Bio::EnsEMBL::Compara::SpeciesSet->new( -genome_dbs => [$gdb1, $gdb2, $gdb3]),
                       -max_alignment_length => 10000,
                   );

SET VALUES
  $method_link_species_set->dbID( 12 );
  $method_link_species_set->adaptor( $mlss_adaptor );
  $method_link_species_set->method( Bio::EnsEMBL::Compara::Method->new( -type => 'MULTIZ') );
  $method_link_species_set->species_set_obj( Bio::EnsEMBL::Compara::SpeciesSet->new( -genome_dbs => [$gdb1, $gdb2, $gdb3]) );
  $method_link_species_set->max_alignment_length( 10000 );

GET VALUES
  my $mlss_id           = $method_link_species_set->dbID();
  my $mlss_adaptor      = $method_link_species_set->adaptor();
  my $method            = $method_link_species_set->method();
  my $method_link_id    = $method_link_species_set->method->dbID();
  my $method_link_type  = $method_link_species_set->method->type();
  my $species_set       = $method_link_species_set->species_set_obj();
  my $species_set_id    = $method_link_species_set->species_set_obj->dbID();
  my $genome_dbs        = $method_link_species_set->species_set_obj->genome_dbs();
  my $max_alignment_length = $method_link_species_set->max_alignment_length();

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut



package Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception qw(throw warning deprecate);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Scalar qw(:assert);
use Bio::EnsEMBL::Compara::Method;
use Bio::EnsEMBL::Compara::SpeciesSet;

use base (  'Bio::EnsEMBL::Storable',           # inherit dbID(), adaptor() and new() methods
            'Bio::EnsEMBL::Compara::Taggable'   # inherit everything related to tagability
         );

my $DEFAULT_MAX_ALIGNMENT = 20000;


=head2 new (CONSTRUCTOR)

  Arg [-DBID]           : (opt.) int $dbID (the database internal ID for this object)
  Arg [-ADAPTOR]        : (opt.) Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor $adaptor
                            (the adaptor for connecting to the database)
  Arg [-METHOD]         : Bio::EnsEMBL::Compara::Method $method object
  Arg [-SPECIES_SET_OBJ]: Bio::EnsEMBL::Compara::SpeciesSet $species_set object
  Arg [-NAME]           : (opt.) string $name (the name for this method_link_species_set)
  Arg [-SOURCE]         : (opt.) string $source (the source of these data)
  Arg [-URL]            : (opt.) string $url (the original url of these data)
  Arg [-MAX_ALGINMENT_LENGTH]
                        : (opt.) int $max_alignment_length (the length of the largest alignment
                            for this MethodLinkSpeciesSet (only used for genomic alignments)
  Example     : my $method_link_species_set = Bio::EnsEMBL::Compara::MethodLinkSpeciesSet->new(
                       -adaptor => $method_link_species_set_adaptor,
                       -method => Bio::EnsEMBL::Compara::Method->new( -type => 'MULTIZ' ),
                       -species_set_obj => Bio::EnsEMBL::Compara::SpeciesSet->new( -genome_dbs => [$gdb1, $gdb2, $gdb3] ),
                       -max_alignment_length => 10000,
                   );
  Description : Creates a new MethodLinkSpeciesSet object
  Returntype  : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
  Exceptions  : none
  Caller      : general

=cut

sub new {
    my $caller = shift @_;
    my $class = ref($caller) || $caller;

    my $self = $class->SUPER::new(@_);  # deal with Storable stuff

    my ($method, $species_set_obj,
        $name, $source, $url, $max_alignment_length) =
            rearrange([qw(
                METHOD SPECIES_SET_OBJ
                NAME SOURCE URL MAX_ALIGNMENT_LENGTH)], @_);

  if($method) {
      $self->method($method);
  } else {
      warning("method has not been set in MLSS->new");
  }

  if ($species_set_obj) {
      $self->species_set_obj($species_set_obj);
  } else {
      warning("species_set_obj has not been set in MLSS->new");
  }

  $self->name($name) if (defined ($name));
  $self->source($source) if (defined ($source));
  $self->url($url) if (defined ($url));
  $self->max_alignment_length($max_alignment_length) if (defined ($max_alignment_length));

  return $self;
}



=head2 method

  Arg [1]    : (opt.) Bio::EnsEMBL::Compara::Method object
  Example    : my $method_object = $method_link_species_set->method();
  Example    : $method_link_species_set->method( $method_object );
  Description: get/set for attribute method
  Returntype : Bio::EnsEMBL::Compara::Method
  Exceptions : none
  Caller     : general

=cut

sub method {
    my ($self, $method) = @_;

    if($method) {
        if(ref($method) eq 'HASH') {
            $method = Bio::EnsEMBL::Compara::Method->new( %$method ) or die "Could not automagically create a Method\n";
        }

        $self->{'method'} = $method;
    }

    return $self->{'method'};
}


=head2 species_set_obj

  Arg [1]    : (opt.) Bio::EnsEMBL::Compara::SpeciesSet species_set object
  Example    : my $species_set_obj = $mlss->species_set_obj();
  Example    : $mlss->species_set_obj( $species_set_obj );
  Description: getter/setter for species_set_obj attribute
  Returntype : Bio::EnsEMBL::Compara::SpeciesSet
  Exceptions : none
  Caller     : general

=cut

sub species_set_obj {
    my ($self, $species_set_obj) = @_;

    if($species_set_obj) {
        if(ref($species_set_obj) eq 'HASH') {
            $species_set_obj = Bio::EnsEMBL::Compara::SpeciesSet->new( %$species_set_obj ) or die "Could not automagically create a SpeciesSet\n";
        }

        $self->{'species_set'} = $species_set_obj;
    }

    return $self->{'species_set'};
}




=head2 name

  Arg [1]    : (opt.) string $name
  Example    : my $name = $method_link_species_set->name();
  Example    : $method_link_species_set->name("families");
  Description: get/set for attribute name
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub name {
  my ($self, $arg) = @_;

  if (defined($arg)) {
    $self->{'name'} = $arg ;
  }

  return $self->{'name'};
}


=head2 source

  Arg [1]    : (opt.) string $name
  Example    : my $name = $method_link_species_set->source();
  Example    : $method_link_species_set->source("ensembl");
  Description: get/set for attribute source. The source refers to who
               generated the data in a first instance (ensembl, ucsc...)
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub source {
  my ($self, $arg) = @_;

  if (defined($arg)) {
    $self->{'source'} = $arg ;
  }

  return $self->{'source'};
}


=head2 url

  Arg [1]    : (opt.) string $url
  Example    : my $name = $method_link_species_set->source();
  Example    : $method_link_species_set->url("http://hgdownload.cse.ucsc.edu/goldenPath/monDom1/vsHg17/");
  Description: get/set for attribute url. Defines where the data come from if they
               have been imported
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub url {
  my ($self, $arg) = @_;

  if (defined($arg)) {
    $self->{'url'} = $arg ;
  }

  return $self->{'url'};
}


=head2 get_common_classification

  Arg [1]    : -none-
  Example    : my $common_classification = $method_link_species_set->
                   get_common_classification();
  Description: This method fetches the taxonimic classifications for all the
               species included in this
               Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object and
               returns the common part of them.
  Returntype : array of strings
  Exceptions : 
  Caller     : general

=cut

sub get_common_classification {
  my ($self) = @_;
  my $common_classification;

  my $species_set = $self->species_set_obj();

  foreach my $this_genome_db (@{$species_set->genome_dbs}) {
    my @classification = split(" ", $this_genome_db->taxon->classification);
    if (!defined($common_classification)) {
      @$common_classification = @classification;
    } else {
      my $new_common_classification = [];
      for (my $i = 0; $i <@classification; $i++) {
        for (my $j = 0; $j<@$common_classification; $j++) {
          if ($classification[$i] eq $common_classification->[$j]) {
            push(@$new_common_classification, splice(@$common_classification, $j, 1));
            last;
          }
        }
      }
      $common_classification = $new_common_classification;
    }
  }

  return $common_classification;
}


=head2 max_alignment_length

  Arg [1]    : (opt.) int $max_alignment_length
  Example    : my $max_alignment_length = $method_link_species_set->
                   max_alignment_length();
  Example    : $method_link_species_set->max_alignment_length(1000);
  Description: get/set for attribute max_alignment_length
  Returntype : integer
  Exceptions : 
  Caller     : general

=cut

sub max_alignment_length {
    my $self = shift @_;
    my $max_align = shift;

    if($max_align) {
        $self->add_tag('max_align', $max_align);
    }

    return $self->get_value_for_tag('max_align') || $DEFAULT_MAX_ALIGNMENT;
}


=head2 toString

  Args       : (none)
  Example    : print $mlss->toString()."\n";
  Description: returns a stringified representation of the method_link_species_set
  Returntype : string

=cut

sub toString {
    my $self = shift;

    return ref($self).": dbID=".($self->dbID || '?').
                      ", name='".$self->name.
                      "', source='".$self->source.
                      "', url='".$self->url.
                      "', max_alignment_length=".($self->max_alignment_length || '?').
                      ", {".$self->method->toString."} x {".$self->species_set_obj->toString."}";
}


1;
