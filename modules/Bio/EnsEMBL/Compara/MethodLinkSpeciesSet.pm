#
# Ensembl module for Bio::EnsEMBL::Compara::MethodLinkSpeciesSet
#
# Cared for by Javier Herrero <jherrero@ebi.ac.uk>
#
# Copyright Javier Herrero
#
# You may distribute this module under the same terms as perl itself

# pod documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::MethodLinkSpeciesSet -
Relates every method_link with the species_set for which it has been used

=head1 SYNOPSIS

  use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
  my $method_link_species_set = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet({
                       -adaptor => $method_link_species_set_adaptor,
                       -method_link_type => "MULTIZ",
                       -species_set => [$gdb1, $gdb2, $gdb3]
                   });

SET VALUES
  $method_link_species_set->dbID(12);
  $method_link_species_set->adaptor($meth_lnk_spcs_adaptor);
  $method_link_species_set->method_link_id(23);
  $method_link_species_set->method_link_type("MULTIZ");
  $method_link_species_set->species_set([$gdb1, $gdb2, $gdb3]);

GET VALUES
  my $dbID = $method_link_species_set->dbID();
  my $meth_lnk_spcs_adaptor = $method_link_species_set->adaptor();
  my $meth_lnk_id = $method_link_species_set->method_link_id();
  my $meth_lnk_type = $method_link_species_set->method_link_type();
  my $meth_lnk_species_set = $method_link_species_set->species_set();


=head1 OBJECT MEMBERS

=over

=item dbID

corresponds to method_link_species.method_link_species_set

=item adaptor

Bio::EnsEMBL::Compara::MethodLinkSpeciesSetAdaptor object to access DB

=item method_link_id

corresponds to method_link_species.method_link_id (external ref. to
method_link.method_link_id)

=item method_link_type

corresponds to method_link.type, accessed through method_link_id (external ref.)

=item species_set

listref of Bio::EnsEMBL::Compara::GenomeDB objects. Each of them corresponds to
a method_link_species.genome_db_id

=back

=head1 AUTHOR

Javier Herrero (jherrero@ebi.ac.uk)

This modules is part of the Ensembl project http://www.ensembl.org

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use vars qw(@ISA);
use strict;

# Object preamble

use Bio::EnsEMBL::Root;

@ISA = qw(Bio::EnsEMBL::Root);

# new() is written here 

=head2 new (CONSTRUCTOR)

  Arg[1]     : a reference to a hash where keys can be:
                 -adaptor
                 -method_link_id
                 -method_link_type
                 -species_set (ref. to an array of
                       Bio::EnsEMBL::Compara::GenomeDB objects)
  Example    : my $method_link_species_set =
                   new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet({
                       -adaptor => $method_link_species_set_adaptor,
                       -method_link_type => "MULTIZ",
                       -species_set => [$gdb1, $gdb2, $gdb3]
                   });
  Description: Creates a new MethodLinkSpeciesSet object
  Returntype : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
  Exceptions : none
  Caller     : general

=cut

sub new {
  my($class, @args) = @_;
  
  my $self = {};
  bless $self,$class;
    
  my (
		$dbID,
		$adaptor,
		$method_link_id,
		$method_link_type,
		$species_set
	
	) = $self->_rearrange([qw(
			
			DBID
			ADAPTOR
			METHOD_LINK_ID
			METHOD_LINK_TYPE
			SPECIES_SET

		)], @args);

  $self->dbID($dbID) if (defined ($dbID));
  $self->adaptor($adaptor) if (defined ($adaptor));
  $self->method_link_id($method_link_id) if (defined ($method_link_id));
  $self->method_link_type($method_link_type) if (defined ($method_link_type));
  $self->species_set($species_set) if (defined ($species_set));

  return $self;
}


sub new_fast {
  my $class = shift;
  my $hashref = shift;

  return bless $hashref, $class;
}


=head2 dbID

  Arg [1]    : (opt.) integer dbID
  Example    : my $dbID = $method_link_species_set->dbID();
  Example    : $method_link_species_set->dbID(12);
  Description: Getter/Setter for the dbID of this object in the database
  Returntype : integer dbID
  Exceptions : none
  Caller     : general

