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

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use vars qw(@ISA);
use strict;


use Bio::Root::RootI;
use Bio::EnsEMBL::DB::ObjI;

use Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor;
use DBI;

@ISA = qw(Bio::Root::RootI Bio::EnsEMBL::DB::ObjI);

sub new {
  my($pkg, @args) = @_;

  my $self = bless {}, $pkg;
  
  my (
      $db,
      $host,
      $driver,
      $user,
      $pass,
      $password,
      $port,
      ) = $self->_rearrange([qw(
				DBNAME
				HOST
				DRIVER
				USER
				PASS
				PASSWORD
				PORT
				)],@args);

  $db   || $self->throw("Database object must have a database name");
  $user || $self->throw("Database object must have a user");
  

  if( defined $pass && ! defined $password ) {
    $password = $pass;
  }

  if( ! $driver ) {
        $driver = 'mysql';
    }
  if( ! $host ) {
      $host = 'localhost';
  }
  if ( ! $port ) {
      $port = undef;
  }
  
  my $dsn = "DBI:$driver:database=$db;host=$host;port=$port";
  
  
  my $dbh = DBI->connect("$dsn","$user",$password, {RaiseError => 1});
  
  $dbh || $self->throw("Could not connect to database $db user $user using [$dsn] as a locator");
  
  
  $self->_db_handle($dbh);
  
  $self->username( $user );
  $self->host( $host );
  $self->dbname( $db );
  $self->password( $password);


  return $self; # success - we hope!
}


=head2 get_GenomeDBAdaptor

 Title   : get_GenomeDBAdaptor
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub get_GenomeDBAdaptor{
   my ($self) = @_;

   if( !defined $self->{'_genomedb_adaptor'} ) {
       require Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor;
       $self->{'_genomedb_adaptor'}  = Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor->new($self);
   }
   return $self->{'_genomedb_adaptor'};
}

=head2 get_ProteinDBAdaptor

 Title   : get_ProteinDBAdaptor
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub get_ProteinDBAdaptor{
   my ($self) = @_;

   if( !defined $self->{'_proteindb_adaptor'} ) {
       require Bio::EnsEMBL::Compara::DBSQL::ProteinDBAdaptor;
       $self->{'_proteindb_adaptor'}  = Bio::EnsEMBL::Compara::DBSQL::ProteinDBAdaptor->new($self);
   }
   return $self->{'_proteindb_adaptor'};
}

=head2 get_ProteinAdaptor

 Title   : get_ProteinAdaptor
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub get_ProteinAdaptor{
   my ($self) = @_;

   if( !defined $self->{'_protein_adaptor'} ) {
       require Bio::EnsEMBL::Compara::DBSQL::ProteinAdaptor;
       $self->{'_protein_adaptor'}  = Bio::EnsEMBL::Compara::DBSQL::ProteinAdaptor->new($self);
   }
   return $self->{'_protein_adaptor'};
}



=head2 get_DnaFragAdaptor

 Title   : get_DnaFragAdaptor
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub get_DnaFragAdaptor{
   my ($self) = @_;

   if( !defined $self->{'_dnafrag_adaptor'} ) {
       require Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor;
       $self->{'_dnafrag_adaptor'}  = Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor->new($self);
   }
   return $self->{'_dnafrag_adaptor'};
}


=head2 get_FamilyAdaptor

 Title	 : get_FamilyAdaptor
 Usage	 :
 Function:
 Example :
 Returns :
 Args	 :


=cut

sub get_FamilyAdaptor{
   my ($self) = @_;

   if( !defined $self->{'_family_adaptor'} ) {
	require Bio::EnsEMBL::Compara::DBSQL::FamilyAdaptor;
	$self->{'_family_adaptor'}  = Bio::EnsEMBL::Compara::DBSQL::FamilyAdaptor->new($self);
   }
   return $self->{'_family_adaptor'};
}


