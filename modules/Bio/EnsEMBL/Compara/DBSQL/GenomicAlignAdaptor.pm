
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


=head2 list_align_ids

 Title   : list_align_ids
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub list_align_ids{
   my ($self) = @_;

   my $sth = $self->prepare("select align_id from align");
   $sth->execute();

   my @out;
   while( my ($gid) = $sth->fetchrow_array ) {
       push(@out,$gid);
   }

   return @out;
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

  return Bio::EnsEMBL::Compara::GenomicAlign->new( -align_id => $align_id,
						   -adaptor => $self,
						   -align_row_id => $align_row_id);
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
  
  unless (defined $align_name) {
    $self->throw("align_name must be defined as argument");
  }

  my $sth = $self->prepare("select align_id from align where align_name=\"$align_name\"");
  $sth->execute();
  my ($align_id) = $sth->fetchrow_array;
  return $align_id;
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
  
  unless (defined $align_id) {
    $self->throw("align_id must be defined as argument");
  }

  my $sth = $self->prepare("select align_name from align where align_id=\"$align_id\"");
  $sth->execute();
  my ($align_name) = $sth->fetchrow_array;
  return $align_name;
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




=head2 fetch_by_dnafrag

 Title	 : fetch_by_dnafrag
 Usage	 :
 Function:
 Example :
 Returns : an array of Bio::EnsEMBL::Compara::GenomicAlign objects 
 Args 	 :


=cut

sub fetch_by_dnafrag{
   my ($self,$dnafrag,$start,$end) = @_;

   $self->throw("Input $dnafrag not a Bio::EnsEMBL::Compara::DnaFrag\n")
    unless $dnafrag->isa("Bio::EnsEMBL::Compara::DnaFrag"); 

   #formating the $dnafrag
	
   my $dnafrag_id = $dnafrag->dbID;
   
   my $sql;
   unless (defined $start && defined $end) {
     $sql = "select gab.align_id,gab.align_row_id from genomic_align_block gab,dnafrag d where d.dnafrag_id=$dnafrag_id and d.dnafrag_id = gab.dnafrag_id group by gab.align_id,gab.align_row_id";
   } else {
     $sql = "select gab.align_id,gab.align_row_id from genomic_align_block gab,dnafrag d where d.dnafrag_id=$dnafrag_id and d.dnafrag_id = gab.dnafrag_id and gab.raw_start<=$end and gab.raw_end>=$start group by gab.align_id,gab.align_row_id";
   }

   my $sth = $self->prepare($sql);

   $sth->execute();

   my @out;

   while( my ($gaid,$row_id) = $sth->fetchrow_array ) {
       push(@out,$self->fetch_by_dbID($gaid,$row_id));
   }
      	

   return @out;
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
      @genomicaligns = $self->fetch_by_dnafrag($df);
    } elsif ($dnafrag_type eq "Chromosome") {
      @genomicaligns = $self->fetch_by_dnafrag($df,$chr_start,$chr_end);
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
	  my $feature1 = new Bio::EnsEMBL::SeqFeature;
	  $feature1->seqname($chr_name1);
	  $feature1->start($alignblock1->start);
	  $feature1->end($alignblock1->end);
	  $feature1->strand($alignblock1->strand);

	  my $feature2 = new Bio::EnsEMBL::SeqFeature;
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
