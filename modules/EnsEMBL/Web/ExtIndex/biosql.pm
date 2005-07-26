package EnsEMBL::Web::ExtIndex::biosql;

use strict;
use Bio::DB::BioDB;
use Bio::Seq::RichSeq;

sub new{
  my $class = shift;
  my $self = bless {
    'db' => Bio::DB::BioDB->new(@_)
  }, $class;
  return $self;
}    

sub get_seq_by_acc { my $self = shift; return $self->get_seq_by_id( @_ ); }

sub get_seq_by_id {
  my( $self, $args ) = @_;
  my $seq_adaptor = $self->{db}->get_object_adaptor( 'Bio::SeqI' );
  my $seq = Bio::Seq::RichSeq->new(
    -accession_number => $args->{ 'ID' },
    -namespace        => $args->{ 'biodb_namespace' }
  );
  $seq = $seq_adaptor->find_by_unique_key( $seq );
  return $seq;
}

1;
