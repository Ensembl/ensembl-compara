#
# BioPerl module for DBSQL::Obj
#
# Cared for by Ewan Birney <birney@sanger.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor

=head1 SYNOPSIS

    $db = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
        -user   => 'root',
        -dbname => 'pog',
        -host   => 'caldy',
        -driver => 'mysql',
        );


=head1 DESCRIPTION

This object represents the handle for a comparative DNA alignment database

=head1 CONTACT

Post questions the the EnsEMBL developer list: <ensembl-dev@ebi.ac.uk>

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::DBSQL::DBAdaptor;

#@ISA = qw( Bio::EnsEMBL::DBSQL::DBConnection );
@ISA = qw( Bio::EnsEMBL::DBSQL::DBAdaptor );



=head2 new

  Arg [..]   : list of named arguments.  See Bio::EnsEMBL::DBConnection.
               [-CONF_FILE] optional name of a file containing configuration
               information for comparas genome databases.  If databases are
               not added in this way, then they should be added via the
               method add_DBAdaptor. An example of the conf file can be found
               in ensembl-compara/modules/Bio/EnsEMBL/Compara/Compara.conf.example
  Example    :  $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(
						    -user   => 'root',
						    -dbname => 'pog',
						    -host   => 'caldy',
						    -driver => 'mysql',
                                                    -conf_file => 'conf.pl');
  Description: Creates a new instance of a DBAdaptor for the compara database.
  Returntype : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor
  Exceptions : none
  Caller     : general

=cut

sub new {
  my ($class, @args) = @_;

  #call superclass constructor; this may actually return a container
  my $container = $class->SUPER::new(@args);

  my $self;
  if($container->isa('Bio::EnsEMBL::Container')) {
    $self = $container->_obj;
  } else {
    $self = $container;
  }

  my ($conf_file) = $self->_rearrange(['CONF_FILE'], @args);

  $self->{'genomes'} = {};

  if($conf_file) {
    #read configuration file from disk
    my @conf = @{do $conf_file};

    foreach my $genome (@conf) {
      my ($species, $assembly, $db_hash) = @$genome;
      my $db;

      my $module = $db_hash->{'module'};
      my $mod = $module;

      eval {
	# require needs /'s rather than colons
	if ( $mod =~ /::/ ) {
	  $mod =~ s/::/\//g;
	}
	require "${mod}.pm";

	$db = $module->new(-dbname => $db_hash->{'dbname'},
			   -host   => $db_hash->{'host'},
			   -user   => $db_hash->{'user'},
			   -pass   => $db_hash->{'pass'},
			   -port   => $db_hash->{'port'},
			   -driver => $db_hash->{'driver'});
      };

      if($@) {
	$self->throw("could not load module specified in configuration " .
		     "file:$@");
      }

      unless($db && ref $db && $db->isa('Bio::EnsEMBL::DBSQL::DBConnection')) {
	$self->throw("[$db] specified in conf file is not a " .
		     "Bio::EnsEMBL::DBSQL::DBConnection");
      }

      #compara should hold onto the actual container objects
      #if($db->isa('Bio::EnsEMBL::DBSQL::Container')) {
      #	$db = $db->_obj;
      #      }

      $self->{'genomes'}->{"$species:$assembly"} = $db;
    }
  }

  #we want to return the container not the contained object
  return $container;
}



=head2 add_db_adaptor

  Arg [1]    : Bio::EnsEMBL::DBSQL::DBConnection
  Example    : $compara_db->add_db_adaptor($homo_sapiens_db);
  Description: Adds a genome-containing database to compara.  This database
               can be used by compara to obtain sequence for a genome on
               on which comparative analysis has been performed.  The database
               adaptor argument must define the get_MetaContainer argument
               so that species name and assembly type information can be
               extracted from the database.
  Returntype : none
  Exceptions : Thrown if the argument is not a Bio::EnsEMBL::DBConnection
               or if the argument does not implement a get_MetaContainer
               method.
  Caller     : general

=cut

sub add_db_adaptor {
  my ($self, $dba) = @_;

  unless($dba && ref $dba && $dba->isa('Bio::EnsEMBL::DBSQL::DBConnection')) {
    $self->throw("dba argument must be a Bio::EnsEMBL::DBSQL::DBConnection\n" .
		 "not a [$dba]");
  }

  #compara should hold onto the actual container objects...
  #  if($dba->isa('Bio::EnsEMBL::Container')) {
  #    $dba = $dba->_obj;
  #  }

  my $mc = $dba->get_MetaContainer;
  my $csa = $dba->get_CoordSystemAdaptor;
  
  my $species = $mc->get_Species->binomial;
  my $assembly = $csa->fetch_top_level->version;

  $self->{'genomes'}->{"$species:$assembly"} = $dba;
}



