
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


package Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor;
use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::Compara::AlignBlockSet; 
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::Utils::Cache; #CPAN LRU cache


@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

my $CACHE_SIZE = 4;


=head2 new

  Arg [1]    : list of argument to super class constructor @args
  Example    : $gaa = new Bio::EnsEMBL::Compara::GenomicAlignAdaptor($db);
  Description: Creates a new GenomicAlignAdaptor.  The superclass constructor
               is extended to initialise an internal cache.
  Returntype : none
  Exceptions : none
  Caller     : Bio::EnsEMBL::DBSQL::DBConnection

=cut

sub new {
  my ($class, @args) = @_;

  my $self = $class->SUPER::new(@args);

  #initialize internal LRU cache
  tie(%{$self->{'_cache'}}, 'Bio::EnsEMBL::Utils::Cache', $CACHE_SIZE);
  
  return $self;
}
     

sub fetch_by_dbID {
    my ($self,$id,$row_id) = @_;
    return $self->fetch_GenomicAlign_by_dbID($id,$row_id);
}



sub list_align_ids{
   my ($self) = @_;

   $self->throw( "This is useless now. I think we need the dnafrags for just one species here" );
}



=head2 fetch_GenomicAlign_by_dbID

 Title   : fetch_GenomicAlign_by_dbID
 Usage   :
 Function:
 Example :
 Reterns : #kailan: returns protein_id(can get protein_name (align_name)  from the align table)
 Args    :

got to fix this

=cut

sub fetch_GenomicAlign_by_dbID{
  my ($self,$align_id,$align_row_id) = @_;

  $self->throw( "Useless now, only alignments should come back from this adaptor" );

#  return Bio::EnsEMBL::Compara::GenomicAlign->new( -align_id => $align_id,
#						   -adaptor => $self,
#						   -align_row_id => $align_row_id);
}

=head2 fetch_align_id_by_align_name

 Title   : fetch_align_id_by_align_name
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub fetch_align_id_by_align_name {
  my ($self,$align_name) = @_;

  $self->throw( "This is the slice name in one of the species. Should be fetch_by_dnafrag" );
#  unless (defined $align_name) {
#    $self->throw("align_name must be defined as argument");
#  }

#  my $sth = $self->prepare("select align_id from align where align_name=\"$align_name\"");
#  $sth->execute();
#  my ($align_id) = $sth->fetchrow_array;
#  return $align_id;
}

