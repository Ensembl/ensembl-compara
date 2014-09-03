#!/usr/local/bin/perl -w
=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

##################################
#
#  DEPRECATED MODULE
#
# The local BioPerl server is no
# longer in use, so this module is
# obsolete. It will be removed in
# Ensembl release 78.
#
##################################

package EnsEMBL::Web::ExtIndex::bioperl;
use strict;
use Bio::DB::SQL::DBAdaptor;
use Bio::SeqIO;

sub new {
warn "!!! DEPRECATED MODULE - will be removed in Release 78";
  my $class = shift;
  my $self = {};
  bless $self, $class;
  return $self;
}

sub get_seq_by_acc{ 
warn "!!! DEPRECATED MODULE - will be removed in Release 78";
my $self = shift; $self->get_seq_by_id( @_ ); }

sub get_seq_by_id{
warn "!!! DEPRECATED MODULE - will be removed in Release 78";
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
