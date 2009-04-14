package Bio::EnsEMBL::Compara::Family;

use strict;
use Bio::EnsEMBL::Compara::BaseRelation;
use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Exception;
use Bio::AlignIO;
use Bio::SimpleAlign;
use IO::File;

our @ISA = qw(Bio::EnsEMBL::Compara::BaseRelation);

=head2 new

  Arg [1]    : 
  Example    : 
  Description: 
  Returntype : Bio::EnsEMBL::Compara::Family (but without members; caller has to fill using
               add_member)
  Exceptions : 
  Caller     : 

=cut

sub new {
  my($class,@args) = @_;
  
  my $self = $class->SUPER::new(@args);
  
  if (scalar @args) {
     #do this explicitly.
     my ($description_score) = rearrange([qw(DESCRIPTION_SCORE)], @args);
      
      $description_score && $self->description_score($description_score);
  }
  
  return $self;
}   

=head2 description_score

  Arg [1]    : 
  Example    : 
  Description: 
  Returntype : 
  Exceptions : 
  Caller     : 

=cut

sub description_score {
  my $self = shift;
  $self->{'_description_score'} = shift if(@_);
  return $self->{'_description_score'};
}


=head2 read_clustalw

  Arg [1]    : string $file 
               The name of the file containing the clustalw output  
  Example    : $family->read_clustalw('/tmp/clustalw.aln');
  Description: Parses the output from clustalw and sets the alignment strings
               of each of the memebers of this family
  Returntype : none
  Exceptions : thrown if file cannot be parsed
               warning if alignment file contains identifiers for sequences
               which are not members of this family
  Caller     : general

=cut

sub read_clustalw {
  my $self = shift;
  my $file = shift;

  my %align_hash;
  my $FH = IO::File->new();
  $FH->open($file) || throw("Could not open alignment file [$file]");

  <$FH>; #skip header
  while(<$FH>) {
    next if($_ =~ /^\s+/);  #skip lines that start with space
    
    my ($id, $align) = split;
    $align_hash{$id} ||= '';
    $align_hash{$id} .= $align;
  }

  $FH->close;

  #place all member attributes in a hash on their member name
  my @members_attributes;

  push @members_attributes,@{$self->get_Member_Attribute_by_source('ENSEMBLPEP')};
  push @members_attributes,@{$self->get_Member_Attribute_by_source('Uniprot/SWISSPROT')};
  push @members_attributes,@{$self->get_Member_Attribute_by_source('Uniprot/SPTREMBL')};
  
  my %attribute_hash;
  foreach my $member_attribute (@members_attributes) {
    my ($member, $attribute) = @{$member_attribute};
    $attribute_hash{$member->stable_id} = $attribute;
  }

  #assign cigar_line to each of the member attribute
  foreach my $id (keys %align_hash) {
    my $attribute = $attribute_hash{$id};
    if($attribute) {
      my $alignment_string = $align_hash{$id};
      $alignment_string =~ s/\-([A-Z])/\- $1/g;
      $alignment_string =~ s/([A-Z])\-/$1 \-/g;

      my @cigar_segments = split " ",$alignment_string;

      my $cigar_line = "";
      foreach my $segment (@cigar_segments) {
        my $seglength = length($segment);
        $seglength = "" if ($seglength == 1);
        if ($segment =~ /^\-+$/) {
          $cigar_line .= $seglength . "D";
        } else {
          $cigar_line .= $seglength . "M";
        }
      }

      $attribute->cigar_line($cigar_line);

    } else {
      throw("No member for alignment portion: [$id]");
    }
  }
}

sub load_cigars_from_fasta {
    my ($self, $file, $store) = @_;

  my $alignio = Bio::AlignIO->new
    (-file => "$file",
     -format => "fasta");
  my $aln = $alignio->next_aln;

  #place all member attributes in a hash on their member name
  my @members_attributes = ();

  push @members_attributes,@{$self->get_Member_Attribute_by_source('ENSEMBLPEP')};
  push @members_attributes,@{$self->get_Member_Attribute_by_source('Uniprot/SWISSPROT')};
  push @members_attributes,@{$self->get_Member_Attribute_by_source('Uniprot/SPTREMBL')};
  
  my %attribute_hash;
  foreach my $member_attribute (@members_attributes) {
    my ($member, $attribute) = @{$member_attribute};
    $attribute_hash{$member->stable_id} = $attribute;
  }

      #assign cigar_line to each of the member attribute
  foreach my $seq ($aln->each_seq) {
    my $attribute = $attribute_hash{$seq->display_id};
    if($attribute) {

        my $cigar_line = '';
        while($seq->seq() =~/(?:\b|^)(.)(.*?)(?:\b|$)/g) {
            $cigar_line .= ($2 ? length($2)+1 : '').(($1 eq '-') ? 'D' : 'M');
        }

        $attribute->cigar_line($cigar_line);

    } else {

        my $id = $seq->display_id;
        throw("No member for alignment portion: [$id]");

    }
  }

        # either store everything or nothing:
    if($store) {
        my $family_adaptor = $self->adaptor();

        foreach my $member_attribute (@members_attributes) {
            $family_adaptor->update_relation($member_attribute);
        }
    }
}

