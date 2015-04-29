=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Text::Feature::GFF;

use strict;
use warnings;
no warnings 'uninitialized';

use URI::Escape qw(uri_unescape);

use base qw(EnsEMBL::Web::Text::Feature);

sub new {
  my ($class, $args) = @_;
  my $extra = {};
  
  if ($args->[16] =~ /=/) {
    my @T = split /;\s*/, $args->[8];
    
    foreach (@T) {
      if (/=/) {
        my($k, $v)= split /=/, $_, 2;
        
        $k =~ s/^\s+//;
        $k =~ s/\s+$//;
        $v =~ s/^\s+//;
        $v =~ s/\s+$//;
        $v =~ s/^"([^"]+)"$/$1/;
        
        push @{$extra->{$k}},$v;
        
        $extra->{'_type'} = [ 'transcript' ]            if $k eq 'transcript_id';
        $extra->{'_type'} = [ 'prediction_transcript' ] if $k eq 'genscan';
        $extra->{'_type'} = [ 'alignment' ]             if $k eq 'hid';
      } else {
        push @{$extra->{'notes'}}, $_;
      }
    }
  }
  
  $extra->{'source'}       = [ $args->[1] ];
  $extra->{'feature_type'} = [ $args->[2] ];
  $extra->{'score'}        = [ $args->[5] ];
  $extra->{'frame'}        = [ $args->[7] ];
  
  my @attrs   = split /;\s?/, $args->[8];
  my %attribs = map uri_unescape($_), map split(/[\s=]/, $_, 2), @attrs;
  
  return bless { __raw__ => $args, __extra__ => $extra, __attribs__ => \%attribs }, $class;
}

sub coords {
  my ($self, $data) = @_;
  return ($data->[0], $data->[3], $data->[4]);
}

sub _seqname { my $self = shift; return $self->{'__raw__'}[0]; }
sub strand   { my $self = shift; return $self->_strand( $self->{'__raw__'}[6] ); }
sub rawstart { my $self = shift; return $self->{'__raw__'}[3]; }
sub rawend   { my $self = shift; return $self->{'__raw__'}[4]; }

sub id       {
  my $self = shift;

  foreach my $key (qw(transcript_id genscan hid)) {
    my $v = $self->{'__extra__'}->{$key};
    return $v->[0] if defined $v;
  }
  foreach my $key (qw(hid ID)) {
    my $v = $self->{'__attribs__'}->{$key};
    return $v if defined $v;    
  }
  foreach my $column (8,2) {
    my $v = $self->{'__raw__'}->[$column];
    return $v if $v;
  }
  return $self->{'__raw__'}->[2];
}

sub attrib { my ($self, $attrib) = @_; return $self->{'__attribs__'} ? $self->{'__attribs__'}{$attrib} : undef ;  }
sub attribs { my $self = shift; return $self->{'__attribs__'} ? $self->{'__attribs__'} : {} ;  }
sub hstart  { my $self = shift; return $self->{'__extra__'}{'hstart'}  ? $self->{'__extra__'}{'hstart'}[0]  : undef ;  }
sub hend    { my $self = shift; return $self->{'__extra__'}{'hend'}    ? $self->{'__extra__'}{'hend'}[0]    : undef ; }
sub hstrand { my $self = shift; return $self->{'__extra__'}{'hstrand'} ? $self->{'__extra__'}{'hstrand'}[0] : 1 ; }
sub external_data { my $self = shift; return $self->{'__extra__'} ? $self->{'__extra__'} : undef ; }


sub cigar_string {
  my $self = shift;
  if($self->{'__attribs__'}->{'Gap'}) {
    # We have an alignment string, so use it.
    my $gap = $self->{'__attribs__'}->{'Gap'};
    # convert GFF gap format to CIGAR
    # In a GFF, Gap attrib "I" means an insert wrt reference, but as we 
    # are probably displaying /on/ reference, we actually need a D 
    # meaning ref has missing sequence, and vice-versa. Should probably 
    # make this configurable, but this seems like the most common 
    # detault, hence the tr///. -- ds23
    my $flip_cigar_sense = 0;
    my @steps = map {
      s/(\D)(\d+)/$2$1/; 
      tr/ID/DI/ if($flip_cigar_sense);
      $_; 
    } split(/[+ ]/,$gap);
    return $self->{'_cigar'} ||= join("",@steps);
  }
  return $self->{'_cigar'}||=($self->{'__raw__'}[4]-$self->{'__raw__'}[3]+1)."M";
}

sub extra_data {
  my $self = shift;
  my @skip = $self->{__extra__}{'transcript_id'} ? qw(transcript_id)
           : $self->{__extra__}{'genscan'}       ? qw(genscan) 
           : $self->{__extra__}{'hid'}           ? qw(hid) 
           :                                       ()
           ;
  push @skip,qw(hstart hend hstrand);
  my %skip = map {($_,1)} @skip;
  my %extra = map { $skip{$_}?():($_,$self->{__extra__}{$_}) } keys %{$self->{__extra__}||{}};

  return \%extra;
}

sub display_id {
  my ($self) = @_;
  
  return $self->{'__attribs__'}->{'ID'};
}

1;
