package Bio::Das::Request;
# encapsulates a request on a DAS server
# also knows how to deal with response
# $Id$

=head1 NAME

Bio::Das::Request - Base class for a request on a DAS server

=head1 SYNOPSIS

 my $dsn                  = $request->dsn;
 my $das_command          = $request->command;
 my $successful           = $request->is_success;
 my $error_msg            = $request->error;
 my @results              = $request->results;
 my ($username,$password) = $request->auth;

=head1 DESCRIPTION

Each type of request on a DAS server (e.g. an entry_points request) is
a subclass of Bio::Das::Request.  The request encapsulates the
essential information on the request: the server, the data source, and
the command that will be executed.  After the request is sent to the
server, the request object will contain information pertinent to the
outcome of the request, including the success status, the results if
successful, and an error message if not successful.

Subclasses of Bio::Das::Request include L<Bio::Das::Request::Dsn>,
L<Bio::Das::Request::Entry_points>, L<Bio::Das::Request::Features>,
L<Bio::Das::Request::Stylesheet>, and L<Bio::Das::Request::Types>.

Creating the appropriate request is done automatically by L<Bio::Das>.
Ordinarily you will not have to create a Bio::Das::Request manually.

=head2 METHODS

Following is a complete list of methods implemented by
Bio::Das::Request.

=over 4

=cut

use strict;

use Bio::Das::Util;
use HTML::Parser;
use Compress::Zlib;
use Carp qw/croak confess/;

use constant GZIP_MAGIC => 0x1f8b;
use constant OS_MAGIC => 0x03;
use constant DASVERSION => 0.95;

use overload '""' => 'url';

my %DAS_error_codes = (
		       200=>'OK, data follows',
		       400=>'Bad command',
		       401=>'Bad data source',
		       402=>'Bad command arguments',
		       403=>'Bad reference object',
		       404=>'Bad stylesheet',
		       405=>'Coordinate error',
		       500=>'Server error',
		       501=>'Unimplemented feature',
		      );

=item $request = Bio::Das::Request->new(-dsn=>$dsn,-args=>$args,-callback=>$callback)

Create a new Bio::Das::Request objects.  The B<-dsn> argument points
to the DAS DSN (full form, including hostname).  B<-callback> points
to an optional coderef that will be invoked for every object returned
during execution of the request.  B<-args> points to a hashref
containing request-specific arguments.

This method is trivially overridden by many of the request subclasses
in order to accept arguments that are specific to each of the
requests, such as -segments.

=cut

# -dsn      dsn object
# -args     e.g. { segment => [qw(ZK154 M7 CHROMOSOME_I:1000000,2000000)] }
# -callback code ref to be invoked when each "object" is finished parsing
sub new {
  my $package = shift;
  my ($dsn,$args,$callback) = rearrange(['dsn',
					 'args',
					 'callback'
					],@_);
  $dsn = Bio::Das::DSN->new($dsn) unless ref $dsn;
  $args ||= {};
  return bless {
		            dsn                 => $dsn,
		            args                => $args,
		            callback            => $callback,
		            results             => [],         # list of objects to return
		            p_success           => 0,
		            p_error             => '',
		            p_compressed_stream => 0,
		            p_xml_parser        => undef,
	            },$package;
}

=item $command = $request->command

The command() method returns the DAS command that will be invoked.
This varies from subclass to subclass.  For example,
Bio::Das::Request::Types->command() will return "types."

=cut

# ==  to be overridden in subclasses ==
# provide the command name (e.g. 'types')
sub command {
  my $self = shift;
  die "command() must be implemented in subclass";
}

=item $url = $request->url

Return the URL for the request on the DAS server.

=cut

# == Generate the URL request ==
sub url {
  my $self = shift;
  my $url     = $self->dsn->url;
  my $command = $self->command;

  if (defined $command) {
    $url .= "/$command";
  }

  $url;
}

=item $dsn = $request->dsn([$new_dsn])

Get the DAS DSN associated with the request.  This method is also used
internally to change the DSN.

=cut

# get/set the DSN
sub dsn {
  my $self = shift;
  my $d = $self->{dsn};
  $self->{dsn} = shift if @_;
  $d;
}

=item $host = $request->host

Returns the host associated with the request.  This is simply
delegated to the DSN object's host() method.

=cut

sub host { shift->dsn->host }

# == status ==

=item $flag = $request->is_success

