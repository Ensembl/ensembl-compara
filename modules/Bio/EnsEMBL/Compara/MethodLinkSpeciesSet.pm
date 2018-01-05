=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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
                       -species_set     => Bio::EnsEMBL::Compara::SpeciesSet->new( -genome_dbs => [$gdb1, $gdb2, $gdb3]),
                       -max_alignment_length => 10000,
                   );

SET VALUES
  $method_link_species_set->dbID( 12 );
  $method_link_species_set->adaptor( $mlss_adaptor );
  $method_link_species_set->method( Bio::EnsEMBL::Compara::Method->new( -type => 'MULTIZ') );
  $method_link_species_set->species_set( Bio::EnsEMBL::Compara::SpeciesSet->new( -genome_dbs => [$gdb1, $gdb2, $gdb3]) );
  $method_link_species_set->max_alignment_length( 10000 );

GET VALUES
  my $mlss_id           = $method_link_species_set->dbID();
  my $mlss_adaptor      = $method_link_species_set->adaptor();
  my $method            = $method_link_species_set->method();
  my $method_link_id    = $method_link_species_set->method->dbID();
  my $method_link_type  = $method_link_species_set->method->type();
  my $species_set       = $method_link_species_set->species_set();
  my $species_set_id    = $method_link_species_set->species_set->dbID();
  my $genome_dbs        = $method_link_species_set->species_set->genome_dbs();
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

use base (  'Bio::EnsEMBL::Compara::StorableWithReleaseHistory',           # inherit dbID(), adaptor() and new() methods, and first_release() and last_release()
            'Bio::EnsEMBL::Compara::Taggable'   # inherit everything related to tagability
         );

my $DEFAULT_MAX_ALIGNMENT = 20000;


