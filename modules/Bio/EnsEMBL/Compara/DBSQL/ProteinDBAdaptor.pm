

#
# Ensembl module for Bio::EnsEMBL::Compara::DBSQL::ProteinDBAdaptor
#
# Cared for by EnsEMBL <www.ensembl.org>
#
# Copyright GRL
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::ProteinDBAdaptor - DESCRIPTION of Object

=head1 SYNOPSIS

Give standard usage here

=head1 DESCRIPTION

Describe the object here

=head1 AUTHOR - Ensembl

This modules is part of the Ensembl project http://www.ensembl.org

=head1 CONTACT

Email ensembl-dev@ebi.ac.uk

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::DBSQL::ProteinDBAdaptor;
use vars qw(@ISA);
use strict;


use Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Compara::ProteinDB;

@ISA = qw(Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor);


sub new {
    my ($class,@args) = @_;

    my $self = Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor->new(@args);

    bless $self,$class;

    $self->{'_cache'} = {};

    return $self;
}

    
=head2 fetch_by_dbID

 Title   : fetch_by_dbID
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub fetch_by_dbID{
   my ($self,$dbid) = @_;

   if( !defined $dbid) {
       $self->throw("Must fetch by dbid");
   }

   if( defined $self->{'_cache'}->{$dbid} ) {
       return $self->{'_cache'}->{$dbid};
   }

   my $sth = $self->prepare("select name,locator from protein_db where protein_db_id = $dbid");
   $sth->execute;

   my ($name,$locator) = $sth->fetchrow_array();

   if( !defined $name) {
       $self->throw("No database with this dbID");
   }

   my $pdb = Bio::EnsEMBL::Compara::ProteinDB->new();
   $pdb->name($name);
   $pdb->locator($locator);
   $pdb->dbID($dbid);
   $self->{'_cache'}->{$dbid} = $pdb;

   return $pdb;
}

=head2 fetch_by_species_tag

 Title   : fetch_by_species_tag
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub fetch_by_species_tag{
   my ($self,$tag) = @_;

   my $sth = $self->prepare("select genome_db_id from genome_db where name = '$tag'");
   $sth->execute;

   my ($id) = $sth->fetchrow_array();

   if( !defined $id ) {
       $self->throw("No species with this tag $tag");
   }

   return $self->fetch_by_dbID($id);

}

=head2 store

 Title   : store
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub store{
   my ($self,$pdb) = @_;

   if( !defined $pdb || !ref $pdb || !$pdb->isa('Bio::EnsEMBL::Compara::ProteinDB') ) {
       $self->throw("Must have proteindb arg [$pdb]");
   }

   if( !defined $pdb->name || !defined $pdb->locator ) {
       $self->throw("genome db must have a name and a locator");
   }
   my $name = $pdb->name;
   my $locator = $pdb->locator;

   my $query = "Select protein_db_id from protein_db where name = '$name' and locator = '$locator'";
   my $sth = $self->prepare($query);
   $sth->execute;
 
   my $dbID = $sth->fetchrow_array();

   if ($dbID) {
      $pdb->dbID($dbID);
   }else{
      my $sth = $self->prepare("insert into protein_db(name,locator) values ('$name','$locator')");
 
      $sth->execute();
 
      $pdb->dbID($sth->{'mysql_insertid'});
   }

   $pdb->dbID($sth->{'mysql_insertid'});

   return $pdb->dbID;
}


=head2 store_DBAdaptor
 
 Title   : store_DBAdaptor
 Usage   :
 Function:
 Example :
 Returns :
 Args    :
 
 
=cut
 
sub store_DBAdaptor{
   my ($self,$dba) = @_;

 
   $self->throw("Trying to store DBAdaptor without valid arg") unless defined $dba;
 
   my $name = $dba->dbname;
   my $locator = ref($dba)."/host=".$dba->host.";port=;dbname=$name;user=".$dba->username.";pass=".$dba->password;
 
    my $query = "Select protein_db_id from protein_db where name = '$name' and locator = '$locator'";
   my $sth = $self->prepare($query);
   $sth->execute;
 
   my $dbID = $sth->fetchrow_array();
 
   if ($dbID) {
      return $dbID;
   }else{
      my $sth = $self->prepare("insert into protein_db(name,locator) values ('$name','$locator')");
      $sth->execute();
      return ($sth->{'mysql_insertid'});
   }
 
 
};


