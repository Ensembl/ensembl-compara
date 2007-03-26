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
  my $method_link_species_set = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet(
                       -adaptor => $method_link_species_set_adaptor,
                       -method_link_type => "MULTIZ",
                       -species_set => [$gdb1, $gdb2, $gdb3],
                       -max_alignment_length => 10000,
                   );

SET VALUES
  $method_link_species_set->dbID(12);
  $method_link_species_set->adaptor($meth_lnk_spcs_adaptor);
  $method_link_species_set->method_link_id(23);
  $method_link_species_set->method_link_type("MULTIZ");
  $method_link_species_set->species_set([$gdb1, $gdb2, $gdb3]);
  $method_link_species_set->max_alignment_length(10000);

GET VALUES
  my $dbID = $method_link_species_set->dbID();
  my $meth_lnk_spcs_adaptor = $method_link_species_set->adaptor();
  my $meth_lnk_id = $method_link_species_set->method_link_id();
  my $meth_lnk_type = $method_link_species_set->method_link_type();
  my $meth_lnk_species_set = $method_link_species_set->species_set();
  my $max_alignment_length = $method_link_species_set->max_alignment_length();


=head1 OBJECT ATTRIBUTES

=over

=item dbID

corresponds to method_link_species_set.method_link_species_set_id

=item adaptor

Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor object to access DB

=item method_link_id

corresponds to method_link_species_set.method_link_id (external ref. to
method_link.method_link_id)

=item method_link_type

corresponds to method_link.type, accessed through method_link_id (external ref.)

=item method_link_class

corresponds to method_link.class, accessed through method_link_id (external ref.)

=item species_set_id

corresponds to method_link_species_set.species_set_id (external ref. to
species_set.species_set_id)

=item species_set

listref of Bio::EnsEMBL::Compara::GenomeDB objects. Each of them corresponds to
a species_set.genome_db_id

=item max_alignment_length (experimental)

Integer. This value is used to speed up the fetching of genomic_align_blocks.
It corresponds to an entry in the meta table where the key is "max_align_$dbID"
where $dbID id the method_link_species_set.method_link_species_set_id.

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

use Bio::EnsEMBL::Utils::Exception qw(throw warning deprecate);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);


# new() is written here 