=head2 new (CONSTRUCTOR)

  Arg [-DBID]           : (opt.) int $dbID (the database internal ID for this object)
  Arg [-ADAPTOR]        : (opt.) Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor $adaptor
                            (the adaptor for connecting to the database)
  Arg [-METHOD]         : Bio::EnsEMBL::Compara::Method $method object
  Arg [-SPECIES_SET]    : Bio::EnsEMBL::Compara::SpeciesSet $species_set object
  Arg [-NAME]           : (opt.) string $name (the name for this method_link_species_set)
  Arg [-SOURCE]         : (opt.) string $source (the source of these data)
  Arg [-URL]            : (opt.) string $url (the original url of these data)
  Arg [-MAX_ALGINMENT_LENGTH]
                        : (opt.) int $max_alignment_length (the length of the largest alignment
                            for this MethodLinkSpeciesSet (only used for genomic alignments)
  Example     : my $method_link_species_set = Bio::EnsEMBL::Compara::MethodLinkSpeciesSet->new(
                       -adaptor => $method_link_species_set_adaptor,
                       -method => Bio::EnsEMBL::Compara::Method->new( -type => 'MULTIZ' ),
                       -species_set => Bio::EnsEMBL::Compara::SpeciesSet->new( -genome_dbs => [$gdb1, $gdb2, $gdb3] ),
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

    my ($method, $species_set_obj, $species_set,
        $name, $source, $url, $max_alignment_length) =
            rearrange([qw(
                METHOD SPECIES_SET_OBJ SPECIES_SET
                NAME SOURCE URL MAX_ALIGNMENT_LENGTH)], @_);

  if($method) {
      $self->method($method);
  } else {
      warning("method has not been set in MLSS->new");
  }

  if ($species_set) {
      $self->species_set($species_set);
  } elsif ($species_set_obj) {
      deprecate('MethodLinkSpeciesSet::new(-SPECIES_SET_OBJ => ...) is deprecated and will be removed in e89. Use -SPECIES_SET instead');
      $self->species_set($species_set_obj);
  } else {
      warning("species_set has not been set in MLSS->new");
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


=head2 species_set_obj (DEPRECATED)

  Description: DEPRECATED. It will be removed in e89. Use species_set() instead

=cut

sub species_set_obj {   ## DEPRECATED
    my $self = shift;
    deprecate('MethodLinkSpeciesSet::species_set_obj is deprecated and will be removed in e89. Use species_set() instead');
    return $self->species_set(@_);
}


=head2 species_set

  Arg [1]    : (opt.) Bio::EnsEMBL::Compara::SpeciesSet species_set object
  Example    : my $species_set = $mlss->species_set();
  Example    : $mlss->species_set( $species_set );
  Description: getter/setter for species_set attribute
  Returntype : Bio::EnsEMBL::Compara::SpeciesSet
  Exceptions : none
  Caller     : general

=cut

sub species_set {
    my ($self, $species_set) = @_;

    if($species_set) {
        if(ref($species_set) eq 'HASH') {
            $species_set = Bio::EnsEMBL::Compara::SpeciesSet->new( %$species_set ) or die "Could not automagically create a SpeciesSet\n";
        }

        $self->{'species_set'} = $species_set;
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
  Example    : my $url = $method_link_species_set->url();
  Example    : $method_link_species_set->url("http://hgdownload.cse.ucsc.edu/goldenPath/monDom1/vsHg17/");
  Description: get/set for attribute url. Defines where the data come from if they
               have been imported. Note that some urls are defined with #base_dir# in the database to
               represent a part that has to be substituted with runtime configuration. This method returns
               the substituted URL.
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub url {
  my ($self, $arg) = @_;

  if (defined($arg)) {
    $self->{'url'} = $arg ;
  }
  if ($self->{'url'} && ($self->{'url'} =~ /^#base_dir#/)) {
      die "Need an adaptor to resolve the location of ".$self->{'url'} unless $self->adaptor;

      my $data_dir = $self->adaptor->base_dir_location;
      my $url = $self->{'url'};
      #warn "<- $url";
      $url =~ s/#base_dir#/$data_dir/;
      $url =~ s/\/multi\/+multi\//\/multi\//;    # temporary hack for e88 production until the database has been updated
      #warn "-> $url";

      if (-e $url) {
          $self->{'original_url'} = $url;
          $self->{'url'} = $url;
      } else {
          die "'$url' does not exist on this machine\n";
      }
  }

  return $self->{'url'};
}


=head2 get_original_url

  Example    : my $url = $method_link_species_set->get_original_url();
  Description: Returns the URL as stored in the database (before substitution)
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub get_original_url {
    my $self = shift;

    return ($self->{'original_url'} || $self->{'url'});
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
    return $self->_getter_setter_for_tag('max_align', @_) || $DEFAULT_MAX_ALIGNMENT;
}


=head2 toString

  Args       : (none)
  Example    : print $mlss->toString()."\n";
  Description: returns a stringified representation of the method_link_species_set
  Returntype : string

=cut

sub toString {
    my $self = shift;

    my $txt = sprintf('MethodLinkSpeciesSet dbID=%s', $self->dbID || '?');
    $txt .= ' ' . ($self->name ? sprintf('"%s"', $self->name) : '(unnamed)');
    $txt .= sprintf(' {method "%s"} x {species-set "%s"}', $self->method->type, $self->species_set->name || $self->species_set->dbID);
    $txt .= ', found in '.$self->url if $self->url;
    $txt .= ' ' . $self->SUPER::toString();
    return $txt;
}


=head2 species_tree

  Arg[1]      : (optional) String $label (default: "default"). The label of the species-tree to retrieve
  Example     : $mlss->species_tree();
  Description : Returns the species-tree associated to this MLSS
  Returntype  : Bio::EnsEMBL::Compara::SpeciesTree
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub species_tree {
    my ($self, $label) = @_;

    $label ||= 'default';
    my $key = '_species_tree_'.$label;
    return $self->{$key} if $self->{$key};

    my $species_tree = $self->adaptor->db->get_SpeciesTreeAdaptor->fetch_by_method_link_species_set_id_label($self->dbID, $label);

    $self->{$key} = $species_tree;
    return $species_tree;
}


1;