After the request is executed, is_success() will return true if the
request was successfully issued and parsed, false otherwise.  If
false, you can retrieve an informative error message using the error()
method.

=cut

# after the request is finished, is_success() will return true if successful
sub is_success { shift->success; }

=item $message = $request->error

If the request was unsuccessful, error() will return an error message.
In the case of a successful request, the result of error() is
undefined and should not be relied on.

Error messages have the format "NNN XXXXXXXX" where "NNN" is a numeric
status code, and XXXXXXX is a human-readable error message.  The
following error messages are possible:

       400 Bad command
       401 Bad data source
       402 Bad command arguments
       403 Bad reference object
       404 Bad stylesheet
       405 Coordinate error
       410 Unknown host
       411 Couldn't connect
       412 Communications error
       413 Authentication scheme 'xxxx" is not supported
       500 Server error
       501 Unimplemented feature
       502 No X-Das-Version header
       503 Invalid X-Das-Version header
       504 DAS server is too old
       505 No X-Das-Status header
       506 Data decompression failure

=cut

# error() will give the most recent error message
sub error {
  my $self = shift;
  if (@_) {
    $self->{p_error} = shift;
    return;
  } else {
    return $self->{p_error};
  }
}

=item @results = $request->results

In a list context this method returns the accumulated results from the
DAS request. The contents of the results list is dependent on the
particular request, and you should consult each of the subclasses to
see what exactly is returned.

In a scalar context, this method will return an array reference.

=cut

sub results {
  my $self = shift;
  my $r = $self->{results} or return;
  return wantarray ? @$r : $r;
}

=item ($username,$password) = $request->auth([$username,$password])

Get or set the username and password that will be used for
authentication in this request.  This is used internally by the
L<Bio::Das::HTTP::Fetch> class and should not ordinarily be
manipulated by application code.

=cut

sub auth {
  my $self = shift;
  my ($username,$password) = @_;
  if ($username) {
    $self->{auth} = [$username,$password];
  }
  return unless $self->{auth};
  return @{$self->{auth}};
}

=item $parser = $request->create_parser()

This method creates an HTML::Parser object that will be used to parse
the incoming XML data.  Ordinarily this will not be called by
application code.

=cut

# create an initiliazed HTML::Parser object
sub create_parser {
  my $self = shift;
  return HTML::Parser->new(
			   api_version   => 3,
			   start_h       => [ sub { $self->tag_starts(@_) },'tagname,attr' ],
			   end_h         => [ sub { $self->tag_stops(@_)  },'tagname' ],
			   text_h        => [ sub { $self->char_data(@_)  },'dtext' ],
			  );
}

=item $request->tag_starts

This method is called internally during the parse to handle a start
tag.  It should not be called by application code.

=cut

# tags will be handled by a method named t_TAGNAME
sub tag_starts {
  my $self = shift;
  my ($tag,$attrs) = @_;
  my $method = "t_$tag";
  $self->{char_data} = '';  # clear char data
  $self->can($method)
    ? $self->$method($attrs) 
    : $self->do_tag($tag,$attrs);
}

=item $request->tag_stops

This method is called internally during the parse to handle a stop
tag.  It should not be called by application code.

=cut

# tags will be handled by a method named t_TAGNAME
sub tag_stops {
  my $self = shift;
  my $tag = shift;
  my $method = "t_$tag";
  $self->can($method)
    ? $self->$method()
    : $self->do_tag($tag);
}

=item $request->do_tag

This method is called internally during the parse to handle a tag.  It
should not be called by application code, but can be overridden by a
subclass to provide tag-specific processing.

=cut

sub do_tag {
  my $self = shift;
  my ($tag,$attrs) = @_;
  # do nothing
}


=item $request->char_data

This method is called internally during the parse to handle character
data.  It should not be called by application code.

=cut

sub char_data {
  my $self = shift;
  if (@_ && length(my $text = shift)>0) {
    $self->{char_data} .= $text;
  } else {
    $self->trim($self->{char_data});
  }
}

=item $request->cleanup

This method is called internally at the end of the parse to handle any
cleanup that is needed.  The default behavior is to do nothing, but it
can be overridden by a subclass to provide more sophisticated
processing.

=cut

sub cleanup {
  my $self = shift;
}

=item $request->clear_results

This method is called internally at the start of the parse to clear
any accumulated results and to get ready for a new parse.

=cut

sub clear_results {
  shift->{results} = [];
}

