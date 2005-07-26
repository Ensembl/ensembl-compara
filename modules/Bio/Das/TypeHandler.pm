package Bio::Das::TypeHandler;
use strict;

=head1 NAME

Bio::Das::TypeHandler -- Utilities for handling types

=head1 SYNOPSIS

This is to be replaced by ontology-based types very soon.

=cut

=head1 METHODS

=head2 new

 Title   : new
 Usage   : $typehandle = Bio::Das::TypeHandler->new;
 Function: create new typehandler
 Returns : a typehandler
 Args    : a verbose/debug flag (optional)

=cut

sub new {
  my $class = shift;
  my $verbose = shift;
  return bless {verbose=>$verbose},$class;
}

sub debug {
  my $self = shift;
  my $d = $self->{verbose};
  $self->{verbose} = shift if @_;
  $d;
}

=head2 parse_types

 Title   : parse_types
 Usage   : $db->parse_types(@args)
 Function: parses list of types
 Returns : an array ref containing ['method','source'] pairs
 Args    : a list of types in 'method:source' form
 Status  : internal

This method takes an array of type names in the format "method:source"
and returns an array reference of ['method','source'] pairs.  It will
also accept a single argument consisting of an array reference with
the list of type names.

=cut

# turn feature types in the format "method:source" into a list of [method,source] refs
sub parse_types {
  my $self  = shift;
  return [] if !@_ or !defined($_[0]);

  my @types = ref($_[0]) eq 'ARRAY' ? @{$_[0]} : @_;
  my @type_list = map { [split(':',$_,2)] } @types;
  return \@type_list;
}

=head2 make_match_sub

 Title   : make_match_sub
 Usage   : $db->make_match_sub($types)
 Function: creates a subroutine used for filtering features
 Returns : a code reference
 Args    : a list of parsed type names
 Status  : protected

This method is used internally to generate a code subroutine that will
accept or reject a feature based on its method and source.  It takes
an array of parsed type names in the format returned by parse_types(),
and generates an anonymous subroutine.  The subroutine takes a single
Bio::DB::GFF::Feature object and returns true if the feature matches
one of the desired feature types, and false otherwise.

=cut

sub make_match_sub {
  my $self = shift;
  my $types = shift;

  return sub { 1 } unless ref $types && @$types;

  my @expr;
  for my $type (@$types) {
    my ($method,$source) = @$type;
    $method ||= '.*';
    $source  = $source ? ":$source" : "(?::.+)?";
    push @expr,"${method}${source}";
  }
  my $expr = join '|',@expr;
  return $self->{match_subs}{$expr} if $self->{match_subs}{$expr};

  my $sub =<<END;
sub {
  my \$feature = shift or return;
  return \$feature->type =~ /^($expr)\$/i;
}
END
  warn "match sub: $sub\n" if $self->debug;
  my $compiled_sub = eval $sub;
  $self->throw($@) if $@;
  return $self->{match_subs}{$expr} = $compiled_sub;
}


1;

=head1 SEE ALSO

L<Bio::Das>

=head1 AUTHOR

Lincoln Stein E<lt>lstein@cshl.orgE<gt>.

Copyright (c) 2001 Cold Spring Harbor Laboratory.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

