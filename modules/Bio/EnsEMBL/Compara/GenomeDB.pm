=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::GenomeDB - DESCRIPTION of Object

=head1 SYNOPSIS
  use Bio::EnsEMBL::Compara::DnaFrag; 
  my $genome_db = Bio::EnsEMBL::Compara::GenomeDB->new();

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

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::GenomeDB;

use strict;

use Bio::EnsEMBL::DBLoader;
use Bio::EnsEMBL::Utils::Exception qw(warning deprecate throw);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);

use base ('Bio::EnsEMBL::Storable');        # inherit dbID(), adaptor() and new() methods


=head2 new

  Example :
    my $genome_db = Bio::EnsEMBL::Compara::GenomeDB->new();
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
    my $caller = shift @_;
    my $class = ref($caller) || $caller;

    my $self = $class->SUPER::new(@_);       # deal with Storable stuff

    my($db_adaptor, $name, $assembly, $taxon_id,  $genebuild) =
        rearrange([qw(DB_ADAPTOR NAME ASSEMBLY TAXON_ID GENEBUILD)], @_);

    $db_adaptor   && $self->db_adaptor($db_adaptor);
    $name         && $self->name($name);
    $assembly     && $self->assembly($assembly);
    $taxon_id     && $self->taxon_id($taxon_id);
    $genebuild    && $self->genebuild($genebuild);

    return $self;
}


=head2 new_fast

  Arg [1]    : hash reference $hashref
  Example    : 
  Description: This is an ultra fast constructor which requires knowledge of
               the objects internals to be used.
  Returntype : Bio::EnsEMBL::Compara::GenomeDB
  Exceptions : none
  Caller     : Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor
  Status     : Stable

=cut

sub new_fast {
  my $class = shift;
  my $hashref = shift;

  return bless $hashref, $class;
}


=head2 db_adaptor

  Arg [1]    : (optional) Bio::EnsEMBL::DBSQL::DBAdaptor $dba
               The DBAdaptor containing sequence information for the genome
               represented by this object.
  Example    : $gdb->db_adaptor($dba);
  Description: Getter/Setter for the DBAdaptor containing sequence 
               information for the genome represented by this object.
  Returntype : Bio::EnsEMBL::DBSQL::DBAdaptor
  Caller     : general
  Status     : Stable

=cut

sub db_adaptor {
    my ( $self, $dba ) = @_;

    if($dba) {
        $self->{'_db_adaptor'} = ($dba && $dba->isa('Bio::EnsEMBL::DBSQL::DBAdaptor'))
            ? $dba
            : undef;
    }

    unless($self->{'_db_adaptor'}) {
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
  $name =~ s/\b(\w)/\U$1/g;
  $name =~ s/\_/\ /g;
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

sub connect_to_genome_locator {
  my $self = shift;

  return undef if($self->locator eq '');

  my $genomeDBA = undef;
  eval {$genomeDBA = Bio::EnsEMBL::DBLoader->new($self->locator); };
  warn "The locator could not be loaded because: $@" if $@;
  return $genomeDBA;
}


=head2 toString

  Args       : (none)
  Example    : print $dbID->toString()."\n";
  Description: returns a stringified representation of the object
  Returntype : string

=cut

sub toString {
    my $self = shift;

    return ref($self).": dbID=".($self->dbID || '?')
        .", name='".$self->name
        ."', assembly='".$self->assembly
        ."', genebuild='".$self->genebuild
        ."', taxon_id='".$self->taxon_id
        ."', locator='".$self->locator
        ."'";
}


1;
