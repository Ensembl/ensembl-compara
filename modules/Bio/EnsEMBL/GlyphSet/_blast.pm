package Bio::EnsEMBL::GlyphSet::_blast;

use strict;
use warnings;
no warnings 'uninitialized';

use Bio::EnsEMBL::External::BlastAdaptor;

use base qw(Bio::EnsEMBL::GlyphSet::_alignment);


sub _blast_adaptor {
  my $self = shift;
  unless( exists $self->{'container'}{'blast_adaptor'} ) {
    my $db_info = $self->{'config'}->species_defs->multidb->{'DATABASE_BLAST'};
    my $ba = undef;
    if( $db_info ) {
      $ba = Bio::EnsEMBL::External::BlastAdaptor->new(
        -dbname => $db_info->{NAME},
        -user   => $db_info->{USER},
        -pass   => $db_info->{PASS},
        -host   => $db_info->{HOST},
        -port   => $db_info->{PORT},
        -driver => $db_info->{DRIVER},
      );
    }
    $self->{'container'}{'blast_adaptor'} = $ba;
  }
  return $self->{'container'}{'blast_adaptor'};
}

sub _das_link {
  my $self = shift;
  return undef;
}

sub feature_group {
  my( $self, $f ) = @_;
  return $f->hseqname; 
}

sub feature_title {
  my( $self, $f, $db_name ) = @_;
  my( $qryname, $hsptoken ) = split( ':', $f->hseqname );
  return sprintf 'Blast hit %s; Score %s; %%age ID: %s; Length: %s%s',
    $qryname,
    $f->score,
    $f->percent_id,
    $f->length,
    $f->p_value ? ("; P-value: ".$f->p_value) : '';
}

sub features {
  my ($self) = @_;
  my %results;
  my $ba = $self->_blast_adaptor;
  return unless $ba;
  my $offset = $self->{'container'}->start-1;
  foreach my $T ( $self->highlights ) {
    next unless $T =~ /BLAST_NEW:(.*)/;
    my $ticket_id = $1;
    eval { 
      my $f_arrayref = $self->{'container'}{'blast_adaptor'}->get_all_SearchFeatures($ticket_id,
        $self->{'container'}->seq_region_name,
        $self->{'container'}->start,
        $self->{'container'}->end,
      ); 
      foreach (@$f_arrayref) {
        $_->start( $_->start - $offset );
        $_->end(   $_->end   - $offset );
      }
      $results{"Ticket: $ticket_id"} = [$f_arrayref];
    }; 
    warn $@ if $@;
  }
  return %results;
}

sub href {
### Links to /Location/Genome
  my( $self, $f ) = @_;

  my( $qryname, $hsptoken ) = split( ':', $f->hseqname );
  my( $ticket, $id, $date ) = split /!!/,$hsptoken;
  return sprintf '/Multi/blastview?ticket=%s;hsp_id=%s!!%s;_display=ALIGN',
    $ticket, $id,$date;
}


1;
