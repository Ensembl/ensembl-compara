
#
# BioPerl module for DB::Clone
#
# Cared for by EnsEMBL (www.ensembl.org)
#
# Copyright GRL and EBI
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::DBSQL::CloneAdapor

=head1 SYNOPSIS

    # $db is Bio::EnsEMBL::DB::DBAdaptor

    my $da= Bio::EnsEMBL::DBSQL::SyntenyAdaptor->new($obj);
    my $syn =$da->fetch($id);

    @contig = $syn->get_protein_matches_per_chromosome();

=head1 DESCRIPTION

Gets info from DB from the database tables which are used for synteny - Kailan's tables

=head1 CONTACT

Tania Oh (tania@fugu-sg.org)


=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::DBSQL::SyntenyHitAdaptor;
use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::DBSQL::BaseAdaptor;        # need this so that I don't need a new method
use Bio::EnsEMBL::Compara::Synteny_Hit;
@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);




=head2 fetch_protein_match_fd_on_fugu_n_chr

 Title   : fetch_protein_match_fd_on_fugu_n_chr
 Usage   : fetch_protein_match_fd_on_fugu_n_chr('1', '1') where 1 refers to 
           scaf, chr respectively
 Function: gets all the proteins which are found on both chr and scaffold .
           eg. get protein A, B coz found on both Chr 1 and scaffold 1
 Example :
 Returns : an array of SyntenyHit
 Args    :


=cut

sub fetch_protein_match_fd_on_fugu_n_chr{
    my ($self,$scaffold,$chr) = @_;


    if( !defined $scaffold) {$self->throw("Don't have $scaffold to retrieve proteins");}
    if( !defined $chr) {$self->throw("Don't have $chr to retrieve proteins");}

	
    my $sth = $self->prepare("select dnafrag_id from dnafrag where name = '$scaffold'");
    $sth->execute();
    my ($scaffold_id) =$sth->fetchrow_array;
    #much faster to pull the dnafrag id first before the select statement below
    my $sth2 = $self->prepare("select dnafrag_id from dnafrag where name = '$chr'");
    $sth2->execute();
    my ($chr_id) = $sth2->fetchrow_array;
    #print STDERR "chr: $chr, chr_id: $chr_id\n";

    my $sql = "select distinct g1.align_id
                               from genomic_align_block g1, genomic_align_block g2
                               where g1.align_id = g2.align_id
                               and g1.dnafrag_id = $chr_id
                               and g2.dnafrag_id = '$scaffold_id'";

    #print STDERR $sql;
    my $sth3 = $self->prepare ($sql);
=headj
    my $sth3 = $self->prepare("select distinct g1.align_id 
                               from genomic_align_block g1, genomic_align_block g2 
                               where g1.align_id = g2.align_id 
                               and g1.dnafrag_id = $chr_id  
                               and g2.dnafrag_id = $scaffold_id;");
=cut

    $sth3->execute();
    my @synfeatures;
    while ( my ($aid) = $sth3->fetchrow_array()){

 	 my $obj = Bio::EnsEMBL::Compara::Synteny_Hit->new( -align_id  => $aid,
							    -dnafrag_id=> $chr_id
                                                          );

         if ($obj) {
             push @synfeatures, $obj;
         }
         
         my $obj2 = Bio::EnsEMBL::Compara::Synteny_Hit->new( -align_id  => $aid,
                                                            -dnafrag_id=> $scaffold_id,
                                                           );
         if ($obj2) {
             push @synfeatures, $obj2;
         }
     }
   
    if (scalar @synfeatures){
       #returning refernce to array, less overhead
    	return \@synfeatures;
    }else{
  		return undef;
	 }
}


sub store{
    my ($self, $hit, $dbID) = @_;
    if (!defined $hit){
       return undef; 
    }	
    
    if (!defined $dbID){
       return undef;
    }
    
    #store info into synteny_cluster table
    my $align_id =  $hit->align_id;
    my $dnafrag_id= $hit->dnafrag_id;
     
    if (!defined $align_id){
       return undef;
    }
    
    if (!defined $dnafrag_id){
        print "going homt\n";
        return undef;
    }


    my $sth = $self->prepare("insert into synteny_cluster values ($dbID, $align_id, $dnafrag_id)");
    $sth->execute();
    
	
} 

1;