=head2 get_db_adaptor

  Arg [1]    : string $species
               the name of the species to obtain a genome DBAdaptor for.
  Arg [2]    : string $assembly
               the name of the assembly to obtain a genome DBAdaptor for.
  Example    : $hs_db = $db->get_db_adaptor('Homo sapiens','NCBI_30');
  Description: Obtains a DBAdaptor for the requested genome if it has been
               specified in the configuration file passed into this objects
               constructor, or subsequently added using the add_db_adaptor
               method.  If the DBAdaptor is not available (i.e. has not
               been specified by one of the abbove methods) undef is returned.
  Returntype : Bio::EnsEMBL::DBSQL::DBConnection
  Exceptions : none
  Caller     : Bio::EnsEMBL::Compara::GenomeDBAdaptor

=cut

sub get_db_adaptor {
  my ($self, $species, $assembly) = @_;

  unless($species && $assembly) {
    $self->throw("species and assembly arguments are required\n");
  }

  return $self->{'genomes'}->{"$species:$assembly"};
}



=head2 get_SyntenyAdaptor

  Arg [1]    : none
  Example    : $sa = $dba->get_SyntenyAdaptor
  Description: Retrieves a synteny adaptor for this database.
  Returntype : Bio::EnsEMBL::Compara::DBSQL::SyntenyAdaptor
  Exceptions : none
  Caller     : general

=cut

sub get_SyntenyAdaptor{
   my ($self) = @_;

   return $self->_get_adaptor("Bio::EnsEMBL::Compara::DBSQL::SyntenyAdaptor");
}


=head2 get_GenomeDBAdaptor

  Arg [1]    : none
  Example    : $gdba = $dba->get_GenomeDBAdaptor
  Description: Retrieves an adaptor that can be used to obtain GenomeDB
               objects from this compara database.
  Returntype : Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor
  Exceptions : none
  Caller     : general

=cut

sub get_GenomeDBAdaptor{
   my ($self) = @_;

   return $self->_get_adaptor("Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor");
}



=head2 get_DnaFragAdaptor

  Arg [1]    : none
  Example    : $dfa = $dba->get_DnaFragAdaptor
  Description: Retrieves an adaptor that can be used to obtain DnaFrag objects
               from this compara database.
  Returntype : none
  Exceptions : none
  Caller     : general

=cut

sub get_DnaFragAdaptor{
   my ($self) = @_;

   return $self->_get_adaptor("Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor");
}



=head2 get_GenomicAlignAdaptor

  Arg [1]    : none
  Example    : $gaa = $dba->get_GenomicAlignAdaptor
  Description: Retrieves an adaptor for this database which can be used
               to obtain GenomicAlign objects
  Returntype : Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor
  Exceptions : none
  Caller     : general

=cut

sub get_GenomicAlignAdaptor{
  my ($self) = @_;

  return
    $self->_get_adaptor("Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor");
}



=head2 get_HomologyAdaptor

  Arg [1]    : none
  Example    : $ha = $dba->get_HomologyAdaptor
  Description: Retrieves a HomologyAdaptor for this database
  Returntype : Bio::EnsEMBL::Compara::DBSQL::HomologyAdaptor
  Exceptions : general
  Caller     : none

=cut

sub get_HomologyAdaptor{
   my ($self) = @_;

   return $self->_get_adaptor("Bio::EnsEMBL::Compara::DBSQL::HomologyAdaptor");
}



=head2 get_SyntenyRegionAdaptor

  Arg [1]    : none
  Example    : $sra = $dba->get_SyntenyRegionAdaptor
  Description: Retrieves a SyntenyRegionAdaptor for this database
  Returntype : Bio::EnsEMBL::Compara::DBSQL::SyntenyRegionAdaptor
  Exceptions : none
  Caller     : general

=cut

sub get_SyntenyRegionAdaptor{
   my ($self) = @_;

   return 
     $self->_get_adaptor("Bio::EnsEMBL::Compara::DBSQL::SyntenyRegionAdaptor");
}