sub get_SimpleAlign {
  my $self = shift;

  my $sa = Bio::SimpleAlign->new();

  #Hack to try to work with both bioperl 0.7 and 1.2:
  #Check to see if the method is called 'addSeq' or 'add_seq'
  my $bio07 = 0;
  if(!$sa->can('add_seq')) {
    $bio07 = 1;
  }

  my @members_attributes;

  push @members_attributes,@{$self->get_Member_Attribute_by_source('ENSEMBLPEP')};
  push @members_attributes,@{$self->get_Member_Attribute_by_source('Uniprot/SWISSPROT')};
  push @members_attributes,@{$self->get_Member_Attribute_by_source('Uniprot/SPTREMBL')};

  foreach my $member_attribute (@members_attributes) {
    my ($member, $attribute) = @{$member_attribute};
    my $seqstr = $attribute->alignment_string($member);
    next if(!$seqstr);
    my $seq = Bio::LocatableSeq->new(-SEQ    => $seqstr,
                                     -START  => 1,
                                     -END    => length($seqstr),
                                     -ID     => $member->stable_id,
                                     -STRAND => 0);

    if($bio07) {
      $sa->addSeq($seq);
    } else {
      $sa->add_seq($seq);
    }
  }

  return $sa;
}

=head2 get_all_taxa_by_member_source_name

  Arg [1]    : string $source_name
               e.g. "ENSEMBLPEP"
  Example    : 
  Description: Returns the distinct taxons found in this family across
               the specified source. If you do not specify a source then
               the code will return all taxons in this family.
  Returntype : array reference of distinct Bio::EnsEMBL::Compara::NCBITaxon 
               objects found in this family
  Exceptions : 
  Caller     : public

=cut

sub get_all_taxa_by_member_source_name {
  my ($self, $source_name) = @_;
  my $ncbi_ta = $self->adaptor->db->get_NCBITaxonAdaptor();
  my $sub = sub {
  	my ($row) = @_;
  	return $ncbi_ta->fetch_node_by_taxon_id($row->[0]);
  };
  my $results = $self->_run_finder_by_member_field_source_name(
		'taxa', $source_name, $sub);
	return $results;
}

=head2 get_all_GenomeDBs_by_member_source_name

  Arg [1]    : string $source_name
               e.g. "ENSEMBLPEP"
  Example    : 
  Description: Returns the distinct GenomeDBs found in this family. Please note
               that if you specify a source other than an EnsEMBL based one
               the chances of getting back GenomeDBs are very low.
  Returntype : array reference of distinct Bio::EnsEMBL::Compara::GenomeDB 
               objects found in this family
  Exceptions : 
  Caller     : public

=cut

sub get_all_GenomeDBs_by_member_source_name {
	my ($self, $source_name) = @_;
	my $gdb_a = $self->adaptor->db->get_GenomeDBAdaptor();
	my $sub = sub {
		my ($row) = @_;
		return $gdb_a->fetch_by_dbID($row->[0]);
	};
	my $results = $self->_run_finder_by_member_field_source_name(
		'genome_db', $source_name, $sub);
	return $results;
}

=head2 _run_finder_by_member_field_source_name

  Arg [1]    : string $entity
               e.g. 'taxa' or 'genome_db'
  Arg [2]    : string $source_name (not required)
               e.g. 'ENSEMBLPEP'
  Arg [3]    : code $sub
               e.g. 'taxa' or 'genome_db'          
  Example    : 
  Description: 
  Returntype : array reference of distinct objects as returned by your 
               subroutine 
  Exceptions : If an unknown entity has been given
  Caller     : private

=cut

sub _run_finder_by_member_field_source_name {
	my ($self, $entity, $source_name, $sub) = @_;
	
	my $field;
	if($entity eq 'genome_db') {
		$field = 'genome_db_id';
	}
	elsif($entity eq 'taxa') {
		$field = 'taxon_id';
	}
	exception("Unknown entity type given [$entity].") unless $field;
	
	my $sql = "SELECT distinct(m.${field})
             FROM family_member fm,member m
             WHERE fm.family_id= ? 
             AND fm.member_id=m.member_id";
  my @args = ($self->dbID());
  
  if (defined $source_name) {
    $sql .= ' AND m.source_name = ?';
    push(@args, $source_name);
  }
  
  my @results;
  
  my $sth = $self->adaptor()->dbc()->prepare($sql);
  $sth->execute(@args);
  while (my $rowarray = $sth->fetchrow_arrayref()) {
  	if(defined $rowarray->[0]) {
  		my $val = $sub->($rowarray);
  		push(@results, $val);
  	}
  }
  $sth->finish();
  
  return \@results;
}

1;
