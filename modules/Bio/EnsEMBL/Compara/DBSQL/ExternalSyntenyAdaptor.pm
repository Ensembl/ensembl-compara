
#
# Ensembl module for Bio::EnsEMBL::Compara::DBSQL::ExternalFeatureView
#
# Cared for by Ewan Birney <birney@ebi.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::ExternalFeatureView - View from one species of a comparative database

=head1 SYNOPSIS

   
   $syn = Bio::EnsEMBL::Compara::DBSQL::ExternalSyntenyAdaptor->new(
								  -compara => $comparadb,
								  -species => 'Homo_sapiens');

   $standard_db_adaptor->add_ExternalSyntenyAdaptor($view);


=head1 DESCRIPTION

Provides a view of this comparative database from one species
perspective, giving out features (AlignBlocks) in
ExternalFeatureFactory manner

=head1 AUTHOR  
tania tania@fugu-sg.org

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::DBSQL::ExternalSyntenyAdaptor;
use Bio::EnsEMBL::SeqFeature;
use DBI;

use vars qw(@ISA);
use strict;

#DBAdaptor checks that it's a ExternalFeatureFactory so need to implement this
@ISA = qw(Bio::EnsEMBL::Compara::DBSQL::DBAdaptor);



sub new {
    my($class,@args) = @_;
    my $self;
    $self = {};
    bless $self, $class;

    my ($db,$host,$port,$driver,$user,$password) =
        $self->_rearrange([qw(DBNAME
                              HOST
                              PORT
                              DRIVER
                              USER
                              PASS
                              )],@args);

    $db   || $self->throw("Database object must have a database name");
    $user || $self->throw("Database object must have a user");

    $driver ||= 'mysql';
    $host ||= 'localhost';
    $port ||= 3306;

    my $dsn = "DBI:$driver:database=$db;host=$host;port=$port";
    my $dbh = DBI->connect("$dsn","$user",$password);

    $dbh || $self->throw("Could not connect to database $db user $user using [$dsn] as a locator");

    $self->_db_handle($dbh);

    return $self; # success - we hope!

}


=head2 get_Ensembl_SeqFeatures_clone_web

 Title   : get_Ensembl_SeqFeatures_clone_web
 Usage   :
 Function:
 Example :
 Returns : a list of lightweight SeqFeature features.
 Args    : scalar in nucleotides (should default to 50)
           array of accession.version numbers

=cut


sub get_Ensembl_SeqFeatures_clone_web {
    my ($self,$glob,@acc) = @_;

    if (! defined $glob) {
        $self->throw("Need to call get_Ensembl_SeqFeatures_clone_web with a globbing parameter and a list of clones");
    }
    if (scalar(@acc) == 0) {
        $self->throw("Calling get_Ensembl_SeqFeatures_clone_web with empty list of clones!\n");
    }

    #lists of synclusters to be returned
    my @synclusters;
NEXT:    foreach my $a (@acc) {
        #$a is in the form Scaffold_6764.0
 
        $a =~ /(\S+)\.(\d+)/;
        my $scaf = $1.".1";
       
         #using no. is faster than using string to search sql tables
         my $sth = $self->prepare("select dnafrag_id from dnafrag where name = '$scaf'");
         $sth->execute();
         my ($dnafrag_id) = $sth->fetchrow_array;

        if (!$dnafrag_id) {next NEXT};


        my $sth2 = $self->prepare ("select seq_start, seq_end from synteny_region where dnafrag_id = $dnafrag_id");  
        $sth2->execute();

       while (my ($start,$end)  = $sth2->fetchrow_array()){
       
           if (!$start && !$end) {next NEXT};

           my $strand = 1; 
           if ($start> $end) { $strand = -1;}
           my $syn = new Bio::EnsEMBL::SeqFeature
					(-seqname => $scaf,
				       -start   => $start,
				       -end     =>$end, 
				       -strand  => $strand,
				       -source_tag => 'synteny',
				       -primary_tag => 'prediction',
					);


           push(@synclusters, $syn);
        }                               # if ! $seen{$key}
    }

    return @synclusters;
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

   $obj->_unlock_tables();

   if( $obj->{'_db_handle'} ) {
       $obj->{'_db_handle'}->disconnect;
       $obj->{'_db_handle'} = undef;
   }
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

   return $self->_db_handle->prepare($string) if defined $self->_db_handle;
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


1;

