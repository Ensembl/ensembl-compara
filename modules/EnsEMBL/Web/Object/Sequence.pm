package EnsEMBL::Web::Object::Sequence;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Object;
our @ISA = qw(  EnsEMBL::Web::Object );

sub fetch_fastaData {
  my $self = shift;
  my %fasta_data1;
  my %fasta_data2;
        
  my $seq1 = $self->Obj->[0];
  my $seq2 = $self->Obj->[1];
    
  return unless $seq1;
     
  $fasta_data1{'id'}           = $seq1->id();
  $fasta_data1{'description'}  = $seq1->desc();
  $fasta_data1{'sequence'}     = $seq1->primary_seq->seq();
  if( $seq2 ){
    $fasta_data2{'id'} = $seq2->id();
    $fasta_data2{'description'}  = $seq2->desc();        
    $fasta_data2{'sequence'}  = $seq2->primary_seq->seq();
  }   
        
  return (\%fasta_data1, \%fasta_data2);
}

sub fetch_fastaMeta { return $_[0]->__data->{'_meta_data'}->{$_[1]}; }

1;
