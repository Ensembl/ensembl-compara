
#
# EnsEMBL module for Bio::EnsEMBL::Compara::ConservedSegment
#
# Cared for by EnsEMBL (www.ensembl.org)
#
# Copyright GRL and EBI
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::ConservedSegment 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::ConservedSegment;
use vars qw(@ISA);
use strict;

# Object preamble - inheriets from Bio::Root::RootI

use Bio::Root::RootI;

@ISA = qw(Bio::Root::RootI);

sub new {
    my ($class,@args) = @_;

    my $self = {};
    bless $self,$class;
 
    $self->{'_protein_id_array'} = [];
    
    my ($dbID, $genome_db_id,$conserved_cluster_id,$seq_start,$seq_end,$intervening_genes,$dnafrag_id,$protein_ids,$adaptor) = 
    $self->_rearrange([qw(	DBID
                            GENOMEDB_ID
                            CONSERVED_CLUSTER_ID
                            SEQ_START
                            SEQ_END
                            INTERVENING_GENES
                            DNAFRAG_ID
                            PROTEIN_IDS
                            ADAPTOR)],@args);
    
    
    if (defined $dbID){
      $self->dbID($dbID);
    }

    if (defined $genome_db_id){
      $self->genome_db_id($genome_db_id);
    }


    if (defined $seq_start){
      $self->seq_start($seq_start);
    }else {
      $self->throw("Conserved Segment must have a seq_start");
    }

    if (defined $seq_end){
      $self->seq_end($seq_end);
    }else {
      $self->throw("Conserved Segment must have a seq_end");
    }

    if (defined $dnafrag_id){
      $self->dnafrag_id($dnafrag_id);
    }else {
      $self->throw("Conserved Segment must have a dnafrag_id");
    }

    if (defined @{$protein_ids}){
      foreach my $id (@{$protein_ids}){
         $self-add_Protein_id ($id);
      }
    }

    if (defined $intervening_genes){
      $self->intervening_genes($intervening_genes);
	}

    if (defined $adaptor){
      $self->adaptor($adaptor);
	}
    
    return $self;
}


=head2 dbID

 Title   : dbID
 Usage   : $obj->dbID($newval)
 Function:
 Returns : value of dbID
 Args    : newvalue (optional)

=cut

sub dbID {
   my $self = shift;
   if( @_ ) {
      my $value = shift;
      $self->{'dbID'} = $value;
   }
   return $self->{'dbID'};

}

=head2 genome_db_id

 Title   : genome_db_id
 Usage   : $obj->genome_db_id($newval)
 Function:
 Returns : value of genome_db_id, reference id to another database
 Args    : newvalue (optional)

=cut

sub genome_db_id {
   my $self = shift;
   if( @_ ) {
      my $value = shift;
      $self->{'genome_db_id'} = $value;
   }
   return $self->{'genome_db_id'};

}


=head2 conserved_cluster_id

 Title   : conserved_cluster_id
 Usage   : $obj->conserved_cluster_id($newval)
 Function:
 Returns : value of conserved_cluster_id
 Args    : newvalue (optional)

=cut

sub conserved_cluster_id{
   my $self = shift;
   if( @_ ) {
      my $value = shift;
      $self->{'conserved_cluster_id'} = $value;
   }
   return $self->{'conserved_cluster_id'};
}

=head2 contig
 
 Title   : contig
 Usage   : $contig = $obj->contig()
 Function: Returns a VC of this segment
 Returns : A contig
 Args    : none
 
=cut
 
sub contig {
  
  my ($self) = @_;

  return $self->{'contig'} if defined ($self->{'contig'}); 
  
  my $dnafrag = $self->adaptor->db->get_DnaFragAdaptor->fetch_by_dbID($self->dnafrag_id);

  my $contig =  $dnafrag->genomedb->get_VC_by_start_end ($dnafrag->name,$dnafrag->type,$self->seq_start,$self->seq_end);

  $self->{'contig'} = $contig;

  return $contig;

}

=head2 get_all_non_coding_regions
 
 Title   : get_all_non_coding_regions
 Usage   : @ncds= $obj->get_all_non_coding_regions()
 Function: Returns an array of seqfeatures
 Returns : an array of seqfeatures
 Args    : none
 
=cut
 
