

#
# Ensembl module for Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor
#
# Cared for by Ewan Birney <birney@ebi.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor - DESCRIPTION of Object

=head1 SYNOPSIS

Give standard usage here

=head1 DESCRIPTION

Describe the object here

=head1 AUTHOR - Ewan Birney

This modules is part of the Ensembl project http://www.ensembl.org

Email birney@ebi.ac.uk

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor;
use vars qw(@ISA);
use strict;


use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Compara::GenomeDB;

@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);



    
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

   my $gdb = undef;

   # check to see whether all the GenomeDBs haev already been created
   if ( $self->{'_GenomeDB_cache'}) {
     if ( defined $self->{'cache'}->{$dbid}) {
       return $self->{'_cache'}->{$dbid};
     }
     else {  # return undef if fed a bogus dbID
       return undef;
     }
   }
   # otherwise go and create them
   else {
     $gdb = $self->create_GenomeDBs($dbid);
   }

   return $gdb;
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

   my $sth = $self->prepare("
     SELECT genome_db_id 
     FROM genome_db 
     WHERE name = '$tag'
   ");
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
   my ($self,$gdb) = @_;

   if( !defined $gdb || !ref $gdb || !$gdb->isa('Bio::EnsEMBL::Compara::GenomeDB') ) {
       $self->throw("Must have genomedb arg [$gdb]");
   }

   if( !defined $gdb->name || !defined $gdb->locator ) {
       $self->throw("genome db must have a name and a locator");
   }
   my $name = $gdb->name;
   my $locator = $gdb->locator;

   my $sth = $self->prepare("
      SELECT genome_db_id 
      FROM genome_db 
      WHERE name = '$name' and locator = '$locator'
   ");
   $sth->execute;

   my $dbID = $sth->fetchrow_array();

   if ($dbID) {
      $gdb->dbID($dbID);
   }else{ 
      my $sth = $self->prepare("
        INSERT into genome_db (name,locator) 
        VALUES ('$name','$locator')
      ");

      $sth->execute();

      $gdb->dbID($sth->{'mysql_insertid'});
   }

   return $gdb->dbID;
}


sub create_GenomeDBs {
  my ( $self, $dbid ) = @_;

  # grab all the possible species databases in the genome db table
  my $sth = $self->prepare("
     SELECT * 
     FROM genome_db 
   ");
   $sth->execute;

  # build a genome db for each species
  while ( my @db_row = $sth->fetchrow_array() ) {
    my ($dbid, $name, $locator) = @db_row;

    my $gdb = Bio::EnsEMBL::Compara::GenomeDB->new();
    $gdb->name($name);
    $gdb->locator($locator);
    $gdb->dbID($dbid);
    $self->{'_cache'}->{$dbid} = $gdb;
  }

  $self->{'_GenomeDB_cache'} = 1;
  
  return $self->{'_cache'}->{$dbid};
}



1;
