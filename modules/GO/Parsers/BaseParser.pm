# $Id$
#
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

package GO::Parsers::BaseParser;

=head1 NAME

  GO::Parsers::BaseParser     - base class for parsers

=head1 SYNOPSIS

  do not use this class directly; use GO::Parser

=cut

=head1 DESCRIPTION

=head1 AUTHOR

=cut

use Carp;
use FileHandle;
use base qw(Data::Stag::BaseGenerator Exporter);
use strict qw(subs vars refs);

# Exceptions

sub throw {
    my $self = shift;
    confess("@_");
}

sub warn {
    my $self = shift;
    warn("@_");
}

sub messages {
    my $self = shift;
    $self->{_messages} = shift if @_;
    return $self->{_messages};
}

*error_list = \&messages;

sub message {
    my $self = shift;
    my $msg = shift;
    unless (ref($msg)) {
        $msg =
          {msg=>$msg,
           line=>$self->line,
           line_no=>$self->line_no,
           file=>$self->file};
    }
    push(@{$self->messages},
         $msg);
}

=head2 show_messages

  Usage   -
  Returns -
  Args    -

=cut

sub show_messages {
    my $self = shift;
    my $fh = shift;
    $fh = \*STDERR unless $fh;
    foreach my $e (@{$self->error_list || []}) {
        printf $fh "\n===\n  Line:%s [%s]\n%s\n  %s\n\n", $e->{line_no} || "", $e->{file} || "", $e->{line} || "", $e->{msg} || "";
    }
}

sub init {
    my $self = shift;

    $self->messages([]);
    $self->acc2termname({});
    $self;
}

sub line_no {
    my $self = shift;
    $self->{_line_no} = shift if @_;
    return $self->{_line_no};
}

sub line {
    my $self = shift;
    $self->{_line} = shift if @_;
    return $self->{_line};
}

sub file {
    my $self = shift;
    $self->{_file} = shift if @_;
    return $self->{_file};
}


sub parsed_ontology {
    my $self = shift;
    $self->{parsed_ontology} = shift if @_;
    return $self->{parsed_ontology};
}

sub acc2termname {
    my $self = shift;
    $self->{_acc2termname} = shift if @_;
    return $self->{_acc2termname};
}



sub xxxxparse {
    my ($self, @files) = @_;
    foreach my $file (@files) { $self->parse_file ($file, $self->{datatype}) }
}



sub start_event {
    my $self = shift;
    eval {
        $self->SUPER::start_event(@_);
    };
    if ($@) {
        $self->message("Handler had problem: $@");
    }
    $self->check_handler_messages;
}
sub end_event { 
    my $self = shift; 
    eval {
        $self->SUPER::end_event(@_);
    };
    if ($@) {
        $self->message("Handler had problem: $@");
        die;
    }
    $self->check_handler_messages;
}
sub event {
    my $self = shift;
    eval {
        $self->SUPER::event(@_);
    };
    if ($@) {
        $self->message("Handler had problem: $@");
    }
    $self->check_handler_messages;
}

# the handlers may throw errors / complain about stuff;
# catch their messages here, and add them to the parser
# messages
sub check_handler_messages {
    my $self = shift;
    my $msgs = $self->handler->messages ||[];
    if (@$msgs) {
        map {
            $self->message(ref($_) ? $_ : {msg=>$_});
        } @$msgs;
        $self->handler->messages([]);
    }
    return;
}

=head2 normalize_files

  Usage   - @files = $parser->normalize_files(@files)
  Returns -
  Args    -

takes a list of filenames/paths, "glob"s them, uncompresses any compressed files and returns the new file list

=cut

sub normalize_files {
    my $self = shift;
    my $dtype;
    my @files = map {glob $_} @_;
    my @errors = ();
    my @nfiles = ();
    
    # uncompress any compressed files
    foreach my $fn (@files) {
        if ($fn =~ /\.gz$/) {
            my $nfn = $fn;
            $nfn =~ s/\.gz$//;
            my $cmd = "gzip -dc $fn > $nfn";
            print STDERR "Running $cmd\n";
            my $err = system("$cmd");
            if ($err) {
                push(@errors,
                     "can't uncompress $fn");
                next;
            }
            $fn = $nfn;
        }
        if ($fn =~ /\.Z$/) {
            my $nfn = $fn;
            $nfn =~ s/\.Z$//;
            my $cmd = "zcat $fn > $nfn";
            print STDERR "Running $cmd\n";
            my $err = system("$cmd");
            if ($err) {
                push(@errors,
                     "can't uncompress $fn");
                next;
            }
            $fn = $nfn;
        }
        push(@nfiles, $fn);
    }
    my %done = ();
    @files = grep { my $d = !$done{$_}; $done{$_} = 1; $d } @nfiles;
    return @files;
}


1;
