package Bio::Das::DSN;
# $Id$

=head1 NAME

Bio::Das::DSN - Object encapsulation of a DAS data source

=head1 SYNOPSIS

 my $base         = $dsn->base;
 my $id           = $dsn->id;
 my $host         = $dsn->host;
 my $url          = $dsn->url;
 my $name         = $dsn->name;
 my $description  = $dsn->description;
 my $mapmaster    = $dsn->master;

=head1 DESCRIPTION

The Bio::Das::DSN object contains information pertaining to a Das data
source.  A set of these objects are returned by a call to
Bio::Das->dsn().

=head2 METHODS

Following is a complete list of methods implemented by Bio::Das::DSN.

=over 4

=cut

use strict;
use overload '""'  => 'url',
             'eq' => 'eq';

=item $dsn = Bio::Das::DSN->new($base,$id,$name,$master,$description)

Create a new Bio::DAS::DSN object.  Ordinarily this is called during
the processing of a DAS dsn request and should not be invoked by
application code.

=cut

sub new {
  my $package = shift;
  my ($base, $id,$name,$master,$description) = @_;
  if (!$id && $base =~ m!(.+/das)/([^/]+)!) {
    $base = $1;
    $id = $2;
  }
  return bless {
		base => $base,
		id => $id,
		name => $name,
		master => $master,
		description => $description,
	       },$package;
}

# I don't think this is used for anything, so it gets commented
# out!
# sub set_authentication{
#   my ($self, $user, $pass) = @_;
#   my $base = $self->base;

#   #Strip any old authentication from URI, and replace
#   $base =~ s#^(.+?://)(.*?@)?#$1$user:$pass@#;  

#   $self->base($base);
# }

=item $base = $dsn->base

Return the base of the DAS server, for example
"http://www.wormbase.org/db/das."

=cut

sub base {
  my $self = shift;
  my $d = $self->{base};
  $self->{base} = shift if @_;
  $d;
}

=item $host = $dsn->host

Return the hostname of the DAS server, for example "www.wormbase.org."

=cut

sub host {
  my $self = shift;
  my $base = $self->base;
  return unless $base =~ m!^\w+://(?:\w+:\w+@)?([^/:]+)!;
  $1;
}

=item $id = $dsn->id

Return the ID of the DAS data source, for example "elegans."

=cut

sub id {
  my $self = shift;
  my $d = $self->{id};
  $self->{id} = shift if @_;
  $d;
}

=item $url = $dsn->url

Return the URL for the request, which will consist of the basename
plus the DSN ID.  For example
"http://www.wormbase.org/db/das/elegans."

The url() method is automatically invoked if the DSN is used in a
string context.  This makes it convenient to use as a hash key.

=cut

sub url {
  my $self = shift;
  return defined $self->{id} ? "$self->{base}/$self->{id}" : $self->{base};
}

=item $name = $dsn->name

Return the human readable name for the DSN.  This is usually, but not
necessarily, identical to the ID.  This field will B<only> be set if
the DSN was generated via a Bio::Das->dsn() request.  Otherwise it
will be undef.

=cut

sub name {
  my $self = shift;
  my $d = $self->{name};
  $self->{name} = shift if @_;
  $d;
}

=item $description = $dsn->description

Return the human readable description for the DSN.  This field will
B<only> be set if the DSN was generated via a Bio::Das->dsn() request.
Otherwise it will be undef.

=cut

sub description {
  my $self = shift;
  my $d = $self->{description};
  $self->{description} = shift if @_;
  $d;
}

=item $master = $dsn->master

Return the URL of the DAS reference server associated with this DSN.
This field will B<only> be set if the DSN was generated via a
Bio::Das->dsn() request.  Otherwise it will be undef.

=cut

sub master {
  my $self = shift;
  my $d = $self->{master};
  $self->{master} = shift if @_;
  $d;
}

=item $flag = $dsn->eq($other_dsn)

This method will return true if two DSN objects are equivalent, false
otherwise.  This method overloads the eq operator, allowing you to
compare to DSNs this way:

  if ($dsn1 eq $dsn2) { .... }

=cut

sub eq {
  my $self = shift;
  my $other = shift;
  return $self->url eq $other->url;
}

=back

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

