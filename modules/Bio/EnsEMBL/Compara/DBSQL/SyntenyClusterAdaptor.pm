
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


package Bio::EnsEMBL::Compara::DBSQL::SyntenyClusterAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor;

use vars qw(@ISA);
use strict;
@ISA = qw(Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor);

use Bio::EnsEMBL::DBSQL::BaseAdaptor;        # need this so that I don't need a new method
@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);




 
sub store {
    my ($self, $clus) = @_;
    
    my $syn_desc = "";
    my @syn_hits = @{$clus->syn_hits};
    if (! scalar @syn_hits){
       $self->throw("must have synteny hits");
    }
    
    if (!$clus->syn_desc){
        $clus->syn_desc("");
    }else{
       # $syn_desc = $clus->syn_desc;
       # $syn_desc = "\"$syn_desc\"";
       # print "syn_desc: $syn_desc\n";
    }

    my $syn_desc = $clus->syn_desc;
   
    #insert info in synteny description table
    #id of the synteny cluster 
    my $sql = "insert into synteny_description values (NULL, '$syn_desc');";
    my $sth = $self->prepare($sql);
    $sth->execute;
    
    #gets the last id inserted.. from the autoincrement
    my $dbID =  $clus->dbID($sth->{'mysql_insertid'});
    $clus->adaptor($self);
    
    #self->dbobj points to ComparaDBAdaptor 
    my $hit_adaptor = $self->db->get_SyntenyHitAdaptor;
    # store into synteny region table
    foreach my $hit(@syn_hits){
        $hit_adaptor->store($hit, $dbID);
    } 
    return $clus->dbID;
}

1;


