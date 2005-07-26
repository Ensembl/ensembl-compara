#!/usr/local/bin/perl -w

package EnsEMBL::Web::ExtIndex::bioperl;
use strict;
use Bio::DB::SQL::DBAdaptor;
use Bio::SeqIO;

sub new {
  my $class = shift;
  my $self = {};
  bless $self, $class;
  return $self;
}

sub get_seq_by_acc{ my $self = shift; $self->get_seq_by_id( @_ ); }

sub get_seq_by_id{
  my ($self, $args)=@_;
  my $db = Bio::DB::SQL::DBAdaptor->new(
    -user   => 'ensro',
    -dbname => 'bioperldb',
    -host   => 'ensrv1',
    -driver => 'mysql'
  );

  my $biodbad = $db->get_BioDatabaseAdaptor();
  my $name = 'EMBL';
     $name = 'EMBL' if $args->{'DB'} eq 'EMBLNEW';
  my $seq;
  eval {
    my $biodb = $biodbad->fetch_BioSeqDatabase_by_name( $name );
    $seq   = $biodb->get_Seq_by_acc( $args->{'ID'} );
  };
  return undef if $@;
  my @arr;
  push @arr, my $empty_var;
  if( $args->{'OPTIONS'} eq 'desc' ) {
    push @arr, $seq->desc;
    return \@arr;
  } elsif($args->{'OPTIONS'} eq 'seq') {
    push @arr, $seq->seq;
    return \@arr;
  } elsif ($args->{'OPTIONS'} eq 'id') {
    push @arr, $seq->id;
    return \@arr;
  } else {
    print STDERR "CALLING ALL ON INDEXER\n";
  }
  return \@arr;
}

1;
