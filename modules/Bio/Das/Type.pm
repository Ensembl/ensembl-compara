package Bio::Das::Type;

use strict;
use overload 
  '""' => 'toString',
  cmp   => '_cmp';

sub new {
  my $class = shift;
  my ($id,$method,$category) = @_;
  return bless {id=>$id,
		method=>$method,
		category=>$category
	       },$class;
}
sub id   {
  my $self = shift;
  my $d = $self->{id};
  $self->{id} = shift if @_;
  $d;
}
sub method {
  my $self = shift;
  my $d = $self->{method};
  if (@_) {
    $self->{method} = $_[0];
    # hack to allow to work with Bio::DB::GFF aggregators.
    # There is a workaround here to correct for broken ensembl
    # das implementation, which lists all methods as "ensembl"
    # This is actually the source, not the method
    $self->{id}    =~ s/^[^:]+/$_[0]/ if $_[0] && $_[0] ne 'ensembl';
  }
  $d;
}
sub method_label {
  my $self = shift;
  my $d = $self->{method_label};
  $self->{method_label} = shift if @_;
  $d;
}
sub category {
  my $self = shift;
  my $d = $self->{category};
  $self->{category} = shift if @_;
  $d;
}
sub count {
  my $self = shift;
  my $d = $self->{count};
  $self->{count} = shift if @_;
  $d;
}
sub reference {
  my $self = shift;
  my $d = $self->{reference};
  $self->{reference} = shift if @_;
  $d;
}
sub has_subparts {
  my $self = shift;
  my $d = $self->{has_subparts};
  $self->{has_subparts} = shift if @_;
  $d;
}
sub has_superparts {
  my $self = shift;
  my $d = $self->{has_superparts};
  $self->{has_superparts} = shift if @_;
  $d;
}
sub source {
  my $self = shift;
  my $d = $self->{source};
  $self->{source} = shift if @_;
  $d;
}
sub label {
  my $self = shift;
  my $d = $self->{label};
  $self->{label} = shift if @_;
  $d;
}
sub toString {
  my $self = shift;
  $self->id || $self->label;
}

sub type {
  shift->toString;
}

sub complete {
  my $self = shift;
  return defined $self->{id} && defined $self->{method};
}

# return a key that is a unique combination of
# type and method
sub _key {
  my $self = shift;
  my @k = $self->{id};
  push @k,$self->{method}          if exists $self->{method};
  push @k,$self->{reference}       if exists $self->{reference};
  push @k,$self->{category}        if exists $self->{category};
  push @k,$self->{has_subparts}    if exists $self->{has_subparts};
  push @k,$self->{has_superparts}  if exists $self->{has_subparts};
  push @k,$self->{method_label}    if exists $self->{method_label};
  push @k,$self->{count}           if exists $self->{count};
  join ':',@k;
}

sub _cmp {
  my $self = shift;
  my ($b,$reversed) = @_;
  my $a = $self->toString;
  ($a,$b) = ($b,$a) if $reversed;
  $a cmp $b;
}

1;

__END__

=head1 NAME

Bio::Das::Type - A sequence annotation type

=head1 SYNOPSIS

  use Bio::Das;

  # contact a DAS server using the "elegans" data source
  my $das      = Bio::Das->new('http://www.wormbase.org/db/das' => 'elegans');

  # find out what feature types are available
  my @types       = $db->types;

  # get information on each one
  for my $t (@types) {
    my $id          = $t->id;
    my $method      = $t->method;
    my $category    = $t->category;
    my $isreference = $t->reference;
    my $label       = $t->label;
    my $method_label = $t->method_label;
  }

=head1 DESCRIPTION

The Bio::Das::Type class provides information about the type of an
annotation.  Each type has a category, which is a general description
of the type, a unique ID, which names the type, and an optional
method, which describes how the type was derived.  A type may also be
marked as being a landmark that can be used as a reference sequence.

Optionally, types can have human readable labels.  There is one label
for the type itself, and another for the type's method.

=head2 OBJECT CREATION

Bio::Das::Type objects are created by calling the types() method of a
Bio::Das or Bio::Das::Segment object.  They are also created implicity
when a Bio::Das::Segment::Feature is created.

If needed, there is a simple constructor which can be called directly:

=over 4

=item $type = Bio::Das::Type->new($id,$method,$category)

Create and return a Bio::Das::Type object with the indicated typeID,
method and category.

=back

=head2 OBJECT METHODS

The following methods are public.  Most of them use an accessor
calling style.  Called without an argument, they return the current
value of the attribute.  Called with an argument, they change the
attribute and return its previous value.

=over 4

=item $id = $type->id([$newid])

Get or set the ID for the type;

=item $label = $type->label([$newlabel])

Get or set the label for the type;

=item $method = $type->method([$newmethod])

Get or set the method ID for the type.

=item $label = $type->method_label([$newlabel])

Get or set the method label for the type.

=item $category = $type->category([$newcategory])

Get or set the category for the type.

=item $reference = $type->reference([$newreference])

Get or set the value of the reference attribute.  If the attribute is
true, then features of this type can be used as reference sequences.
However, see LIMITATIONSbelow.

=back

=head2 LIMITATIONS

Due to the requirements of the DAS spec, the reference() method will
always return false for types returned by the Bio::Das->types() or
Bio::Das::Segment->types() methods.  As currently specified, the
reference attribute is an attribute of an individual feature, and not
of a generic type.

=head1 AUTHOR

Lincoln Stein <lstein@cshl.org>.

Copyright (c) 2001 Cold Spring Harbor Laboratory

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=head1 SEE ALSO

L<Bio::Das>, L<Bio::Das::Segment>,
L<Bio::Das::Segment::Feature>

=cut

