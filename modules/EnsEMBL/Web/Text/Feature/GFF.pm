package EnsEMBL::Web::Text::Feature::GFF;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Text::Feature);

sub new {
  my( $class, $hash_ref ) = @_;

  my $extra = {};

  if( $hash_ref->[16] =~ /=/ ) {
    my @T = split /;\s*/, $hash_ref->[16];
    foreach (@T) {
      if( /=/ ) {
        my($k,$v)= split /=/, $_, 2;
        $k =~ s/^\s+//;
        $k =~ s/\s+$//;
        $v =~ s/^\s+//;
        $v =~ s/\s+$//;
        $v =~ s/^"([^"]+)"$/$1/;
        push @{$extra->{$k}},$v;
        $extra->{'_type'} = ['transcript']            if $k eq 'transcript_id';
        $extra->{'_type'} = ['prediction_transcript'] if $k eq 'genscan';
        $extra->{'_type'} = ['alignment']             if $k eq 'hid';
      } else {
        push @{$extra->{'notes'}},$_;
      }
    }
  }
  $extra->{'source'}       = [ $hash_ref->[2] ];
  $extra->{'feature_type'} = [ $hash_ref->[4] ];
  $extra->{'frame'}        = [ $hash_ref->[14]];
  return bless { '__raw__' => $hash_ref, '__extra__' => $extra }, $class;
}

sub _seqname { my $self = shift; return $self->{'__raw__'}[0]; }
sub strand   { my $self = shift; return $self->_strand( $self->{'__raw__'}[12] ); }
sub rawstart { my $self = shift; return $self->{'__raw__'}[6]; }
sub rawend   { my $self = shift; return $self->{'__raw__'}[8]; }

sub id       {
  my $self = shift;

# use Data::Dumper; local $Data::Dumper::Indent = 0; warn Dumper($self->{'__extra__'});
  return $self->{'__extra__'}{'transcript_id'} ? $self->{'__extra__'}{'transcript_id'}[0]
       : $self->{'__extra__'}{'genscan'      } ? $self->{'__extra__'}{'genscan'}[0]
       : $self->{'__extra__'}{'hid'          } ? $self->{'__extra__'}{'hid'}[0]
       : $self->{'__raw__'}[16]                ? $self->{'__raw__'}[16]
       :                                         $self->{'__raw__'}[4]
       ;
}

sub hstart  { my $self = shift; return $self->{'__extra__'}{'hstart'}  ? $self->{'__extra__'}{'hstart'}[0]  : undef ;  }
sub hend    { my $self = shift; return $self->{'__extra__'}{'hend'}    ? $self->{'__extra__'}{'hend'}[0]    : undef ; }
sub hstrand { my $self = shift; return $self->{'__extra__'}{'hstrand'} ? $self->{'__extra__'}{'hstrand'}[0] : undef ; }

sub slide   {
  my $self = shift; my $offset = shift;
  $self->{'start'} = $self->{'__raw__'}[6]+ $offset;
  $self->{'end'}   = $self->{'__raw__'}[8]+ $offset;
}

sub cigar_string {
  my $self = shift;
  return $self->{'_cigar'}||=($self->{'__raw__'}[8]-$self->{'__raw__'}[6]+1)."M";
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
1;
