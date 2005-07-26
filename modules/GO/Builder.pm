# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself


package GO::Builder;

=head1 NAME

  GO::Builder

=head1 DESCRIPTION

Abstract class for building data structures/objects of GO Terms and
relationships

kind of a 'consumer' object in a producer/consumer relationship

generates event-calls which can be interrupted (ie by subclassing) in
the concrete builder class

 usage:

   my $builder = new GO::Builder();
   my $parser = new GO::Parser ($builder);
   $parser->parse

=cut

use Exporter;
@ISA = qw(Exporter);

use Carp;
use strict qw(subs vars refs);

# Constructor

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    $self->_initialize(@_);
    return $self;
}

sub _initialize {
    my $self = shift;
    my $paramh = shift || {};
    if (!ref($paramh)) {
	confess("arg to new() should be ref, not $paramh");
    }
    my $stderr =  $paramh->{'stderr'};
    if (!$stderr) {$stderr = \*STDERR};
    $self->{'stderr'} = $stderr ;
}

# error handling

sub warn {
    my ($self, $msg) = @_;
    print STDERR "\n** WARNING **\n";
    warn($msg);
    if (!$self->{error_list}) {
	$self->{error_list} = [];
    }
    push(@{$self->{error_list}}, {msg=>$msg});
}

sub silent_warn {
    my ($self, $msg) = @_;
    if (!$self->{error_list}) {
	$self->{error_list} = [];
    }
    push(@{$self->{error_list}}, {msg=>$msg});
}

sub error_list {
    my $self = shift;
    $self->{error_list} = shift if @_;
    return $self->{error_list};
}


# Dummy build methods -- override for interesting functionality

sub add_term {
    my ($self, $h) = @_;
    $self->warn ("Ignored:\n");
}

sub set_category {
    my ($self, $id, $category) = @_;
    $self->warn ("Ignored: term $id category is '$category'\n");
}

sub add_obsolete_pointer {
    my ($self, $id, $obsolete_id) = @_;
    $self->warn ("Ignored: term $obsolete_id obsoleted by $id\n");
}

sub add_relationship {
    my ($self, $from_id, $to_id, $type) = @_;
    $self->warn ("Ignored: type '$type' relationship from $from_id to $to_id\n");
}

sub add_synonym {
    my ($self, $id, $synonym) = @_;
    $self->warn ("Ignored: term $id has synonym '$synonym'\n");
}

sub add_dbxref {
    my ($self, $id, $dbxref) = @_;
    $self->warn ("Ignored: term $id has dbxref '$dbxref'\n");
}

#sub add_xref {
#    my ($self, $id, $xrefkey, $xrefdbname) = @_;
#    $self->warn ("Ignored: term $id has xref to $xrefdbname:$xrefkey\n");
#}

sub add_association {
    my $self = shift;
    $self->warn ("Ignored: add association @_\n");
    
}

sub message {
    my ($self, $msg) = @_;
    print STDERR "Message:$msg";
}

