
#
# Ensembl module for Bio::EnsEMBL::Compara::Utils
#
# Cared for by Ewan Birney <birney@ebi.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::Utils - Function bag for general useful functions 

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


package Bio::EnsEMBL::Compara::Utils;
use vars qw(@ISA);
use strict;

# Object preamble


=head2 dual_AlignBlockSet_from_FeaturePair_list

 Title   : dual_AlignBlockSet_from_FeaturePair_list
 Usage   : $abs = Bio::EnsEMBL::Compara::Utils::dual_AlignBlockSet_from_Feature_list
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub dual_AlignBlockSet_from_FeaturePair_list {
   my ($self,@fp) = @_;

   # sort by start position of the first sequence
   @fp = sort { $a <=> $b } @fp;

   my $pos = 1;

   my $anchor = Bio::EnsEMBL::Compara::AlignBlockSet->new();
   my $hung   = Bio::EnsEMBL::Compara::AlignBlockSet->new();

   foreach my $f ( @fp ) {
       my $len = $f->length;

       # first position is in perfect sync
       my $al = Bio::EnsEMBL::Compara::AlignBlock->new();
       $al->align_start($pos);
       $al->align_end($pos+$len-1);
       
       $al->start($f->start);
       $al->end($f->end);
       $al->strand($f->strand);

       $anchor->add_AlignBlock($al);

       my $al2 = Bio::EnsEMBL::Compara::AlignBlock->new();
       $al2->align_start($pos);
       $al2->align_end($pos+$len-1);
       
       $al2->start($f->hstart);
       $al2->end($f->hend);
       $al2->strand($f->hstrand);

       $hung->add_AlignBlock($al2);
   }
  
   #
   # We should have a rationalisation function probably
   #
     
   return($anchor,$hung);

}


1;
