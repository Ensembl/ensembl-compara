package Bio::EnsEMBL::Compara::Family;

use strict;
use Bio::EnsEMBL::Compara::BaseRelation;
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
     my ($dbid, $stable_id, $description, $description_score, $adaptor) = $self->_rearrange([qw(DESCRIPTION_SCORE)], @args);
      
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
  $FH->open($file) || $self->throw("Could not open alignment file [$file]");

  <$FH>; #skip header
  while(<$FH>) {
    next if($_ =~ /^\s+/);  #skip lines that start with space
    
    my ($id, $align) = split;
    $align_hash{$id} ||= '';
    $align_hash{$id} .= $align;
  }

  $FH->close;

  #place all family members in a hash on their names
  my %member_hash;
  foreach my $member (@{$self->get_all_members}) {
    $member_hash{$member->stable_id} = $member;
  }

  #assign alignment strings to each of the members
  foreach my $id (keys %align_hash) {
    my $member = $member_hash{$id};
    if($member) {
      $member->alignment_string($align_hash{$id});
    } else {
      $self->warn("No member for alignment portion: [$id]");
    }
  }
}

1;
