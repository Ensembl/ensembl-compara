package Bio::Das::Request::Feature2Segments;
# $Id$
# this module issues and parses the features command with the feature_id argument

=head1 NAME

Bio::Das::Request::Feature2Segments - Translate feature names into segments

=head1 SYNOPSIS

 my @segments             = $request->results;
 my $das_command          = $request->command;
 my $successful           = $request->is_success;
 my $error_msg            = $request->error;
 my ($username,$password) = $request->auth;

=head1 DESCRIPTION

This is a subclass of L<Bio::Das::Request> specialized for the
"features" command with specialized arguments that allow it to
translate a feature name into a segment of the genome.  It works by
issuing the DAS features command using a type of NULL (which is an
invalid feature type) and a feature_id argument.  It is used to
implement the Bio::Das->get_feature_by_name() method.

The results() method returns a series of L<Bio::Das::Segment> objects.
All other methods are as described in L<Bio::Das::Request>.  .

=head1 AUTHOR

Lincoln Stein <lstein@cshl.org>.

Copyright (c) 2003 Cold Spring Harbor Laboratory

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=head1 SEE ALSO

L<Bio::Das::Request::Features>, L<Bio::Das::Request>,
L<Bio::Das::HTTP::Fetch>, L<Bio::Das::Segment>, L<Bio::Das::Type>,
L<Bio::Das::Stylesheet>, L<Bio::Das::Source>, L<Bio::RangeI>

=cut

use strict;
use Bio::Das::Type;
use Bio::Das::Segment;
use Bio::Das::Request;
use Bio::Das::Util 'rearrange';

use vars '@ISA';
@ISA = 'Bio::Das::Request';

sub new {
  my $pack = shift;
  my ($dsn,$class,$features,$das,$callback) = rearrange([['dsn','dsns'],
							 'class',
							 ['feature','features'],
							 'das',
							 'callback',
							],@_);
  my $qualified_features;
  if ($class && $das) {
    my $typehandler = Bio::Das::TypeHandler->new;
    my $types = $typehandler->parse_types($class);
    for my $a ($das->aggregators) {
      $a->disaggregate($types,$typehandler);
    }
    my $names = ref($features) ? $features : [$features];
    for my $t (@$types) {
      for my $f (@$names) {
	push @$qualified_features,"$t->[0]:$f";
      }
    }
  } else {
    $qualified_features = $features;
  }

  my $self = $pack->SUPER::new(-dsn => $dsn,
			       -callback  => $callback,
			       -args => { feature_id   => $qualified_features,
					  type         => 'NULL',
					} );
  $self->das($das) if defined $das;
  $self;
}

sub command { 'features' }
sub das {
  my $self = shift;
  my $d    = $self->{das};
  $self->{das} = shift if @_;
  $d;
}

sub t_DASGFF {
  my $self = shift;
  my $attrs = shift;
  if ($attrs) {
    $self->clear_results;
  }
  delete $self->{tmp};
}

sub t_GFF {
  # nothing to do here
}

sub t_SEGMENT {
  my $self = shift;
  my $attrs = shift;
  if ($attrs) {    # segment section is starting
    $self->{tmp}{current_segment} = Bio::Das::Segment->new($attrs->{id},$attrs->{start},
							   $attrs->{stop},$attrs->{version},
							   $self->das,$self->dsn
							  );
  } else {
    $self->add_object($self->{tmp}{current_segment});
  }

}

1;