=cut

sub dbID {
  my ($obj, $value) = @_;
  
  if (defined($value)) {
    $obj->{'dbID'} = $value;
  }
  
  return $obj->{'dbID'};
}


=head2 adaptor

  Arg [1]    : (opt.) Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor
  Example    : my $meth_lnk_spcs_adaptor = $method_link_species_set->adaptor();
  Example    : $method_link_species_set->adaptor($meth_lnk_spcs_adaptor);
  Description: Getter/Setter for the adaptor this object uses for database
               interaction.
  Returntype : Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor
  Exceptions : none
  Caller     : general

=cut

sub adaptor {
  my ($obj,$value) = @_;
  
  if (defined($value)) {
    $obj->{'adaptor'} = $value;
  }
  
  return $obj->{'adaptor'};
}


=head2 method_link_id
 
  Arg [1]    : (opt.) integer method_link_id
  Example    : my $meth_lnk_id = $method_link_species_set->method_link_id();
  Example    : $method_link_species_set->method_link_id(23);
  Description: get/set for attribute method_link_id
  Returntype : integer
  Exceptions : none
  Caller     : general
 
=cut

sub method_link_id {
  my ($self, $arg) = @_;

  if (defined($arg)) {
    $self->{'method_link_id'} = $arg ;
  }
  
  if (!defined($self->{'method_link_id'})
      && defined($self->{'method_link_type'})
      && defined($self->{'adaptor'})) {
    $self->{'method_link_id'} = $self->adaptor->_get_method_link_id_from_type($self->{'method_link_type'});
  }

  return $self->{'method_link_id'};
}


=head2 method_link_type
 
  Arg [1]    : (opt.) string method_link_type
  Example    : my $meth_lnk_type = $method_link_species_set->method_link_type();
  Example    : $method_link_species_set->method_link_type("BLASTZ_NET");
  Description: get/set for attribute method_link_type
  Returntype : string
  Exceptions : none
  Caller     : general
 
=cut

sub method_link_type {
  my ($self, $arg) = @_;

  if (defined($arg)) {
    $self->{'method_link_type'} = $arg;
  }
  
  if (!defined($self->{'method_link_type'})
      && defined($self->{'method_link_id'})
      && defined($self->{'adaptor'})) {
    $self->{'method_link_type'} = $self->adaptor->_get_method_link_type_from_id($self->{'method_link_id'});
  }

  return $self->{'method_link_type'};
}


=head2 species_set
 
  Arg [1]    : (opt.) listref of Bio::EnsEMBL::Compara::GenomeDB objects
  Example    : my $meth_lnk_species_set = $method_link_species_set->species_set();
  Example    : $method_link_species_set->species_set([$gdb1, $gdb2, $gdb3]);
  Description: get/set for attribute species_set
  Returntype : listref of Bio::EnsEMBL::Compara::GenomeDB objects
  Exceptions : Thrown if any argument is not a Bio::EnsEMBL::Compara::GenomeDB
               object or a GenomeDB entry appears several times
  Caller     : general
 
=cut

sub species_set {
  my ($self, $arg) = @_;
 
  if ($arg && @$arg) {
    ## Check content
    my $genome;
    foreach my $genome_db (@$arg) {
      $self->throw("undefined value used as a Bio::EnsEMBL::Compara::GenomeDB\n") if (!defined($genome_db));
      $self->throw("$genome_db must be a Bio::EnsEMBL::Compara::GenomeDB\n")
        unless $genome_db->isa("Bio::EnsEMBL::Compara::GenomeDB");
      $self->throw("GenomeDB (".$genome_db->name."; dbID=".$genome_db->dbID.
          ") appears twice in this Bio::EnsEMBL::Compara::MethodLinkSpeciesSet\n")
        if $genome->{$genome_db->dbID};

      $genome->{$genome_db->dbID} = 1;
    }
    $self->{'species_set'} = $arg ;
  }
  
  return $self->{'species_set'};
}

1;