=item $request->add_objects(@objects)

This method is called internally during the parse to add one or more
objects (e.g. a Bio::Das::Feature) to the results list.

=cut

# add one or more objects to our results list
sub add_object {
  my $self = shift;
  if (my $cb = $self->callback) {
    eval {$cb->(@_)};
    warn $@ if $@;
  } else {
    push @{$self->{results}},@_;
  }
}

# == ACCESSORS ==

=item $parser = $request->xml_parser([$new_parser])

Internal accessor for getting or setting the XML parser object used in
processing the request.

=cut

# get/set the HTML::Parser object
sub xml_parser {
  my $self = shift;
  my $d = $self->{p_xml_parser};
  $self->{p_xml_parser} = shift if @_;
  $d;
}

=item $flag = $request->compressed([$new_flag])

Internal accessor for getting or setting the compressed data stream
flag.  This is true when processing a compressed data stream, such as
GZIP compression.

=cut

# get/set stream compression flag
sub compressed {
  my $self = shift;
  my $d = $self->{p_compressed_stream};
  $self->{p_compressed_stream} = shift if @_;
  $d;
}

=item $flag = $request->success([$new_flag])

Internal accessor for getting or setting the success flag.  This is
the read/write version of is_success(), and should not be used by
application code.

=cut

# get/set success flag
sub success {
  my $self = shift;
  my $d = $self->{p_success};
  $self->{p_success} = shift if @_;
  $d;
}


=item $callback = $request->callback([$new_callback])

Internal accessor for getting or setting the callback code that will
be used to process objects as they are generated by the parse.

=cut

# get/set callback
sub callback {
  my $self = shift;
  my $d = $self->{callback};
  $self->{callback} = shift if @_;
  $d;
}

=item $args = $request->args([$new_args])

Internal accessor for getting or setting the CGI arguments that will
be passed to the DAS server.  The arguments are a hashref in which the
keys and values correspond to the CGI parameters.  Multivalued CGI
parameters are represented as array refs.

=cut

# get/set the request arguments
sub args {
  my $self = shift;
  my $d = $self->{args};
  $self->{args} = shift if @_;
  $d;
}

=item $method = $request->method

This method can be overridden by subclasses to force the
L<Bio::Das::HTTP::Fetch> object to use a particular HTTP request
method.  Possible values that this method can return are "AUTO", "GET"
or "POST."  The base class returns a value of "AUTO," allowing the
L<Bio::Das::HTTP::Fetch> object to choose the most appropriate request
method.

=cut

# return the method - currently "auto"
sub method {
  my $self = shift;
  return 'AUTO';
}

# == Parser stuff ==

=item $request->headers($das_header_data)

The headers() method is called internally to parse the HTTP headers
returned by the DAS server.  The data is a hashref in which the keys
and values correspond to the HTTP headers and their values.

=cut

# handle the headers
sub headers {
  my $self    = shift;
  my $hashref = shift;

  # check the DAS header
  my $protocol = $hashref->{'X-Das-Version'} or
    return $self->error('502 No X-Das-Version header');

  my ($version) = $protocol =~ m!(?:DAS/)?([\d.]+)! or
    return $self->error('503 Invalid X-Das-Version header');

  $version >= DASVERSION or
    return $self->error("504 DAS server is too old. Got $version; require at least ${\DASVERSION}");

  # check the DAS status
  my $status = $hashref->{'X-Das-Status'} or
    return $self->error('505 No X-Das-Status header');

  $status =~ /200/ or
    return $self->error("$status $DAS_error_codes{$status}");

  $self->compressed(1) if exists $hashref->{'Content-Encoding'} &&
    $hashref->{'Content-Encoding'} =~ /gzip/;

  1;  # we passed the tests, so we continue to parse
}

=item $request->start_body()

This internal method is called by L<Bio::Das::HTTP::Fetch> upon first
encountering the DAS document body data.  The method calls
create_parser() to create the appropriately-initialized HTML::Parser
object and stores it internally using the xml_parser() accessor.

=cut

# called to do initialization after receiving the header
# but before processing any body data
sub start_body {
  my $self = shift;
  $self->xml_parser($self->create_parser);
  $self->xml_parser->xml_mode(1);
  return $self->xml_parser;
}

=item $request->body($data)

This internal method is called by L<Bio::Das::HTTP::Fetch> to process
each chunk of DAS document data. The data is processed incrementally
in multiple steps until the end of document is reached.

