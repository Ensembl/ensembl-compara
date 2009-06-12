package EnsEMBL::Web::Component::Transcript::ExternalRecordAlignment;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);
use EnsEMBL::Web::ExtIndex;
use EnsEMBL::Web::Document::HTML::TwoCol;
use POSIX;


#use Data::Dumper;
#$Data::Dumper::Maxdepth = 3;

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub caption {
  return undef;
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $trans = $object->Obj;
  my $tsi = $object->stable_id;
  my $input = $object->input;
  my $hit_id = $input->{'sequence'}->[0];

  #get external sequence and type (DNA or PEP)
  my $ext_seq = $object->get_ext_seq( $hit_id);
  $ext_seq =~ s /^ //mg; #remove white space from the beginning of each line of sequence
  my $seq_type = $object->determine_sequence_type( $ext_seq );

  #get transcript sequence
  my $trans_sequence = $object->get_int_seq($trans,$seq_type)->[0];

  #get transcript alignment
  my $html;
  if ($ext_seq) {
    my $trans_alignment = $object->get_alignment( $ext_seq, $trans_sequence, $seq_type );
    $html = qq(<p>Alignment between external feature $hit_id and transcript ID $tsi</p><p><pre>$trans_alignment</pre></p>);
  }
  else {
    $html = qq(<p>Unable to retrieve sequence for $hit_id</p>);
  }
  return $html;
}		

1;

