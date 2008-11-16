package EnsEMBL::Web::Text::Feature::GFF;

use strict;

use base qw(EnsEMBL::Web::Text::Feature);

use Data::Dumper;

sub new {
  my( $class, $hash_ref ) = @_;
  return bless {
	  '__raw__'=>$hash_ref,
    '__extra__' => { map { /^(\w+)[=s+]([^;]+)/ ? ($1=>$2) : () } split /;\s*/, $hash->{'__raw__'}[16]
  },
	$_[0];
}

sub _seqname { my $self = shift; return $self->{'__raw__'}[0]; }
sub strand   { my $self = shift; return $self->_strand( $self->{'__raw__'}[12] ); }
sub rawstart { my $self = shift; return $self->{'__raw__'}[6]; }
sub rawend   { my $self = shift; return $self->{'__raw__'}[8]; }

sub id       {
  my $self = shift;
	local $Data::Dumper::Indent = 0;
	warn Dumper( $self->{'__extra__'} );
	return $self->{'__extra__'}{'transcript_id'} ||
	       $self->{'__extra__'}{'hid'}           ||
				 $self->{'__raw__'}[16]                ||
				 $self->{'__raw__'}[4]
}

sub hstart  { my $self = shift; return $self->{'__extra__'}{'hit_start'};  }
sub hend    { my $self = shift; return $self->{'__extra__'}{'hit_end'};    }

sub slide   {
  my $self = shift; my $offset = shift;
  $self->{'start'} = $self->{'__raw__'}[6]+ $offset;
  $self->{'end'}   = $self->{'__raw__'}[8]+ $offset;
}

sub cigar_string {
  my $self = shift;
  return $self->{'_cigar'}||=($self->{'__raw__'}[8]-$self->{'__raw__'}[6]+1)."M";
}

1;
