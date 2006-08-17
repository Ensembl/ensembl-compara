package EnsEMBL::Web::Object::Alignment;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Object;
our @ISA = qw(  EnsEMBL::Web::Object );

sub class  {
  my $self = shift;
  $self->__data->{'class'} = shift if @_;
  return $self->__data->{'class'};
}

sub get_alignment{
  my $self = shift;
  my $ext_seq   = shift || return undef();
  my $int_seq   = shift || return undef();
  my $seq_type  = shift || return undef();

  warn "this method is also in the factory, should be deprecated in one of the two!";

  my $int_seq_file = $self->save_seq($int_seq);
  my $ext_seq_file = $self->save_seq($ext_seq);

  my $out_file = time().int(rand()*100000000).$$;
  $out_file = $self->species_defs->ENSEMBL_TMP_DIR.'/'.$out_file.'out';

  my $command;
  if( $seq_type eq 'DNA' ){
    $command = sprintf( "%s/bin/matcher -sequencea %s -sequenceb %s -outfile %s",
            $self->species_defs->ENSEMBL_EMBOSS_PATH,
            $int_seq_file, $ext_seq_file, $out_file );
  } elsif( $seq_type eq 'PEP' ) {
    $command = sprintf( "%s/bin/psw -m %s/wisecfg/blosum62.bla %s %s > %s",
            $self->species_defs->ENSEMBL_WISE2_PATH,
            $self->species_defs->ENSEMBL_WISE2_PATH,
            $int_seq_file, $ext_seq_file, $out_file );
  } else {
    return undef();
  }

  `$command`;
  my $alignment = undef;
  if( open OUT, $out_file ) {
    while( <OUT> ){
      $alignment .= $_ unless /# Report_file/o;
    }
    unlink( $out_file );
  }
  unlink( $int_seq_file );
  unlink( $ext_seq_file );
 
  return $alignment;
}

sub save_seq {
  my $self = shift;
  my $content = shift ;
  my $seq_file = $self->species_defs->ENSEMBL_TMP_DIR.'/'."SEQ_".time().int(rand()*100000000).$$;
  open (TMP,">$seq_file") or die("Cannot create working file.$!");
  print TMP $content;
  close TMP;
  return $seq_file ;
}

1;
