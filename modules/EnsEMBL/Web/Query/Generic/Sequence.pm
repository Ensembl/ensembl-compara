package EnsEMBL::Web::Query::Generic::Sequence;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Query::Generic::Base);

sub fixup_transcript {
  my ($self,$key,$sk,$tk) = @_;

  if($self->phase eq 'pre_process') {
    my $data = $self->data;
    $data->{$key} = $data->{$key}->stable_id if $data->{$key};
  } elsif($self->phase eq 'pre_generate') {
    my $data = $self->data;
    #$data->{"__orig_$key"} = $data->{$key};
    my $ad = $self->source('Adaptors');
    if($data->{$key}) {
      $data->{$key} =
        $ad->transcript_by_stableid($data->{$sk},$data->{$tk},$data->{$key});
    }
  }
}

sub loop_transcripts {
  my ($self,$args) = @_;

  my $all = $self->source('Adaptors')->
              transcript_adaptor($args->{'species'},$args->{'type'})->fetch_all;
  my @out;
  foreach my $t (@$all) {
#    next unless $t->stable_id eq 'ENST00000380152';
    my %out = %$args;
    $out{'species'} = $args->{'species'};
    $out{'type'} = $args->{'type'};
    $out{'transcript'} = $t->stable_id;
    $out{'__name'} = $t->stable_id;
    push @out,\%out;
  }
  return \@out;
}


1;
