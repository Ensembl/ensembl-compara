# $Id$
#
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

package GO::Parsers::GoTextParser;

=head1 NAME

  GO::Parsers::GoTextParser     - syntax parsing for GO ontology, xref, def and assoc files

=head1 SYNOPSIS

  do not use this class directly; use GO::Parser

=cut

=head1 DESCRIPTION

This script is a wrapper for

  GO::Parsers::GoOntParser
  GO::Parsers::GoDefParser
  GO::Parsers::GoXrefParser
  GO::Parsers::GoAssocParser

It will detect the type of file used, and delegate to the appropriate Parser

All the above parsers use the Data::Stag parsing model - see
http://stag.sourceforge.net for details

=cut

use Exporter;
use GO::Parsers::BaseParser;
use GO::Parsers::GoOntParser;
use GO::Parsers::GoDefParser;
use GO::Parsers::GoXrefParser;
use GO::Parsers::GoAssocParser;
@ISA = qw(GO::Parsers::BaseParser Exporter);

use Carp;
use FileHandle;
use strict qw(subs vars refs);



sub parse_file {
    my ($self, $file, $dtype) = @_;
    $self->file($file);

    if (!$dtype) {
        if ($file =~ /ontology$/) {
            $dtype = "go-ontology";
        }
        if ($file =~ /defs$/) {
            $dtype = "go-defs";
        }
        if ($file =~ /2go$/) {
            $dtype = "go-xrefs";
        }
        if ($file =~ /gene_association/) {
            $dtype = "go-assocs";
        }
    }
    if (!$dtype || $dtype =~ /ontology$/) {
        return $self->parse_ontology($file);
    }
    if ($dtype =~ /defs$/) {
        return $self->parse_defs($file);
    }
    if ($dtype =~ /xrefs$/) {
        return $self->parse_xrefs($file);
    }
    if ($dtype =~ /assocs$/) {
        return $self->parse_assocs($file);
    }
    $self->throw("Datatype: $dtype unknown");
}

sub parse {
    my $self = shift;
    $self->parse_file($_) foreach @_;
}

sub acc2termname {
    my $self = shift;
    $self->{_acc2termname} = shift if @_;
    return $self->{_acc2termname};
}


sub parse_ontology {
    my ($self, $file) = @_;
    my $p = GO::Parsers::GoOntParser->new;
    %$p = %$self;
    $p->parse($file);
    %$self = %$p;
    return;
}

sub parse_defs {
    my ($self, $file) = @_;
    my $p = GO::Parsers::GoDefParser->new;
    %$p = %$self;
    $p->parse($file);
    %$self = %$p;
    return;
}

sub parse_xrefs {
    my ($self, $file) = @_;
    my $p = GO::Parsers::GoXrefParser->new;
    %$p = %$self;
    $p->parse($file);
    %$self = %$p;
    return;
}

sub parse_assocs {
    my ($self, $file) = @_;
    my $p = GO::Parsers::GoAssocParser->new;
    %$p = %$self;
    $p->parse($file);
    %$self = %$p;
    return;
}

1;
