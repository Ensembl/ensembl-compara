package EnsEMBL::Web::Factory::Sequence;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::ExtIndex;

use Bio::SeqIO;
use Bio::Seq;
use IO::String;
use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Proxy::Object;

our @ISA = qw(  EnsEMBL::Web::Factory );

sub createObjects { 
  my $self     = shift;

  my $id       = $self->param( 'id' );
  my $fa_id    = $self->param( 'faid' );
  my $trace_id = $self->param( 'traceid' );

  my( $META, $seq1, $seq2 );

  if( $fa_id ) { ### We have a fasta identifier
    my $database = $self->database( 'fasta' );
    return $self->problem( 'fatal', 'Database Error', "Could not connect to the FASTA database." ) unless $database;
    eval{ $META = $database->fetch_fasta_table_metadata($fa_id); };
    return $self->problem( 'fatal', 'Unknown sequence database', "The database table $fa_id could not be found in @{[$database->db->dbname]}" ) unless $META;
    if( $id =~ /(\S+):(\S+)\-(\S+)/ ) {
      eval {
        ($seq1) = $database->fetch_fasta_by_id($fa_id, $2 );
        ($seq2) = $database->fetch_fasta_by_id($fa_id, $3 );
      };
    } elsif(  $id =~/\S+/ ) {
      eval {
        ($seq1) = $database->fetch_fasta_by_id($fa_id, $id );
      };
    } else {
      return $self->problem( 'fatal', 'Unknown sequence database', "The sequence $id could not be found in the Ensembl database" );
    }
    if( $@ || !$seq1 ) {
      return $self->problem( 'fatal', "Unknown FASTA entry",
             "The FASTA entry $id can not be found in the Ensembl database." );

    }
  } elsif($id||$trace_id) { # TODO: use the ExtIndex modules!
    my $ei = EnsEMBL::Web::ExtIndex->new( $self->species_defs );
    $ei->get_indexer( 'DEFAULT' );
    if( $ei ) {
      my $temp = join '', @{ $ei->get_seq_by_id({'DB'=>'DEFAULT','ID'=>$id||$trace_id,'OPTIONS'=>'seq'})||[] };
      if( $temp ) {
        my $stringio = IO::String->new($temp);
        my $in = Bio::SeqIO->new(-fh => $stringio , '-format' => 'Fasta');
        $seq1 = $in->next_seq();
        $META = { 'title' => "pfetched sequence" };
      }
    }
  }
  if( $seq1 ) {
    my $dataobject = EnsEMBL::Web::Proxy::Object->new( 'Sequence', [$seq1,$seq2], $self->__data );
    $dataobject->__data->{'_meta_data'} = $META;
    $self->DataObjects($dataobject);
  } else { 
    $self->problem('fatal', 'Unknown Sequence ID', "The sequence $id could not be found in the Ensembl database");
  }
}

1;

