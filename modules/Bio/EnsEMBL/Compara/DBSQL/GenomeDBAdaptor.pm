

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


use Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor;

@ISA = qw(Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor);


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

   my $sth = $self->prepare("select name,locator from genome_db where genome_db_id = $dbid");
   $sth->execute;

   my ($name,$locator) = $sth->fetchrow_array();

   if( !defined $name) {
       $self->throw("No database with this dbID");
   }

   my $gdb = Bio::EnsEMBL::Compara::GenomeDB->new();
   $gdb->name($name);
   $gdb->locator($locator);

   return $gdb;
}


1;
