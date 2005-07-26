package Bio::Das::FeatureIterator;

use strict;
require Exporter;
use Carp 'croak';
use vars qw($VERSION);

$VERSION = '0.01';

=head1 NAME

Bio::Das::FeatureIterator - Iterate over a set of Bio::Das::Features

=head1 SYNOPSIS

 my $iterator =  $das->features(-dsn => ['http://www.wormbase.org/db/das/elegans',
					 'http://dev.wormbase.org/db/das/elegans'
				        ],
			        -segment => ['I:1,10000','II:1,10000'],
			        -category => 'transcription',
			        -iterator => 1,
			      );
 while (my $feature = $iterator=>next_seq) {
   print $feature,"\n";
 }

=head1 DESCRIPTION

When the Bio::Das->features() method is called with the B<-iterator>
argument, the method will return an iterator over the features
returned from the various data sources. Each feature can be returned
by calling next_seq() iteratively until the method returns undef.

This is not as neat as it seems, because it works by creating all the
features in advance and storing them in memory.  For true pipelined
access to the features, call features() with a callback subroutine.

=cut

sub new {
  my $class = shift;
  $class = ref($class) if ref($class);

  my $features = shift;
  return bless {responses=>$features},$class;
}

sub next_seq {
  my $self = shift;

  return shift @{$self->{next_result}}
    if $self->{next_result} && @{$self->{next_result}};

  while (1) {
    return unless @{$self->{responses}};
    my $response = shift @{$self->{responses}};
    if ($response->can('results')) {
      my @r = $response->results;
      $self->{next_result} = \@r;
      return shift @{$self->{next_result}} if @{$self->{next_result}};
    } else {
      return $response;
    }
  }
}

=head1 AUTHOR

Lincoln Stein <lstein@cshl.org>.

Copyright (c) 2001 Cold Spring Harbor Laboratory

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=head1 SEE ALSO

L<Bio::Das::Request>, L<Bio::Das::HTTP::Fetch>,
L<Bio::Das::Segment>, L<Bio::Das::Type>, L<Bio::Das::Stylesheet>,
L<Bio::Das::Source>, L<Bio::RangeI>

=cut

1;
