package EnsEMBL::Web::ExtIndex::SRS;
use strict;

sub new {
  my $class = shift;
  my $self = {
    'options' => {
      'id'    =>  ['-f','id'],
      'acc'   =>  ['-f','acc'],
      'seq'   =>  ['-f','seq'],
      'desc'  =>  ['-f','des'],
      'all'   =>  ['-e'],
    }
  };
  bless $self, $class;
  return $self;
}

sub get_seq_by_id {
  my ($self, $args)=@_;
  return $self->_get( "$args->{'DB'}-id", $args );
}

sub get_seq_by_acc {
  my ($self, $args)=@_;
  return $self->_get( "$args->{'DB'}-acc", $args );
}

sub _get {
  my( $self,$db, $args ) = @_;
  my $pid='';
  my @output;
    
  unless (defined ($pid=open(READABLE_CHILD, "-|"))){
    warn "Cannot fork Readable_child for _get SRS: $!\n";
    return undef;
  }

  if ($pid){  # I'm the Daddy!
    @output=<READABLE_CHILD>;
    close READABLE_CHILD;
  } else {      # I'm the child 
    unless( exec( $args->{'EXE'},
       @{$self->{'options'}{$args->{'OPTIONS'}}||$self->{'options'}{'all'}},
       "[$db:$args->{'ID'}]"
    ) ) {
      warn "Cannot exec SRS call $!\n";
      return undef;
    }
  }
  return \@output;
}

1;