=cut

# called to process body data
sub body {
  my $self = shift;
  my $data = shift;
  my $parser = $self->xml_parser or return;
  my $status;
  if ($self->compressed) {
    ($data,$status) = $self->inflate($data);
    return unless $status;
  }
  return $parser->parse($data);
}

=item $request->finish_body()

This internal method is called by L<Bio::Das::HTTP::Fetch> when the
end of document is encountered.

=cut

# called to finish body data
sub finish_body {
  my $self = shift;
  $self->cleanup();
  my $parser = $self->xml_parser or return;
  my $result = $parser->eof;
  $self->success(1);
  1;
}

=item ($inflated_data,$status) = $request->inflate($data)

This internal method is called when processing compressed data.  It
returns a two-element list consisting of the inflated data and a
true/false status code.  A false status code means an error was
encountered during inflation, and ordinarily causes the parsing to
terminate.

=cut

# == inflation stuff ==
sub inflate {
  my $self = shift;
  my $compressed_data = shift;

  # the complication here is that we might be called on a portion of the
  # data stream that contains only a partial header.  This is unlikely, but
  # I'll be paranoid.
  if (!$self->{p_i}) { # haven't created the inflator yet
    $self->{p_gzip_header} .= $compressed_data;
    my $cd = $self->{p_gzip_header};
    return ('',1) if length $cd < 10;

    # process header
    my ($gzip_magic,$gzip_method,$comment,$time,undef,$os_magic) 
      = unpack("nccVcc",substr($cd,0,10));

    return $self->error("506 Data decompression failure (not a gzip stream)")
      unless $gzip_magic == GZIP_MAGIC;
    return $self->error("506 Data decompression failure (unknown compression method)") 
      unless $gzip_method == Z_DEFLATED;

    substr($cd,0,10) = '';     # truncate the rest

    # handle embedded comments that proceed deflated stream
    # note that we do not correctly buffer here, but assume
    # that we've got it all.  We don't bother doing this right,
    # because the filename field is not usually present in
    # the on-the-fly streaming done by HTTP servers.
    if ($comment == 8 or $comment == 10) {
      my ($fname) = unpack("Z*",$cd);
      substr($cd,0,(length $fname)+1) = '';
    }

    $compressed_data = $cd;
    delete $self->{p_gzip_header};

    $self->{p_i} = inflateInit(-WindowBits => -MAX_WBITS() ) or return;
  }

  my ($out,$status) = $self->{p_i}->inflate($compressed_data);
  return $self->error("506 Data decompression failure (inflation failed, errcode = $status)")
    unless $status == Z_OK or $status == Z_STREAM_END;

  return ($out,1);
}

=item $trimmed_string = $request->trim($untrimmed_string)

This internal method strips leading and trailing whitespace from a
string.

=cut

# utilities
sub trim {
  my $self = shift;
  my $string = shift;
  $string =~ s/^\s+//;
  $string =~ s/\s+$//;
  $string;
}

=back

=head2 The Parsing Process

This module and its subclasses use an interesting object-oriented way
of parsing XML documents that is flexible without imposing a large
performance penalty.

When a tag start or tag stop is encountered, the tag and its
attributes are passed to the tag_starts() and tag_stops() methods
respectively.  These methods both look for a defined method called
t_TAGNAME (where TAGNAME is replaced by the actual name of the tag).
If the method exists it is invoked, otherwise the tag and attribute
data are passed to the do_tag() method, which by default simply
ignores the tag.

A Bio::Das::Request subclass that wishes to process the
E<lt>FOOBARE<gt> tag, can therefore define a method called t_FOOBAR
which takes two arguments, the request object and the tag attribute
hashref.  The method can distinguish between E<lt>FOOBARE<gt> and
E<lt>/FOOBARE<gt> by looking at the attribute argument, which will be
defined for the start tag and undef for the end tag.  Here is a simple
example:

  sub t_FOOBAR {
    my $self       = shift;
    my $attributes = shift;
    if ($attributes) {
       print "FOOBAR is starting with the attributes ",join(' ',%$attributes),"\n";
    } else {
       print "FOOBAR is ending\n";
    }
  }

The L<Bio::Das::Request::Dsn> subclass is a good example of a simple
parser that uses t_TAGNAME methods exclusively.
L<Bio::Das::Request::Stylesheet> is an example of a parser that also
overrides do_tag() in order to process unanticipated tags.

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
