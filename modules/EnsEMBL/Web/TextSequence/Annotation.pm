package EnsEMBL::Web::TextSequence::Annotation;

use strict;
use warnings;

use List::MoreUtils qw(any);

sub new {
  my ($proto,$p) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    phases => $p,
    view => undef,
  };
  bless $self,$class;
  return $self;
}

sub too_rare_snp {
  my ($self,$in,$config) = @_;

  return 0 unless $config->{'hide_rare_snps'} and $config->{'hide_rare_snps'} ne 'off';
  my $val = abs $config->{'hide_rare_snps'};
  my $mul = ($config->{'hide_rare_snps'}<0)?-1:1;
  my $maf = $in;
  $maf = $in->minor_allele_frequency if ref $in;
  return ($mul>0) unless $maf;
  return ($maf - $val)*$mul < 0;
}

sub hidden_source {
  my ($self,$val,$config) = @_;

  my $source = $val;
  $source = $val->source_name if ref $val;
  $source ||= '';
  return any { $source eq ($_||'') } @{$config->{'hidden_sources'}||[]};
}


sub view { $_[0]->{'view'} = $_[1] if @_>1; return $_[0]->{'view'}; }
sub phases { $_[0]->{'phases'} = $_[1] if @_>1; return $_[0]->{'phases'}; }

sub name { return ref $_[0]; }
sub replaces { return undef; }

sub prepare_ropes {}

sub add_rope { my $self = shift; return $self->{'view'}->new_sequence(@_); }

1;