=head2 new (CONSTRUCTOR)

  Arg [-DBID] : (opt.) int $dbID (the database internal ID for this object)
  Arg [-ADAPTOR]
              : (opt.) Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor $adaptor
                (the adaptor for connecting to the database)
  Arg [-METHOD_LINK_ID]
              : (opt.) int $method_link_id (the database internal ID for the method_link)
  Arg [-METHOD_LINK_TYPE]
              : (opt.) string $method_link_type (the name of the method_link)
  Arg [-METHOD_LINK_CLASS]
              : (opt.) string $method_link_class (the class of the method_link)
  Arg [-SPECIES_SET_ID]
              : (opt.) int $species_set_id (the database internal ID for the species_set)
  Arg [-SPECIES_SET]
              : (opt.) arrayref $genome_dbs (a reference to an array of
                Bio::EnsEMBL::Compara::GenomeDB objects)
  Arg [-NAME]
              : (opt.) string $name (the name for this method_link_species_set)
  Arg [-SOURCE]
              : (opt.) string $source (the source of these data)
  Arg [-URL]
              : (opt.) string $url (the original url of these data)
  Arg [-MAX_ALGINMENT_LENGTH]
              : (opt.) int $max_alignment_length (the length of the largest alignment
                for this MethodLinkSpeciesSet (only used for genomic alignments)
  Example     : my $method_link_species_set =
                   new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet(
                       -adaptor => $method_link_species_set_adaptor,
                       -method_link_type => "MULTIZ",
                       -species_set => [$gdb1, $gdb2, $gdb3],
                       -max_alignment_length => 10000,
                   );
  Description : Creates a new MethodLinkSpeciesSet object
  Returntype  : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
  Exceptions  : none
  Caller      : general

=cut

sub new {
  my($class, @args) = @_;
  
  my $self = {};
  bless $self,$class;
    
  my ($dbID, $adaptor, $method_link_id, $method_link_type, $species_set_id, $species_set,
      $method_link_class, $name, $source, $url, $max_alignment_length) =
      rearrange([qw(
          DBID ADAPTOR METHOD_LINK_ID METHOD_LINK_TYPE SPECIES_SET_ID SPECIES_SET
          METHOD_LINK_CLASS NAME SOURCE URL MAX_ALIGNMENT_LENGTH)], @args);

  $self->dbID($dbID) if (defined ($dbID));
  $self->adaptor($adaptor) if (defined ($adaptor));
  $self->method_link_id($method_link_id) if (defined ($method_link_id));
  $self->method_link_type($method_link_type) if (defined ($method_link_type));
  $self->method_link_class($method_link_class) if (defined ($method_link_class));
  $self->species_set_id($species_set_id) if (defined ($species_set_id));
  $self->species_set($species_set) if (defined ($species_set));
  $self->name($name) if (defined ($name));
  $self->source($source) if (defined ($source));
  $self->url($url) if (defined ($url));
  $self->max_alignment_length($max_alignment_length) if (defined ($max_alignment_length));

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
  my $obj = shift;
  
  if (@_) {
    $obj->{'dbID'} = shift;
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
  my $obj = shift;
  
  if (@_) {
    $obj->{'adaptor'} = shift;
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
    $self->{'method_link_id'} = $self->adaptor->get_method_link_id_from_method_link_type($self->{'method_link_type'});
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
    $self->{'method_link_type'} = $self->adaptor->get_method_link_type_from_method_link_id($self->{'method_link_id'});
  }

  return $self->{'method_link_type'};
}


=head2 method_link_class
 
  Arg [1]    : (opt.) string method_link_class
  Example    : my $meth_lnk_class = $method_link_species_set->method_link_class();
  Example    : $method_link_species_set->method_link_class("GenomicAlignBlock.multiple_alignment");
  Description: get/set for attribute method_link_class
  Returntype : string
  Exceptions : none
  Caller     : general
 
=cut

sub method_link_class {
  my ($self, $arg) = @_;

  if (defined($arg)) {
    $self->{'method_link_class'} = $arg;
  }
  
  if (!defined($self->{'method_link_class'})
      && defined($self->{'method_link_id'})
      && defined($self->{'adaptor'})) {
    $self->{'method_link_class'} = $self->adaptor->_get_method_link_class_from_id($self->{'method_link_id'});
  }

  return $self->{'method_link_class'};
}


=head2 species_set_id

  Arg [1]    : (opt.) integer species_set_id
  Example    : my $species_set_id = $method_link_species_set->species_set_id();
  Example    : $method_link_species_set->species_set_id(23);
  Description: get/set for attribute species_set_id
  Returntype : integer
  Exceptions : none
  Caller     : general

=cut

sub species_set_id {
  my ($self, $arg) = @_;

  if (defined($arg)) {
    $self->{'species_set_id'} = $arg ;
  }

  if (!defined($self->{'species_set_id'})
      && defined($self->{'species_set'})
      && defined($self->{'adaptor'})) {
    $self->{'species_set_id'} = $self->adaptor->_get_species_set_id_from_species_set($self->{'species_set'});
  }

  return $self->{'species_set_id'};
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
    my $genome_dbs;
    foreach my $gdb (@$arg) {
      throw("undefined value used as a Bio::EnsEMBL::Compara::GenomeDB\n")
        if (!defined($gdb));
      throw("$gdb must be a Bio::EnsEMBL::Compara::GenomeDB\n")
        unless $gdb->isa("Bio::EnsEMBL::Compara::GenomeDB");

      unless (defined $genome_dbs->{$gdb->dbID}) {
        $genome_dbs->{$gdb->dbID} = $gdb;
      } else {
        warn("GenomeDB (".$gdb->name."; dbID=".$gdb->dbID .
             ") appears twice in this Bio::EnsEMBL::Compara::MethodLinkSpeciesSet\n");
      }
    }
    $self->{'species_set'} = [ values %{$genome_dbs} ] ;
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

  my $species_set = $self->species_set();

  foreach my $this_genome_db (@$species_set) {
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
  my ($self, $arg) = @_;

  if (defined($arg)) {
    $self->{'max_alignment_length'} = int($arg);
  } elsif (!defined($self->{'max_alignment_length'}) and defined($self->adaptor)) {
    $self->adaptor->get_max_alignment_length($self);
  }

  return $self->{'max_alignment_length'};
}

1;