=head2 fetch_align_name_by_align_id

 Title   : fetch_align_name_by_align_id
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub fetch_align_name_by_align_id {
  my ($self,$align_id) = @_;
  
  $self->throw( "fetch_by_dnafrag is better choice now" );
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
   # dnafrags have genomedb, so it should be redundant here
   
   $self->warn( "use fetch_all_by_dnafrags( \$dnafrag, \"query\""); 
   $self->fetch_all_by_dnafrags( $dnafrag_list );

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

   my $sql = "select gab.align_id,gab.align_row_id from genomic_align_block gab,dnafrag d where d.name in $str and d.genome_db_id = $gid and d.dnafrag_id = gab.dnafrag_id group by gab.align_id,gab.align_row_id";
   
   my $sth = $self->prepare($sql);

   $sth->execute();

   my @out;

   while( my ($gaid,$row_id) = $sth->fetchrow_array ) {
       push(@out,$self->fetch_by_dbID($gaid,$row_id));
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

   my $sth = $self->prepare("select b.align_start,b.align_end,b.dnafrag_id,b.raw_start,b.raw_end,b.raw_strand ,b.perc_id,b.score,b.cigar_line  from genomic_align_block b where b.align_id = $align_id and b.align_row_id = $row_number order by align_start");
   $sth->execute;

   my $alignset  = Bio::EnsEMBL::Compara::AlignBlockSet->new();

   while( my $ref = $sth->fetchrow_arrayref ) {
       my($align_start,$align_end,$raw_id,$raw_start,$raw_end,$raw_strand,$perc_id,$score,$cigar_string) = @$ref;
       my $alignblock = Bio::EnsEMBL::Compara::AlignBlock->new();
       $alignblock->align_start($align_start);
       $alignblock->align_end($align_end);
       $alignblock->start($raw_start);
       $alignblock->end($raw_end);
       $alignblock->strand($raw_strand);
       $alignblock->perc_id($perc_id);
       $alignblock->score($score);
       $alignblock->cigar_string($cigar_string);
      
       
       if( ! defined $dnafraghash{$raw_id} ) {
	   $dnafraghash{$raw_id} = $dnafragadp->fetch_by_dbID($raw_id);
       }

       $alignblock->dnafrag($dnafraghash{$raw_id});
       $alignset->add_AlignBlock($alignblock);
   }
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
   my ($self,$aln,$align_id) = @_;

   if( !defined $aln || !ref $aln || !$aln->isa('Bio::EnsEMBL::Compara::GenomicAlign') ) {
       $self->throw("Must store with a GenomicAlign, not a $aln");
   }

   unless (defined $align_id) {
     $self->throw("An align_id must be specified and defined");
   }

   my $dnafragadp = $self->db->get_DnaFragAdaptor();

   foreach my $abs ( $aln->each_AlignBlockSet ) {
       foreach my $ab ( $abs->get_AlignBlocks ) {
	   if( !defined $ab->dnafrag ) {
	       $self->throw("Must have a dnafrag attached to alignblocks");
	   }
	   if( !defined $ab->dnafrag->dbID ) {
	       $dnafragadp->store_if_needed($ab->dnafrag);
	   }
       }
   }

   # for each alignblockset, store the row and then the alignblocks themselves
   
   my $sth3 = $self->prepare("insert into genomic_align_block (align_id,align_start,align_end,align_row_id,dnafrag_id,raw_start,raw_end,raw_strand,score,perc_id,cigar_line) values (?,?,?,?,?,?,?,?,?,?,?)");

   foreach my $ab ( $aln->each_AlignBlockSet ) {
       my $sth2 = $self->prepare("insert into align_row (align_id) values ($align_id)");
       $sth2->execute();
       my $row_id = $sth2->{'mysql_insertid'};
       
       foreach my $a ( $ab->get_AlignBlocks ) {
	   $sth3->execute($align_id,
			  $a->align_start,
			  $a->align_end,
			  $row_id,
			  $a->dnafrag->dbID,
			  $a->start,
			  $a->end,
			  $a->strand,
                          $a->score,
                          $a->perc_id,
			  $a->cigar_string
			  );

       }
   }
    
   $aln->dbID($align_id);

   return $align_id;
}





=head2 _fetch_all_by_dnafrag_genomedb_direct

  Arg  1     : Bio::EnsEMBL::Compara::DnaFrag $dnafrag
               All genomic aligns that align to this frag
  Arg [2]    : Bio::EnsEMBL::Compara::GenomeDB $target_genome
               optionally restrict resutls to matches with this
               genome. Has to have a dbID().
  Arg [3]    : int $start
  Arg [4]    : int $end
  Example    : none
  Description: Find all GenomicAligns that overlap this dnafrag.
               Return them in a way that this frags are on the
               consensus side of the Alignment.
  Returntype : listref Bio::EnsEMBL::Compara:GenomicAlign
  Exceptions : none
  Caller     : general

=cut


sub _fetch_all_by_dnafrag_genomedb_direct {
   my ($self,$dnafrag, $target_genome, $start,$end) = @_;

   $self->throw("Input $dnafrag not a Bio::EnsEMBL::Compara::DnaFrag\n")
    unless $dnafrag->isa("Bio::EnsEMBL::Compara::DnaFrag"); 

   #formating the $dnafrag
	
   my $dnafrag_id = $dnafrag->dbID;
   
   my $genome_db = $dnafrag->genomedb();
   my $select = "SELECT ".join( ",", map { "gab.".$_ } $self->_columns() ).
     " FROM genomic_align_block gab ";
   if( defined $target_genome ) {
     $select .= ", dnafrag d"
   }

   my $sql;
   my $sth;
   my $result = [];

   if( !defined($target_genome) ||
       $genome_db->has_query( $target_genome ) ) {
     $sql = $select . " WHERE gab.consensus_dnafrag_id = $dnafrag_id";
     if (defined $start && defined $end) {
       $sql .= " AND gab.consensus_start<= $end
                 AND gab.consensus_end >= $start";
     }
     if( defined $target_genome ) {
       $sql .= " AND gab.query_dnafrag_id = d.dnafrag_id
                 AND d.genome_db_id = ".$target_genome->dbID();
     }
     $sth = $self->prepare( $sql );
     $sth->execute();
     $result = $self->_objs_from_sth( $sth );
   } 

   if( !defined($target_genome) ||
       $genome_db->has_consensus( $target_genome ) ) {
     
     $sql = $select . " WHERE gab.query_dnafrag_id = $dnafrag_id";
     if (defined $start && defined $end) {
       $sql .= " AND gab.query_start<= $end
                 AND gab.query_end >= $start";
     }
     if( defined $target_genome ) {
       $sql .= " AND gab.consensus_dnafrag_id = d.dnafrag_id
                 AND d.genome_db_id = ".$target_genome->dbID();
     }
     $sth = $self->prepare( $sql );
     $sth->execute();
     push( @$result, @{$self->_objs_from_sth( $sth, 1 )});
   }

   return $result;
}



=head2 fetch_all_by_dnafrag_genomedb

  Arg  1     : Bio::EnsEMBL::Compara::DnaFrag $dnafrag
  Arg  2     : string $query_species
               The species where the caller wants alignments to
               his dnafrag.
  Arg [3]    : int $start
  Arg [4]    : int $end
  Example    :  ( optional )
  Description: testable description
  Returntype : none, txt, int, float, Bio::EnsEMBL::Example
  Exceptions : none
  Caller     : object::methodname or just methodname

=cut


sub fetch_all_by_dnafrag_genomedb {
  my ( $self, $dnafrag, $target_genome, $start, $end ) = @_;

  my $genome_cons = $dnafrag->genomedb();
  my $genome_query = $target_genome;
  
  # direct or indirect ??
  if( $genome_cons->has_consensus( $genome_query ) ||
      $genome_cons->has_query( $genome_query )) {
    $self->_fetch_all_by_dnafrag_genomedb_direct
      ( $dnafrag, $target_genome, $start, $end );
  } else {
    # indirect checks
    my $linked_cons = $genome_cons->linked_genomes();
    my $linked_query = $genome_query->linked_genomes();
    
    # there are not many genomes, square effort is cheap
    my $linked = [];
    for my $g1 ( @$linked_cons ) {
      for my $g2 ( @$linked_query ) {
	if( $g1 == $g2 ) {
	  push( @$linked, $g1 );
	}
      }
    }
    #collect GenomicAligns from all linked genomes
    my $set1 = [];
    for my $g ( @$linked ) {
      my $g_res = $self->_fetch_all_by_dnafrag_genomedb_direct
	( $dnafrag, $g, $start, $end );
      push( @$set1, @$g_res );
    }

    # go from each dnafrag in the result set to target_genome
    # there is room for improvement here: create start end

    my %frags = map { $_->query_dnafrag() => $_->query_dnafrag() } @$set1;
    
    my $set2 = [];
    for my $frag ( values %frags ) {
      my $d_res = $self->_fetch_all_by_dnafrag_genomedb_direct
	( $frag, $genome_query );
      push( @$set2, @$d_res );
    }
    # now set1 and set2 have to merge...
    $self->_merge_alignsets( $set1, $set2 );
  }
}


=head2 _merge_alignsets

  Arg  1     : listref Bio::EnsEMBL::Compara::GenomicAlign $set1
               from consensus to query
  Arg  2     : listref Bio::EnsEMBL::Compara::GenomicAlign $set2
               and over consensus to next species query             
  Example    : none
  Description: set1 contains GAs with consensus species belonging to
               the input dnafragment. Query fragments are the actual reference
               species. In set 2 consensus species is the reference and
               query is the actual target genome. There may be more than
               one reference genome involved.
  Returntype : listref Bio::EnsEMBL::Compara::GenomicAlign
  Exceptions : none
  Caller     : internal

=cut


sub _merge_alignsets {
  my ( $self, $alignset1, $alignset2 ) = @_;

  # sorting of both sets
  # walking through and finding overlapping GAs
  # create GA from overlapping GA
  # return list of those

  # efficiently generating all Aligns that overlap
  # [ key, object, set1 or 2 ]
  # Alignments are twice in big list. They are added to the overlapping
  # set the first time they appear and they are removed the
  # second time they appear. Scanline algorithm

  my @biglist = ();
  for my $align ( @$alignset1 ) {
    push( @biglist, 
          [ $align->query_dnafrag()->dbID(), 
            $align->query_start(), $align, 0 ] );
    push( @biglist, 
          [ $align->query_dnafrag()->dbID(), 
            $align->query_end()+.5, $align, 0 ] );
  }

  for my $align ( @$alignset2 ) {
    push( @biglist, 
          [ $align->consensus_dnafrag()->dbID(), 
            $align->consensus_start(), $align, 1 ] );
    push( @biglist, 
          [ $align->consensus_dnafrag()->dbID(), 
            $align->consensus_end()+.5, $align, 1 ] );
  }
  
  my @sortlist = sort { $a->[0] <=> $b->[0] ||
                        $a->[1] <=> $b->[1] } @biglist;

  # walking from start to end through sortlist and keep track of the 
  # currently overlapping set of Alignments
 
  my @overlapping_sets = ( {}, {} ); 
  my ($align, $setno);
  my $merged_aligns = [];

  for my $aligninfo ( @sortlist ) {
    $align = $aligninfo->[2];
    $setno = $aligninfo->[3];

    if( exists $overlapping_sets[ $setno ]->{ $align } ) {
      # remove from current overlapping set
      delete $overlapping_sets[ $setno ]->{ $align };
    } else {
      # insert into the set and do all the overlap business
      $overlapping_sets[ $setno ]->{ $align } = $align;
      # the other set contains everything this align overlaps with
      for my $align2 ( values %{$overlapping_sets[ 1 - $setno ]} ) {
        if( $setno == 0 ) {
          $self->_add_derived_alignments( $merged_aligns, $align, $align2 );
        } else {
          $self->_add_derived_alignments( $merged_aligns, $align2, $align );
        }
      }
    }
  }

  return $merged_aligns;
}



=head2 _add_derived_alignments

  Arg  1     : listref 
    Additional description lines
    list, listref, hashref
  Example    :  ( optional )
  Description: testable description
  Returntype : none, txt, int, float, Bio::EnsEMBL::Example
  Exceptions : none
  Caller     : object::methodname or just methodname

=cut


sub _add_derived_alignments {
  my ( $self, $merged_aligns, $alignA, $alignB ) = @_;

  # variable name explanation
  # q - query c - consensus s - start e - end l - last
  # o, ov overlap j - jump_in_
  # r - result
  my ( $qs, $qe, $lqs, $lqe, $cs, $ce, $lcs, $lce,
       $ocs, $oce, $oqs, $oqe, $jc, $jq, $ovs, $ove,
       $rcs, $rce, $rqs, $rqe);

  # initialization phase
  

  my @cigA = ( $alignA->cigar_line =~ /(\d*[MDI])/g );
  my @cigB;
  my $line = $alignB->cigar_line();

  if( $alignA->query_strand == -1 ) {
    @cigB = reverse ( $line =~ /(\d*[MDI])/g ); 
  } else {
    @cigB = ( $line =~ /(\d*[MDI])/g ); 
  }

  # need a 'normalized' start for qs, qe, oxs so I dont 
  # have to check strandedness all the time  

  # consensus is strand 1 and is not compared to anything,
  # can keep its original coordinate system
 
  $lce = $alignA->consensus_start() - 1;
  $ce = $lce;
  $cs = $ce + 1;
  
  # alignBs query can be + or - just keep relative coords for now
  $lqe = 0; $lqs = 1;
  $qe = 0; $qs = 1;

  # ocs will be found relative to oce and has to be comparable
  # to oqs. But it could be that we have to move downwards if we
  # are not - strand. thats why coordinates are trnaformed here

  if( $alignA->query_strand == -1 ) {
    # query_end is first basepair of alignment
    if( $alignA->query_end() < $alignB->consensus_end() ) {
      # oqs/e = 0 ocs/e = difference
      $oqe = 0; $oqs = 1;
      $oce = $alignB->consensus_end() - $alignA->query_end();
      $ocs = $oce + 1;
    } else {
      $oce = 0; $ocs = 1;
      $oqe = $alignA->query_end() - $alignB->consensus_end();
      $oqs = $oqe + 1;
    }
  } else {
    # in theory no coordinate magic necessary :-)
    $oqs = $alignA->query_start();
    $oqe = $alignA->query_end();
    $ocs = $alignB->consensus_start();
    $oce = $alignB->consensus_end();
  }

  # initializing result
  $rcs = $rce = $rqs = $rqe = 0;
  my @result_cig= ();

  my $current_match = 0;
  my $new_match;
  

  while( 1 ) {
    print "ocs $ocs oce $oce oqs $oqs oqe $oqe\n";
    print "cs $cs ce $ce qs $qs qe $qe\n";
    print "rcs $rcs rce $rce rqs $rqs rqe $rqe\n";
    print "\n";


    # exit if you request a new piece of alignment and the cig list is 
    # empty

    if( $oce < $ocs || $oce < $oqs ) {
      # next M area in cigB
      last unless @cigB;
      $self->_next_cig( \@cigB, \$ocs, \$oce, \$qs, \$qe ); 
      next;
    }
    if( $oqe < $oqs || $oqe < $ocs ) {
      # next M area in cigA
      last unless @cigA;
      $self->_next_cig( \@cigA, \$cs, \$ce, \$oqs, \$oqe );
      next;
    }

    # now matching region overlap in reference genome
    $ovs = $ocs < $oqs ? $oqs : $ocs;
    $ove = $oce < $oqe ? $oce : $oqe;
    
    if( $current_match ) {
      $jc = $cs + ( $ovs - $oqs ) - $lce - 1;
      $jq = $qs + ( $ovs - $ocs ) - $lqe - 1;
    } else {
      $jc = $jq = 0;
    }

    $new_match = $ove - $ovs + 1;
    my $new_ga = 0;

    print "";

    if( $jc == 0 ) {
      if( $jq == 0 ) {
	$current_match += $new_match;
      } else {
        # store current match;
	push( @result_cig, $current_match."M" );
	$jq = "" if ($jq == 1); 
	# jq deletions;
	push( @result_cig, $jq."D" );
	$current_match = $new_match;
      }
    } else {
      if( $jq == 0 ) {
        # store current match;
	push( @result_cig, $current_match."M" );
	# jc insertions;
	$jc = "" if( $jc == 1 );
	push( @result_cig, $jc."I" );
	$current_match = $new_match;
         
      } else {

	push( @result_cig, $current_match."M" );
	# new GA
	my $query_strand = $alignA->query_strand() * $alignB->query_strand();
	my ( $query_start, $query_end );
	if( $query_strand == 1 ) {
	  $query_start = $rqs + $alignB->query_start() - 1;
	  $query_end = $rqe + $alignB->query_end() - 1;
	} else {
	  $query_end = $alignB->query_end() - $rqs + 1;
	  $query_start = $alignB->query_end() - $rqe + 1;
	}
      
	my $ga = Bio::EnsEMBL::Compara::GenomicAlign->new
	  ( -consensus_dnafrag => $alignA->consensus_dnafrag,
	    -query_dnafrag => $alignB->query_dnafrag,
	    -cigar_line => join("",@result_cig),
	    -consensus_start => $rcs,
	    -consensus_end => $rce,
	    -query_strand => $query_strand, 
	    -query_start => $query_start,
	    -query_end => $query_end
	    -adaptor => $self,
	    -perc_id => $alignA->perc_id() * $alignB->perc_id() / 10000,
	    -score => $alignA->score() < $alignB->score() ? $alignA->score() : $alignB->score()
	  );
	push( @$merged_aligns, $ga );
	$rcs = $rce = $rqs = $rqe = 0;
	@result_cig = ();
	
	$current_match = $new_match;
      }
    }


    
    $rcs = $cs+($ovs-$oqs) unless $rcs;
    $rce = $cs+($ove-$oqs);
    $rqs = $qs+($ovs-$ocs) unless $rqs;
    $rqe = $qs+($ove-$ocs);

    # update the last positions
    $lcs = $cs; $lce = $ce; $lqs = $qs; $lqe = $qe;

    # next piece on the one that end earlier
    my $cmp = ( $oce <=> $oqe );
 
    if( $cmp >= 0 ) {
      # next M area in cigB
      $self->_next_cig( \@cigB, \$ocs, \$oce, \$qs, \$qe ); 
    }
    if( $cmp <= 0 ) {
      # next M area in cigA
      $self->_next_cig( \@cigA, \$cs, \$ce, \$oqs, \$oqe );
    } 
  } # end of while loop

  # if there is a last floating current match
  if( $current_match ) {
    push( @result_cig, $current_match."M" );
    # new GA
    my $query_strand = $alignA->query_strand() * $alignB->query_strand();
    my ( $query_start, $query_end );
    if( $query_strand == 1 ) {
      $query_start = $rqs + $alignB->query_start() - 1;
      $query_end = $rqe + $alignB->query_end() - 1;
    } else {
      $query_end = $alignB->query_end() - $rqs + 1;
      $query_start = $alignB->query_end() - $rqe + 1;
    }
  
    my $ga = Bio::EnsEMBL::Compara::GenomicAlign->new
      ( -consensus_dnafrag => $alignA->consensus_dnafrag,
	-query_dnafrag => $alignB->query_dnafrag,
	-cigar_line => join("",@result_cig),
	-consensus_start => $rcs,
	-consensus_end => $rce,
	-query_strand => $query_strand, 
	-query_start => $query_start,
	-query_end => $query_end
	-adaptor => $self,
	-perc_id => $alignA->perc_id() * $alignB->perc_id() / 10000,
	-score => $alignA->score() < $alignB->score() ? $alignA->score() : $alignB->score()
      );
    push( @$merged_aligns, $ga );
  # nothing to return all in merged_aligns
  }
}


sub _next_cig {
  my ( $self, $ciglist, $cs, $ce, $qs, $qe ) = @_;
  
  my ( $cig_elem, $type, $count );
  my $count;
  do {
    $cig_elem = shift( @$ciglist );
    ( $count ) = ($cig_elem =~ /(\d*)/);
    $count || ( $count = 1 );

    ( $type ) = ( $cig_elem =~ /(.)$/ );
    if( $type eq 'D' ) {
      $$qe += $count;
    } elsif( $type eq 'I' ) {
      $$ce += $count;
    } else {
      $$cs = $$ce + 1;
      $$ce = $$cs + $count - 1;
      $$qs = $$qe + 1;
      $$qe = $$qs + $count - 1;
    } 
  } until ( $type eq 'M' || ! ( @$ciglist ));
}

  
=head2 fetch_DnaDnaAlignFeature_by_species_chr_start_end

 Arg [1]    : string subject_species
              e.g. "Homo_sapiens"
 Arg [2]    : string query_species
              e.g. "Mus_musculus"
 Arg [3]    : string chr_name
 Arg [4]    : int chr_start
 Arg [5]    : int chr_end
 Arg [6]    : string dnafrag_type (optional)
              type of dnafrag from which data as to be queried, default is "VirtualContig"
 Example    : fetch_DnaDnaAlignFeature_by_species_chr_start_end("Homo_sapiens","Mus_musculus","X",250000,"VirtualContig");
 Description: find matches of query_species on subject_species between chromosome coordinates on subject_species
 Returntype : an array reference of Bio::EnsEMBL::DnaDnaAlignFeature objects
 Exceptions : none
 Caller     : general

=cut

sub fetch_DnaDnaAlignFeature_by_species_chr_start_end {
  my ($self,$sb_species,$qy_species,$chr_name,$chr_start,$chr_end,$dnafrag_type) = @_;

  my @DnaDnaAlignFeatures;

  my $dfad = $self->db->get_DnaFragAdaptor;
  unless (defined $dnafrag_type) {
    $dnafrag_type = "VirtualContig";
  }
  
  my @list_dnafrag = $dfad->fetch_by_species_chr_start_end ($sb_species,$chr_name,$chr_start,$chr_end,$dnafrag_type);
  
  foreach my $df (@list_dnafrag) {
    my @genomicaligns;
    if ($dnafrag_type eq "VirtualContig") {
      @genomicaligns = @{$self->fetch_all_by_dnafrag($df)};
    } elsif ($dnafrag_type eq "Chromosome") {
      @genomicaligns = @{$self->fetch_all_by_dnafrag($df,$chr_start,$chr_end)};
    }

    foreach my $genomicalign (@genomicaligns) {

      foreach my $alignblockset ($genomicalign->each_AlignBlockSet) {

        my %alignblocks;

        foreach my $alignblock ($alignblockset->get_AlignBlocks) {
	  $alignblocks{$alignblock->dnafrag->genomedb->name}{$alignblock->align_start."-".$alignblock->align_end} = $alignblock;
	} 

	foreach my $key (keys %{$alignblocks{$sb_species}}) {

	  my $alignblock1 = $alignblocks{$sb_species}{$key};
	  my $alignblock2 = $alignblocks{$qy_species}{$key};	
	  
	  next unless (defined $alignblock2);

	  my ($chr_name1,$chr_start1,$chr_end1);
	  if ($alignblock1->dnafrag->type eq "VirtualContig") {
	    ($chr_name1,$chr_start1,$chr_end1) = split /\./, $alignblock1->dnafrag->name;
	    $alignblock1->start($alignblock1->start + $chr_start1 - 1);
	    $alignblock1->end($alignblock1->end + $chr_start1 - 1);
	  } else {
	    $chr_name1 = $alignblock1->dnafrag->name;
	  }

	  next unless ($alignblock1->start <= $chr_end && $alignblock1->end >= $chr_start);
	  
	  my ($chr_name2,$chr_start2,$chr_end2);
	  if ($alignblock2->dnafrag->type eq "VirtualContig") {
	    ($chr_name2,$chr_start2,$chr_end2) = split /\./, $alignblock2->dnafrag->name;
	    $alignblock2->start($alignblock2->start + $chr_start2 - 1);
	    $alignblock2->end($alignblock2->end + $chr_start2 - 1);
	  } else {
	    $chr_name2 = $alignblock2->dnafrag->name;
	  }

	  my $DnaDnaAlignFeature = new Bio::EnsEMBL::DnaDnaAlignFeature('-cigar_string' => $alignblock1->cigar_string);
	  my $feature1 = Bio::EnsEMBL::SeqFeature->new();
	  $feature1->seqname($chr_name1);
	  $feature1->start($alignblock1->start);
	  $feature1->end($alignblock1->end);
	  $feature1->strand($alignblock1->strand);

	  my $feature2 = Bio::EnsEMBL::SeqFeature->new();
	  $feature2->seqname($chr_name2);
	  $feature2->start($alignblock2->start);
	  $feature2->end($alignblock2->end);
	  $feature2->strand($alignblock2->strand);

	  $DnaDnaAlignFeature->feature1($feature1);
	  $DnaDnaAlignFeature->feature2($feature2);
	  $DnaDnaAlignFeature->score($alignblock1->score);
	  $DnaDnaAlignFeature->percent_id($alignblock1->perc_id);
	  $DnaDnaAlignFeature->species($alignblock1->dnafrag->genomedb->name);
	  $DnaDnaAlignFeature->hspecies($alignblock2->dnafrag->genomedb->name);

	  if ($DnaDnaAlignFeature->strand == -1) {
	    $DnaDnaAlignFeature->reverse_complement;
	  }

	  push @DnaDnaAlignFeatures,$DnaDnaAlignFeature;

	}
      }
    }
  }
  
  return \@DnaDnaAlignFeatures;
}




=head2 fetch_DnaDnaAlignFeature_by_Slice

 Arg [1]    : Bio::EnsEMBL::Slice
 Arg [2]    : string query_species
              e.g. "Mus_musculus"
 Example    : $gaa->fetch_DnaDnaAlignFeature_by_Slice($slice, "Mus_musculus");
 Description: find matches of query_species in the region of a slice of a 
              subject species
 Returntype : an array reference of Bio::EnsEMBL::DnaDnaAlignFeature objects
 Exceptions : none
 Caller     : general

=cut

sub fetch_DnaDnaAlignFeatures_by_Slice {
  my ($self, $slice, $qy_species) = @_;

  unless($slice && ref $slice && $slice->isa('Bio::EnsEMBL::Slice')) {
    $self->throw("Invalid slice argument [$slice]\n");
  }

  unless($qy_species) {
    $self->throw("Query species argument is required");
  }

  #we will probably use a taxon object instead of a string eventually
  my $species = $slice->adaptor->db->get_MetaContainer->get_Species;
  my $sb_species = $species->binomial;
  $sb_species =~ s/ /_/; #replace spaces with underscores

  my $key = join(':', "SLICE", $slice->name, $sb_species, $qy_species);

  if(exists $self->{'_cache'}->{$key}) {
    return $self->{'_cache'}->{$key};
  } 

  my $slice_start = $slice->chr_start;
  my $slice_end   = $slice->chr_end;
  my $slice_strand = $slice->strand;

  my $features = $self->fetch_DnaDnaAlignFeature_by_species_chr_start_end(
						$sb_species,
						$qy_species,
						$slice->chr_name,
						$slice_start,
					        $slice_end);

  if($slice_strand == 1) {
    foreach my $f (@$features) {
      my $start  = $f->start - $slice_start + 1;
      my $end    = $f->end   - $slice_start + 1;
      $f->start($start);
      $f->end($end);
      $f->contig($slice);
    }
  } else {
    foreach my $f (@$features) {
      my $start  = $slice_end - $f->start + 1;
      my $end    = $slice_end - $f->end   + 1;
      my $strand = $f->strand * -1;
      $f->start($start);
      $f->end($end);
      $f->strand($strand);
      $f->contig($slice);
    }
  }

  #update the cache
  $self->{'_cache'}->{$key} = $features;

  return $features;
}

# produse a list of columns in the order expected from 
# _objs_from_sth

sub _columns {
  return ( "consensus_dnafrag_id", "consensus_start", "consensus_end",
	   "query_dnafrag_id", "query_start", "query_end", "query_strand",
	   "score", "perc_id", "cigar_line" );
}

=head2 _objs_from_sth

  Arg [1]    : DBD::statement_handle $sth
               an executed statement handle. The result columns
               have to be in the correct order.
  Arg [2]    : int $reverse ( 1 if present )
               flip the consensus and the query before creating the
               GenomicAlign.  
  Example    : none
  Description: retrieves the data from the database and creates GenomicAlign
               objects from it.
  Returntype : listref Bio::EnsEMBL::Compara::GenomicAlign 
  Exceptions : none
  Caller     : internal

=cut


sub _objs_from_sth {
  my ( $self, $sth, $reverse ) = @_;

  my $result = [];

  my ( $consensus_dnafrag_id, $consensus_start, $consensus_end, $query_dnafrag_id,
       $query_start, $query_end, $query_strand, $score, $perc_id, $cigar_string );
  if( $reverse ) {
    $sth->bind_columns
      ( \$query_dnafrag_id, \$query_start, \$query_end,  
	\$consensus_dnafrag_id, \$consensus_start, \$consensus_end, \$query_strand,
	\$score, \$perc_id, \$cigar_string );
  } else {
    $sth->bind_columns
      ( \$consensus_dnafrag_id, \$consensus_start, \$consensus_end, 
	\$query_dnafrag_id, \$query_start, \$query_end, \$query_strand, 
	\$score, \$perc_id, \$cigar_string );
  }

  my $da = $self->db()->get_DnaFragAdaptor();

  while( $sth->fetch() ) {
    my $genomic_align;
    
    if( $reverse && $query_strand == -1 ) {
      # alignment of the opposite strand

      $cigar_string =~ tr/DI/ID/;
      my @pieces = ( $cigar_string =~ /(\d*[MDI])/g );
      $cigar_string= join( "", reverse( @pieces ));
    }
    
    $genomic_align = Bio::EnsEMBL::Compara::GenomicAlign->new
      (
       -adaptor => $self,
       -consensus_dnafrag => $da->fetch_by_dbID( $consensus_dnafrag_id ),
       -consensus_start => $consensus_start,
       -consensus_end => $consensus_end,
       -query_dnafrag => $da->fetch_by_dbID( $query_dnafrag_id ),
       -query_start => $query_start,
       -query_end => $query_end,
       -query_strand => $query_strand,
       -score => $score,
       -perc_id => $perc_id,
       -cigar_line => $cigar_string
      );


    push( @$result, $genomic_align );
  }


  return $result;
}




=head2 deleteObj

  Arg [1]    : none
  Example    : none
  Description: Clears the internal cache prior so correct garbage collection 
               can occur.
  Returntype : none
  Exceptions : none
  Caller     : Bio::EnsEMBL::DBSQL::DBConnection::deleteObj

=cut

sub deleteObj {
  my $self = shift;

  #perform superclass cleanup
  $self->SUPER::deleteObj;

  #flush internal cache
  %{$self->{'_cache'}} = ();
}

1;
