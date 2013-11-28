=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

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
