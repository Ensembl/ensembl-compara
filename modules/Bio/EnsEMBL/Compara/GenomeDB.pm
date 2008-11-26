
#
# Ensembl module for Bio::EnsEMBL::Compara::GenomeDB
#
# Cared for by Ewan Birney <birney@ebi.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::GenomeDB - DESCRIPTION of Object

=head1 SYNOPSIS
  use Bio::EnsEMBL::Compara::DnaFrag; 
  my $genome_db = new Bio::EnsEMBL::Compara::GenomeDB();

SET VALUES
  $genome_db->dbID(22);
  $genome_db->dba($dba);
  $genome_db->name("Homo sapiens");
  $genome_db->assembly("NCBI36");
  $genome_db->taxon_id(9606);
  $genome_db->taxon($taxon);
  $genome_db->genebuild("2006-12-Ensembl");
  $genome_db->assembly_default(1);
  $genome_db->locator("Bio::EnsEMBL::DBSQL::DBAdaptor/host=???;port=???;user=???;dbname=homo_sapiens_core_51_36m;species=Homo sapiens;disconnect_when_inactive=1");

GET VALUES
  $dbID = $genome_db->dbID;
  $genome_db_adaptor = $genome_db->adaptor;
  $name = $genome_db->name;
  $assembly = $genome_db->assembly;
  $taxon_id = $genome_db->taxon_id;
  $taxon = $genome_db->taxon;
  $genebuild = $genome_db->genebuild;
  $assembly_default = $genome_db->assembly_default;
  $locator = $genome_db->locator;


=head1 DESCRIPTION

The GenomeDB object stores information about each species including the taxon_id, species name, assembly, genebuild and the location of the core database.

=head1 AUTHOR - Ewan Birney

This modules is part of the Ensembl project http://www.ensembl.org

Email birney@ebi.ac.uk

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::GenomeDB;

use strict;

use Bio::EnsEMBL::Utils::Exception qw(warning deprecate throw);
use Bio::EnsEMBL::DBLoader;

=head2 new

  Example :
    my $genome_db = new Bio::EnsEMBL::Compara::GenomeDB();
    $genome_db->dba($dba);
    $genome_db->name("Homo sapiens");
    $genome_db->assembly("NCBI36");
    $genome_db->taxon_id(9606);
    $genome_db->dbID(22);
    $genome_db->genebuild("2006-12-Ensembl");

  Description: Creates a new GenomeDB object
  Returntype : Bio::EnsEMBL::Compara::GenomeDB
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub new {
  my($caller, $dba, $name, $assembly, $taxon_id, $dbID, $genebuild) = @_;

  my $class = ref($caller) || $caller;
  my $self = bless({}, $class);

  $dba       && $self->db_adaptor($dba);
  $name      && $self->name($name);
  $assembly  && $self->assembly($assembly);
  $taxon_id  && $self->taxon_id($taxon_id);
  $dbID      && $self->dbID($dbID);
  $genebuild && $self->genebuild($genebuild);

  return $self;
}



=head2 db_adaptor

  Arg [1]    : (optional) Bio::EnsEMBL::DBSQL::DBAdaptor $dba
               The DBAdaptor containing sequence information for the genome
               represented by this object.
  Example    : $gdb->db_adaptor($dba);
  Description: Getter/Setter for the DBAdaptor containing sequence 
               information for the genome represented by this object.
  Returntype : Bio::EnsEMBL::DBSQL::DBAdaptor
  Exceptions : thrown if the argument is not a
               Bio::EnsEMBL::DBSQL::DBAdaptor
  Caller     : general
  Status     : Stable

=cut

sub db_adaptor {
  my ( $self, $dba ) = @_;

  if($dba) {
    unless($dba && $dba->isa('Bio::EnsEMBL::DBSQL::DBAdaptor')) {
      throw("dba arg must be a Bio::EnsEMBL::DBSQL::DBAdaptor not a [$dba]\n");
    }
    $self->{'_db_adaptor'} = $dba;
  }
  
  unless (defined $self->{'_db_adaptor'}) {
    $self->{'_db_adaptor'} = $self->connect_to_genome_locator;
  }
  
  return $self->{'_db_adaptor'};
}