=head2 get_DnaAlignFeatureAdaptor

  Arg [1]    : none
  Example    : $dafa = $dba->get_DnaAlignFeatureAdaptor;
  Description: Retrieves a DnaAlignFeatureAdaptor for this compara database
  Returntype : Bio::EnsEMBL::Compara::DBSQL::DnaAlignFeatureAdaptor
  Exceptions : none
  Caller     : general

=cut

sub get_DnaAlignFeatureAdaptor {
  my $self = shift;

  return 
   $self->_get_adaptor("Bio::EnsEMBL::Compara::DBSQL::DnaAlignFeatureAdaptor");
}



=head2 get_MetaContainer

  Arg [1]    : none
  Example    : $mc = $dba->get_MetaContainer
  Description: Retrieves an object that can be used to obtain meta information
               from the database.
  Returntype : Bio::EnsEMBL::DBSQL::MetaContainer
  Exceptions : none
  Caller     : general

=cut

sub get_MetaContainer {
    my $self = shift;

    return $self->_get_adaptor("Bio::EnsEMBL::DBSQL::MetaContainer");
}

=head2 get_FamilyAdaptor

  Arg [1]    : none
  Example    : $fa = $dba->get_FamilyAdaptor
  Description: Retrieves a FamilyAdaptor for this compara database
  Returntype : Bio::EnsEMBL::Compara::DBSQL::FamilyAdaptor
  Exceptions : none
  Caller     : general

=cut

sub get_FamilyAdaptor {
  my $self = shift;
  
  return $self->_get_adaptor("Bio::EnsEMBL::Compara::DBSQL::FamilyAdaptor" );
}

=head2 get_DomainAdaptor

  Arg [1]    : none
  Example    : $fa = $dba->get_DomainAdaptor
  Description: Retrieves a DomainAdaptor for this compara database
  Returntype : Bio::EnsEMBL::Compara::DBSQL::DomainAdaptor
  Exceptions : none
  Caller     : general

=cut

sub get_DomainAdaptor {
  my $self = shift;
  
  return $self->_get_adaptor("Bio::EnsEMBL::Compara::DBSQL::DomainAdaptor" );
}

=head2 get_SubsetAdaptor

  Arg [1]    : none
  Example    : $ma = $dba->get_SubsetAdaptor
  Description: Retrieves a MemberSetAdaptor for this compara database
  Returntype : Bio::EnsEMBL::Compara::DBSQL::SubssetAdaptor
  Exceptions : none
  Caller     : general

=cut

sub get_SubsetAdaptor {
  my $self = shift;
  
  return $self->_get_adaptor("Bio::EnsEMBL::Compara::DBSQL::SubsetAdaptor" );
}

=head2 get_MemberAdaptor

  Arg [1]    : none
  Example    : $ma = $dba->get_MemberAdaptor
  Description: Retrieves a MemberAdaptor for this compara database
  Returntype : Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor
  Exceptions : none
  Caller     : general

=cut

sub get_MemberAdaptor {
  my $self = shift;

  return $self->_get_adaptor("Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor" );
}

=head2 get_AttributeAdaptor

  Arg [1]    : none
  Example    : $ma = $dba->get_AttibuteAdaptor
  Description: Retrieves a AttributeAdaptor for this compara database
  Returntype : Bio::EnsEMBL::Compara::DBSQL::AttributeAdaptor
  Exceptions : none
  Caller     : general

=cut

sub get_AttributeAdaptor {
  my $self = shift;
  
  return $self->_get_adaptor("Bio::EnsEMBL::Compara::DBSQL::AttributeAdaptor" );
}

=head2 get_TaxonAdaptor

  Arg [1]    : none
  Example    : $ta = $dba->get_TaxonAdaptor
  Description: Retrieves a TaxonAdaptor for this compara database
  Returntype : Bio::EnsEMBL::Compara::DBSQL::TaxonAdaptor
  Exceptions : none
  Caller     : general

=cut

sub get_TaxonAdaptor {
  my $self = shift;
  
  return $self->_get_adaptor("Bio::EnsEMBL::Compara::DBSQL::TaxonAdaptor" );
}

sub deleteObj {
  my $self = shift;

  if($self->{'genomes'}) {
    foreach my $db (keys %{$self->{'genomes'}}) {
      delete $self->{'genomes'}->{$db};
    }
  }

  $self->SUPER::deleteObj;
}


1;