=head2 get_GenomicAlignAdaptor

 Title   : get_GenomicAlignAdaptor
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub get_GenomicAlignAdaptor{
   my ($self) = @_;

   if( !defined $self->{'_genomicalign_adaptor'} ) {
       require Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor;
       $self->{'_genomicalign_adaptor'}  = Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor->new($self);
   }
   return $self->{'_genomicalign_adaptor'};
}


=head2 get_HomologyAdaptor

 Title   : get_HomologyAdaptor
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub get_HomologyAdaptor{
   my ($self) = @_;

   if( !defined $self->{'_homology_adaptor'} ) {
       require Bio::EnsEMBL::Compara::DBSQL::HomologyAdaptor;
       $self->{'_homology_adaptor'}  = Bio::EnsEMBL::Compara::DBSQL::HomologyAdaptor->new($self);
   }
   return $self->{'_homology_adaptor'};
}


=head2 get_SyntenyRegionAdaptor

 Title   : get_SyntenyRegionAdaptor
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub get_SyntenyRegionAdaptor{
   my ($self) = @_;

   if( !defined $self->{'_genomicalign_adaptor'} ) {
       require Bio::EnsEMBL::Compara::DBSQL::SyntenyRegionAdaptor;
       $self->{'_genomicalign_adaptor'}  = Bio::EnsEMBL::Compara::DBSQL::SyntenyRegionAdaptor->new($self);
   }
   return $self->{'_genomicalign_adaptor'};
}

# only the get part of the 3 functions should be considered public

sub dbname {
  my ($self, $arg ) = @_;
  ( defined $arg ) &&
    ( $self->{_dbname} = $arg );
  $self->{_dbname};
}

sub username {
  my ($self, $arg ) = @_;
  ( defined $arg ) &&
    ( $self->{_username} = $arg );
  $self->{_username};
}

sub host {
  my ($self, $arg ) = @_;
  ( defined $arg ) &&
    ( $self->{_host} = $arg );
  $self->{_host};
}

sub password {
  my ($self, $arg ) = @_;
  ( defined $arg ) &&
    ( $self->{_password} = $arg );
  $self->{_password};
}


=head2 prepare

 Title   : prepare
 Usage   : $sth = $dbobj->prepare("select seq_start,seq_end from feature where analysis = \" \" ");
 Function: prepares a SQL statement on the DBI handle

           If the debug level is greater than 10, provides information into the
           DummyStatement object
 Example :
 Returns : A DBI statement handle object
 Args    : a SQL string


=cut

sub prepare {
   my ($self,$string) = @_;

   if( ! $string ) {
       $self->throw("Attempting to prepare an empty SQL query!");
   }
   if( !defined $self->_db_handle ) {
      $self->throw("Database object has lost its database handle! getting otta here!");
   }

   # should we try to verify the string?

   return $self->_db_handle->prepare($string);
}


=head2 _db_handle

 Title   : _db_handle
 Usage   : $obj->_db_handle($newval)
 Function: 
 Example : 
 Returns : value of _db_handle
 Args    : newvalue (optional)


=cut

sub _db_handle{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'_db_handle'} = $value;
    }
    return $self->{'_db_handle'};

}


=head2 DESTROY

 Title   : DESTROY
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub DESTROY {
   my ($obj) = @_;

   if( $obj->{'_db_handle'} ) {
       $obj->{'_db_handle'}->disconnect;
       $obj->{'_db_handle'} = undef;
   }
   $obj->deleteObj();

}


=head2 deleteObj

 Title   : deleteObj
 Usage   : $obj->deleteObj
 Function: removes memory cycles. Probably triggered by Root deleteObj
 Returns : 
 Args    : none


=cut

sub deleteObj {
  my $self = shift;
  my @dummy = values %{$self};
  foreach my $key ( keys %$self ) {
    delete $self->{$key};
  }
  foreach my $obj ( @dummy ) {
    eval {
      $obj->deleteObj;
    }
  }
}


1;