sub get_all_non_coding_regions{
  
  my ($self) = @_;

  my $dnafrag = $self->adaptor->db->get_DnaFragAdaptor->fetch_by_dbID($self->dnafrag_id);

  my $vc = $dnafrag->genomedb->get_VC_by_start_end ($dnafrag->name,$dnafrag->type,($self->seq_start-5000),($self->seq_end+5000));
  my @exons;

  foreach my $gene ($vc->get_all_Genes){
    push (@exons,$gene->get_all_Exons);

  }
  @exons = sort {$a->start <=> $b->start
                           ||
                 $a->end <=> $b->end  } @exons;

  my @non_cds;

  my $first_ncds= new Bio::EnsEMBL::SeqFeature 
                       (-seqname => $exons[0]->seqname,
                        -start   => 1,
                        -end     => ($exons[0]->start -1),
                        -strand  => 1
                       );

  $first_ncds->attach_seq($vc->primary_seq);
  push (@non_cds,$first_ncds);

  for (my $i = 0; $i <= $#exons ; $i++){
    my $start;
    my $end;
    my $count; 
    for ( my $j = $i; $j <= $#exons; $j++){
      if ($j == $#exons){
         $start = $exons[$j]->end + 1;
         $end = $vc->length - 1;
         $i = $j;
      }
      elsif ($exons[$j+1]->start > $exons[$i]->end + 1){
         $start = $exons[$i]->end + 1; 
         $end   = $exons[$j+1]->start -1 ;
         $i= $j;
         $j = $#exons+1;
      }
    }
    my $ncds =  new Bio::EnsEMBL::SeqFeature
                       (-seqname => $exons[$1]->seqname,
                        -start   => $start,
                        -end     => $end,
                        -strand  => 1
                       );


    $ncds->attach_seq($vc->primary_seq);
    push (@non_cds,$ncds);
  }

  return (@non_cds);

}

=head2 seq_start
 Title   : seq_start
 Usage   : $obj->seq_start($newval) 
 Function: getset for seq_start value
 Returns : value of seq_start
 Args    : newvalue (optional)

=cut

sub seq_start{
   my $self = shift;

   if( @_ ) {
      my $value = shift;
      $self->{'seq_start'} = $value;
   }
   return $self->{'seq_start'};

}

=head2 seq_end
 Title   : seq_end
 Usage   : $obj->seq_end($newval) 
 Function: getset for seq_end value
 Returns : value of seq_end
 Args    : newvalue (optional)

=cut

sub seq_end{
   my $self = shift;

   if( @_ ) {
      my $value = shift;
      $self->{'seq_end'} = $value;
   }
   return $self->{'seq_end'};

}

=head2 intervening_genes
 Title   : intervening_genes
 Usage   : $obj->intervening_genes($newval) 
 Function: getset for intervening_genes
 Returns : number of intervening genes within this conserved_seg.
 Args    : 

=cut

sub intervening_genes{
   my ($self,$value) = @_;

   if (defined $value){ 
   $self->{'intervening_genes'} = $value;
   }
   return $self->{'intervening_genes'};
}

=head2 dnafrag_id
 Title   : dnafrag_id
 Usage   : $obj->dnafrag_id($newval) 
 Function: getset for dnafrag_id
 Returns : dnafrag_id that this protein sits on.
 Args    : dnafrag_id that this protein sits on.

=cut

sub dnafrag_id{
   my ($self,$value) = @_;

   if (defined $value){ 
   $self->{'dnafrag_id'} = $value;
   }
   return $self->{'dnafrag_id'};

}


=head2 get_all_Protein_ids

 Title   : get_all_Protein_ids
 Usage   : $obj->get_all_Protein_ids
 Function: 
 Returns : array of protein_ids;
 Args    : 


=cut

sub get_all_Protein_ids{

    my ($self) = @_;

    return @{$self->{'_protein_id_array'}};

}

=head2 add_Protein_id
 
 Title   : add_Protein_id
 Usage   : $obj->add_Protein_id($protein_dbID)
 Function:
 Returns : 
 Args    :
 
 
=cut
 
sub add_Protein_id{
 
    my ($self,$protein_dbID) = @_;

    $self->throw("Trying to add protein id without supplying argument") unless defined ($protein_dbID);

    push (@{$self->{'_protein_id_array'}},$protein_dbID);
 
}

=head2 adaptor
 
 Title   : adaptor
 Usage   : $obj->adaptor($newval)
 Function: Getset for adaptor object
 Returns : Bio::EnsEMBL::Compara::DBSQL::ConservedSegmentAdaptor
 Args    : Bio::EnsEMBL::Compara::DBSQL::ConservedSegmentAdaptor
 
 
=cut

sub adaptor{
   my $obj = shift;
   if( @_ ) {
      my $value = shift;
      $obj->{'adaptor'} = $value;
    }
    return $obj->{'adaptor'};

}

1;
