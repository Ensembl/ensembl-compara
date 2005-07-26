#!/usr/local/bin/perl -w

package EnsEMBL::Web::ExtIndex::WEBSRS;
require LWP::UserAgent;

use strict;

sub new {
  my $class = shift;
  my $self = {
    'options' => {
      'id'   => '+-f+id',
      'acc'  => '+-f+acc',
      'seq'  => '+-f+seq',
      'desc' => '+-f+des',
      'all'  =>  '-e',
    }
  };
  bless $self, $class;
  return $self;
}

sub get_seq_by_id  { my ($self, $args)=@_; return $self->query_server( "id",  $args); }
sub get_seq_by_acc { my ($self, $args)=@_; return $self->query_server( "acc", $args); }

sub query_server {
  my ($self, $type, $args) = @_;
  
  my $db = lc($args->{'DB'});
  $db = '{embl_SP_emblnew}'       if $db eq 'emblnew'   || $db eq 'embl';
  $db = '{swissprot_SP_swissnew}' if $db eq 'swissnew'  || $db eq 'swissprot';
  $db = '{sptrembl_SP_tremblnew}' if $db eq 'tremblnew' || $db eq 'sptrembl';
  $db = "$db-type";

  my $query  = "$args->{'EXE'}?[$db:$args->{'ID'}]".
               ( $self->{'options'}{$args->{'OPTIONS'}} || $self->{'options'}{'all'} );
  print STDERR "$query\n";
  my $ua       = LWP::UserAgent->new;
  my $request  = HTTP::Request->new('GET', $query);
  my $response = $ua->request($request); # or
  my $str      = $response->as_string;
    print STDERR "$str\n"; 
  my @lines    = split(/\n/,$str);
  my @output;
  my $foundseq = 0;
  
  foreach my $line (@lines) {
    $line =~ s/<.*?>//g;
    chomp;
       if( $line =~ s/^DE\s+//)                                { push @output, $line ; }
    elsif( $args->{'OPTIONS'} eq 'all' )                       { push @output, $line ; }
    elsif( $args->{'OPTIONS'} eq 'id'  && $line =~ s/^ID\s+//) { push @output, $line ; }
    elsif( $args->{'OPTIONS'} eq 'acc' && $line =~ s/^AC\s+//) { push @output, $line ; }
    elsif( $args->{'OPTIONS'} eq 'seq' && $line =~ /^>/)       { $foundseq = 1;        }
    elsif( $args->{'OPTIONS'} eq 'seq' && $foundseq == 1)      { push @output, $line ; }
    elsif( $args->{'OPTIONS'} eq 'seq' && $line =~ /^</)       { $foundseq = 0;        }
  } 
  return \@output;
}
    
1;