=head2 name

  Arg [1]    : (optional) string $value
  Example    : $gdb->name('Homo sapiens');
  Description: Getter setter for the name of this genome database, usually
               just the species name.
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub name{
  my ($self,$value) = @_;

  if( defined $value) {
    $self->{'name'} = $value;
  }
  return $self->{'name'};
}


=head2 short_name

  Example    : $gdb->short_name;
  Description: The name of this genome in the Gspe ('G'enera
               'spe'cies) format. Can also handle 'G'enera 's'pecies
               's'ub 's'pecies (Gsss)
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub short_name {
  my $self = shift;
  my $name = $self->name;
  unless( $name =~  s/(\S)\S*\s(\S)\S*\s(\S)\S*\s(\S).*/$1$2$3$4/ ){
    unless( $name =~  s/(\S)\S*\s(\S)\S*\s(\S{2,2}).*/$1$2$3/ ){
      unless( $name =~  s/(\S)\S*\s(\S{3,3}).*/$1$2/ ){
        $name = substr( $name, 0, 4 );
      }
    }
  }
  return $name;
}

=head2 get_short_name

  Example    : $gdb->get_short_name;
  Description: The name of this genome in the Gspe ('G'enera
               'spe'cies) format. Can also handle 'G'enera 's'pecies
               's'ub 's'pecies (Gsss)
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub get_short_name {
  my $self = shift;
  return $self->short_name;
}


=head2 dbID

  Arg [1]    : (optional) int $value the new value of this objects database 
               identifier
  Example    : $dbID = $genome_db->dbID;
  Description: Getter/Setter for the internal identifier of this GenomeDB
  Returntype : int
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub dbID{
   my ($self,$value) = @_;
   if( defined $value) {
     $self->{'dbID'} = $value;
   }
   return $self->{'dbID'};
}


=head2 adaptor

  Arg [1]    : (optional) Bio::EnsEMBL::Compara::GenomeDBAdaptor $adaptor
  Example    : $adaptor = $GenomeDB->adaptor();
  Description: Getter/Setter for the GenomeDB object adaptor used
               by this GenomeDB for database interaction.
  Returntype : Bio::EnsEMBL::Compara::GenomeDBAdaptor
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub adaptor{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'adaptor'} = $value;
   }
   return $self->{'adaptor'};
}


=head2 assembly

  Arg [1]    : (optional) string
  Example    : $gdb->assembly('NCBI36');
  Description: Getter/Setter for the assembly type of this genome db.
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub assembly {
  my $self = shift;
  my $assembly = shift;

  if($assembly) {
    $self->{'assembly'} = $assembly;
  }
  return $self->{'assembly'};
}

=head2 assembly_default

  Arg [1]    : (optional) int
  Example    : $gdb->assembly_default(1);
  Description: Getter/Setter for the assembly_default of this genome db.
  Returntype : int
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub assembly_default {
  my $self = shift;
  my $boolean = shift;

  if(defined $boolean) {
    $self->{'assembly_default'} = $boolean;
  }
  $self->{'assembly_default'}='1' unless(defined($self->{'assembly_default'}));
  return $self->{'assembly_default'};
}

=head2 genebuild

  Arg [1]    : (optional) string
  Example    : $gdb->genebuild('2006-12-Ensembl');
  Description: Getter/Setter for the genebuild type of this genome db.
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub genebuild {
  my $self = shift;
  $self->{'genebuild'} = shift if (@_);
  $self->{'genebuild'}='' unless(defined($self->{'genebuild'}));
  return $self->{'genebuild'};
}


=head2 taxon_id

  Arg [1]    : (optional) int
  Example    : $gdb->taxon_id(9606);
  Description: Getter/Setter for the taxon id of the contained genome db
  Returntype : int
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub taxon_id {
  my $self = shift;
  my $taxon_id = shift;

  if(defined $taxon_id) {
    $self->{'taxon_id'} = $taxon_id;
  }
  return $self->{'taxon_id'};
}

=head2 taxon

  Description: uses taxon_id to fetch the NCBITaxon object
  Returntype : Bio::EnsEMBL::Compara::NCBITaxon object 
  Exceptions : if taxon_id or adaptor not defined
  Caller     : general
  Status     : Stable

