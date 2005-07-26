package Bio::Das::Source;

use strict;

use Carp 'croak';
use XML::Parser;
use Bio::Das::Parser;

use vars qw($VERSION @ISA);
@ISA       = qw(Bio::Das::Parser);
$VERSION = '0.01';

use overload '""' => 'toString';

#
# Bio::Das::Source->sources($das);
#
sub sources {
  my $class = shift;
  my $das = shift;
  my $self = bless { sources => [] },$class;
  $das->_sources(-parser=>$self,-chunk=>4096);
  return @{$self->{sources}};
}

sub add_source {
  my $self = shift;
  my $dsn  = shift;
  push @{$self->{sources}},$dsn;
}

sub new {
  return bless {},shift;
}

sub id {
  my $self = shift;
  my $d = $self->{id};
  $self->{id} = shift if @_;
  $d;
}

sub name {
  my $self = shift;
  my $d = $self->{name};
  $self->{name} = shift if @_;
  $d;
}

sub mapmaster {
  my $self = shift;
  my $d = $self->{mapmaster};
  $self->{mapmaster} = shift if @_;
  $d;
}

sub description {
  my $self = shift;
  my $d = $self->{description};
  $self->{description} = shift if @_;
  $d;
}

sub info {
  my $self = shift;
  my $d = $self->{info};
  $self->{info} = shift if @_;
  $d;
}

sub toString {
  my $self = shift;
  my $string = $self->id || $self->name;
  return overload::StrVal($self) unless $string;
  $string;
}

sub create_parser {
  my $self = shift;
  return XML::Parser->new( Handlers => {
					Start => sub { $self->tag_start(@_) },
					End   => sub { $self->tag_end(@_)   },
				       });
}

sub parsedone {
  my $self = shift;
  $self->SUPER::parsedone;
  delete $self->{tmp};
}

sub tag_start {
  my $self = shift;
  my ($expat,$element,%attr) = @_;

  if ($element eq 'DSN') { # starting a new source section
    $self->{tmp}{cs} = ref($self)->new;  # cs = current source
    return;
  }

  my $s = $self->{tmp}{cs} or return;

  if ($element =~ /^(SOURCE|MAPMASTER|DESCRIPTION)$/) {
    $self->{tmp}{data} = '';
    $expat->setHandlers(Char => sub { $self->do_content(@_) } );
  }

  if ($element eq 'SOURCE') {
    $s->id($attr{id});
    return;
  }

  if ($element eq 'DESCRIPTION') {
    $s->info($attr{href}) if exists $attr{href};
    return;
  }
}

sub tag_end {
  my $self = shift;
  my ($expat,$element) = @_;

  my $s    = $self->{tmp}{cs}   or return;
  my $data = $self->{tmp}{data};
  $expat->setHandlers(Char => undef);

  if ($element eq 'SOURCE') {
    $s->name($data);
    return;
  }

  if ($element eq 'MAPMASTER') {
    $s->mapmaster($data);
    return;
  }

  if ($element eq 'DESCRIPTION') {
    $s->description($data);
    return;
  }

  if ($element eq 'DSN') {
    $self->add_source($s);
    return;
  }
}

sub do_content {
  my $self = shift;
  my ($expat,$data) = @_;
  return unless $data =~ /\S/; # ignore whitespace
  chomp($data);
  $self->{tmp}{data} = $data;
}

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__

=head1 NAME

Bio::Das::Source - A data source associated with a DAS server

=head1 SYNOPSIS

  use Bio::Das;

  # contact the DAS server at wormbase.org
  my $das      = Bio::Das->new('http://www.wormbase.org/db/das');

  # find out what data sources are available:
  my @sources  $das->sources;

  # select one that has something to do with human
  ($h) = grep /human/,@sources;
   $das->dsn($h);

=head1 DESCRIPTION

The Bio::Das::Source class contains information about one of the data
sources available from a DAS server.  These objects are returned by
the Bio::Das->sources() method, and can be passed to
Bio::Das->source() to select the data source.


=head2 METHODS

=over 4

=item $id = $source->id([$newid])

Get or set the ID of the source.  This is usually a short identifier
such as "elegans".

=item $name = $source->name([$newname])

Get or set the name of the source.  This is a human-readable label.

=item $description = $source->description([$newdescription])

Get or set the description for the source.  This is a longer
human-readable description of what the source contains.

=item $mapmapster = $source->mapmapster([$newmapmapster])

Get or set the URL that contains the address of the reference server
that is authoritative for the physical map.

=back

=head2 STRING OVERLOADING

The "" operator is overloaded in this class so that the ID is returned
when the source is used in a string context.  If the ID is undefed
(which should "never happen") the name is returned instead.

=head1 AUTHOR

Lincoln Stein <lstein@cshl.org>.

Copyright (c) 2001 Cold Spring Harbor Laboratory

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=head1 SEE ALSO

L<Bio::Das>

=cut
