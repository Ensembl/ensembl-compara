
#
# Ensembl module for Bio::EnsEMBL::DBSQL::GenomicAlignAdaptor
#
# Cared for by Ewan Birney <birney@ebi.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::DBSQL::GenomicAlignAdaptor - DESCRIPTION of Object

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

    BEGIN { print STDERR "Looking at this...\n"; }

package Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor;
use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Compara::GenomicAlign;

@ISA = qw(Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor);

# we inheriet new

sub fetch_by_dbID {
    my ($self,$id) = @_;

    return $self->fetch_GenomicAlign_by_dbID($id);
}

=head2 fetch_GenomicAlign_by_dbID

 Title   : fetch_GenomicAlign_by_dbID
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub fetch_GenomicAlign_by_dbID{
   my ($self,$dbid) = @_;

   return Bio::EnsEMBL::Compara::GenomicAlign->new( -align_id => $dbid, -adaptor => $self);
}


=head2 fetch_by_genomedb_dnafrag_list

 Title   : fetch_by_genomedb_dnafrag_list
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub fetch_by_genomedb_dnafrag_list{
   my ($self,$genomedb,$dnafrag_list) = @_;

   my $str;

   if( !defined $dnafrag_list || !ref $genomedb || !$genomedb->isa('Bio::EnsEMBL::Compara::GenomeDB') ) {
       $self->throw("Misformed arguments");
   }

   foreach my $id ( @{$dnafrag_list} ) {
       $str .= "'$id',";
   }
   $str =~ s/\,$//g;
   $str = "($str)";
   my $gid = $genomedb->dbID();

   if( !defined  $gid ) {
       $self->throw("Your genome db is not database aware");
   }

   my $sql = "select distinct(gab.align_id) from genomic_align_block gab,dnafrag d where d.name in $str and d.genome_db_id = $gid and d.dnafrag_id = gab.dnafrag_id";
   
   my $sth = $self->prepare($sql);

   $sth->execute();

   my @out;

   while( my ($gaid) = $sth->fetchrow_array ) {
       push(@out,$self->fetch_by_dbID($gaid));
   }
	    

   return @out;
}


=head2 get_AlignBlockSet

 Title   : get_AlignBlockSet
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub get_AlignBlockSet{
   my ($self,$align_id,$row_number) = @_;

   my %dnafraghash;
   my $dnafragadp = $self->db->get_DnaFragAdaptor;

   if( !defined $row_number ) {
       $self->throw("Must get AlignBlockSet by row number");
   }

   my $sth = $self->prepare("select b.align_start,b.align_end,b.dnafrag_id,b.raw_start,b.raw_end,b.raw_strand from genomic_align_block b where b.align_id = $align_id and b.align_row_id = $row_number order by align_start");
   $sth->execute;

   my $alignset  = Bio::EnsEMBL::Compara::FeatureAwareAlignBlockSet->new();
   my $core_db;
 
   while( my $ref = $sth->fetchrow_arrayref ) {
       my($align_start,$align_end,$raw_id,$raw_start,$raw_end,$raw_strand) = @$ref;
       my $alignblock = Bio::EnsEMBL::Compara::AlignBlock->new();
       $alignblock->align_start($align_start);
       $alignblock->align_end($align_end);
       $alignblock->start($raw_start);
       $alignblock->end($raw_end);
       $alignblock->strand($raw_strand);
       
       if( ! defined $dnafraghash{$raw_id} ) {
	   $dnafraghash{$raw_id} = $dnafragadp->fetch_by_dbID($raw_id);
       }

       $alignblock->dnafrag($dnafraghash{$raw_id});
       $alignset->add_AlignBlock($alignblock);
       $core_db = $dnafraghash{$raw_id}->genomedb->ensembl_db; 
   }

   $alignset->core_adaptor($core_db);

   return $alignset;
}



=head2 store

 Title   : store
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub store {
   my ($self,$aln) = @_;

   if( !defined $aln || !ref $aln || !$aln->isa('Bio::EnsEMBL::Compara::GenomicAlign') ) {
       $self->throw("Must store with a GenomicAlign, not a $aln");
   }

   my $dnafragadp = $self->db->get_DnaFragAdaptor();

   foreach my $abs ( $aln->each_AlignBlockSet ) {
       foreach my $ab ( $abs->get_AlignBlocks ) {
	   if( !defined $ab->dnafrag ) {
	       $self->throw("Must have a dnafrag attached to alignblocks");
	   }
	   if( !defined $ab->dnafrag->dbID ) {
	       $dnafragadp->store($ab->dnafrag);
	   }
       }
   }

   # store the alignment first

   my $sth = $self->prepare("insert into align (score) values ('0.0')");
   $sth->execute;
   $aln->dbID($sth->{'mysql_insertid'});
   my $align_id = $aln->dbID;

   # for each alignblockset, store the row and then the alignblocks themselves
   
   foreach my $ab ( $aln->each_AlignBlockSet ) {
       my $sth2 = $self->prepare("insert into align_row (align_id) values ($align_id)");
       $sth2->execute();
       my $row_id = $sth2->{'mysql_insertid'};

       foreach my $a ( $ab->get_AlignBlocks ) {
	   my $sth3 = $self->prepare("insert into genomic_align_block (align_id,align_start,align_end,align_row_id,dnafrag_id,raw_start,raw_end,raw_strand) values ($align_id,",
				     $a->align_start,
				     $a->align_end,
				     $row_id,
				     $a->dnafrag->dbID,
				     $a->start,
				     $a->end,
				     $a->strand
				     );
       }
   }
    
   $aln->dbID($align_id);

   return $align_id;
}



1;