=cut

sub taxon {
  my $self = shift;

  return $self->{'_taxon'} if(defined $self->{'_taxon'});

  unless (defined $self->taxon_id and $self->adaptor) {
    throw("can't fetch Taxon without a taxon_id and an adaptor");
  }
  my $ncbi_taxon_adaptor = $self->adaptor->db->get_NCBITaxonAdaptor;
  $self->{'_taxon'} = $ncbi_taxon_adaptor->fetch_node_by_taxon_id($self->{'taxon_id'});
  return $self->{'_taxon'};
}


=head2 locator

  Arg [1]    : string
  Description: Returns a string which describes where the external genome (ensembl core)
               database base is located. Locator format is:
               "Bio::EnsEMBL::DBSQL::DBAdaptor/host=ecs4port=3351;user=ensro;dbname=mus_musculus_core_20_32"
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub locator {
  my $self = shift;
  $self->{'locator'} = shift if (@_);
  $self->{'locator'}='' unless(defined($self->{'locator'}));
  return $self->{'locator'};
}

=head2 connect_to_genome_locator

  Arg [1]    : string
  Description: uses the locator string to connect to the external genome database
  Returntype : DBConnection/DBAdaptor defined in locator string
              (usually a Bio::EnsEMBL::DBSQL::DBAdaptor)
              return undef if locator undefined or unable to connect
  Exceptions : none
  Caller     : internal private method 
  Status     : Stable

=cut

sub connect_to_genome_locator
{
  my $self = shift;

  return undef if($self->locator eq '');

  my $genomeDBA = undef;
  eval {$genomeDBA = Bio::EnsEMBL::DBLoader->new($self->locator); };
  return undef unless($genomeDBA);
  return $genomeDBA;
}

=head2 has_consensus

  Arg[1]     : Bio::EnsEMBL::Compara::GenomeDB $genomedb
  Arg[2]     : int $method_link_id
  Example    : none
  Description: none
  Returntype : int
  Exceptions : throw if no $con_gdb passed in or $con_gdb is not a 
               Bio::EnsEMBL::Compara::GenomeDB or $con_gdb is the same as $self
  Caller     : general
  Status     : Stable

=cut

sub has_consensus {
  my ($self,$con_gdb,$method_link_id) = @_;

  # sanity check on the GenomeDB passed in
  if( !defined $con_gdb || !$con_gdb->isa("Bio::EnsEMBL::Compara::GenomeDB")) {
    throw("No query genome specified or query is not a GenomeDB obj");
  }
  # and check that you are not trying to compare the same GenomeDB
  if ( $con_gdb eq $self ) {
    throw("Trying to return consensus / query information from the same db");
  }

  my $consensus = $self->adaptor->check_for_consensus_db( $self, $con_gdb,$method_link_id);

  return $consensus;
}



=head2 has_query

  Arg[1]     : Bio::EnsEMBL::Compara::GenomeDB $genomedb
  Arg[2]     : int $method_link_id
  Example    : none
  Description: none
  Returntype : int
  Exceptions : throw if no $query_gdb passed in or $query_gdb is not a 
               Bio::EnsEMBL::Compara::GenomeDB or $query_gdb is the same as 
               $self
  Caller     : general
  Status     : Stable

=cut

sub has_query {
  my ($self,$query_gdb,$method_link_id) = @_;

  # sanity check on the GenomeDB passed in
  if( !defined $query_gdb || 
      !$query_gdb->isa("Bio::EnsEMBL::Compara::GenomeDB")) {
    throw("No consensus genome specified or query is not a GenomeDB object");
  }
  # and check that you are not trying to compare the same GenomeDB
  if ( $query_gdb eq $self ) {
    throw("Trying to return consensus / query information from the same db");
  }

  my $query = $self->adaptor->check_for_query_db( $self, $query_gdb ,$method_link_id);

  return $query;
}



=head2 linked_genomes_by_method_link_id

  Arg[1]     : int $method_link_id
  Example    : none
  Description: none
  Returntype : int
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub linked_genomes_by_method_link_id {
  my ( $self,$method_link_id ) = @_;

  my $links = $self->adaptor->get_all_db_links( $self , $method_link_id);

  return $links;
}


1;
