
# =======================================================================
# Doxygen Pre-Processor for Visual Basic
# Copyright (C) 2007  Phinex Informatik AG
# All Rights Reserved
# 
# Doxygen Filter is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
# 
# Larry Wall's 'Artistic License' for perl can be found in
# http://www.perl.com/pub/a/language/misc/Artistic.html
# 
# =======================================================================
# 
# Author: Aeby Thomas, Phinex Informatik AG,
# E-Mail: tom.aeby@phinex.ch
# 
# Phinex Informatik AG
# Thomas Aeby
# Kirchweg 52
# 1735 Giffers
# 
# =======================================================================
# 
# @(#) $Id$
# 
# Revision History:
# 
# $Log$
# Revision 1.2  2009/01/08 13:38:29  aeby
# added example visual basic class
# VBFilter: emit class declaration before comments inside the same class
#
# Revision 1.1  2009/01/08 09:04:59  aeby
# added support for visual basic
#
# Revision 1.2  2006/01/31 16:53:52  aeby
# added copyright info
#
#  
# =======================================================================

## @file
# implementation of DoxyGen::VBFilter.
#


## @class
# Filter from Visual Basic to Doxygen-compatible syntax.
# This class is meant to be used as a filter for the
# <a href="http://www.doxygen.org/">Doxygen</a> documentation tool.
package DoxyGen::VBFilter;

use warnings;
use strict;
use base qw(DoxyGen::Filter);

my $current_class;
my @superclasses;

## @method void filter($infh)
# do the filtering.
# @param infh input filehandle, normally STDIN
sub filter {
    my($self, $infile) = @_;
    open(IN, $infile);
    $self->{infunction} = 0;
    $self->{inenum} = 0;
    $self->{instruct} = 0;
    $self->{emptylines} = 0;
    while (<IN>) {
	s/[\r\n]//g;
	my $next = $_;
	while( ($next =~ /_$/) && ($next = <IN>)) {
	    $_ =~ s/_$//;
	    $next =~ s/[\r\n]//g;
	    $_ .= $next;
	}

	$self->{comment} = "";
	if( /''/ ) {
	    $self->{comment} = "///$'";
	    $_ = $`;
	}
	if( /'/ ) {
	    $self->{comment} = "//$'";
	    $_ = $`;
	}

	s/^\s+//;
	unless( $_ ) {
	    next unless( $self->{comment} || ! $self->{emptylines} );
	    $self->emit_class() if( $self->{comment} );
	    $self->print( "\n" );
	    $self->{emptylines} = ! $self->{comment};
	    next;
	}
	$self->{emptylines} = 0;

	if( $self->{inenum} ) {
	    if( /^end\s+enum/i ) {
		$self->{inenum} = 0;
		$self->print( "};\n" );
	    }
	    else {
		$self->print( $_.",\n" );
	    }
	    next;
	}
	elsif( $self->{instruct} ) {
	    if( /^end\s+structure/i ) {
		$self->{instruct} = 0;
		$self->print( "};\n" );
	    }
	    else {
		if( /^(dim|)\s*(\w+)\s+as\s+(.*)/i ) {
		    $self->print( $2." [$3];\n");
		}
	    }
	    next;
	}

	$self->{access} = "public";
	while( /^(public|private|protected|friend|protected friend|shadows|mustinherit|notinheritable|partial|overrides|readonly|overloads|shared)\s*/i ) {
	    my $what = $1;
	    $_ = $';
	    if( $what =~ /^(public|private|protected|friend|protected friend)$/i ) {
		$self->{access} = lc($what);
	    }
	}

	if( /^class\s+(\w+)/i ) {
	    $current_class = "class $1";
	    @superclasses = ();
	    next;
	}
	elsif( /^(inherits|implements)\s+(.*)/i ) {
	    push( @superclasses, map { "public $_" } split( /\s*,\s*/, $2 ) );
	    next;
	}

	$self->emit_class();

	if( /^structure\s+(.*)/i && ! $self->{infunction} ) {
	    $self->{instruct} = 1;
	    $self->print( $self->{access}.": struct $1 {\n" );
	    next;
	}

	if( /^(property|sub|function|structure)\s+/i && ! $self->{infunction} ) {
	    $self->{infunction}++;
#	    $self->print( $self->{access}.": ".$_." {\n" );
	    $self->print( $self->parse_sub( $1, $' ) );
	    next;
	}
	elsif( /^end\s+(property|sub|function|structure)/i && $self->{infunction} ) {
	    print "}\n\n";
	    $self->{infunction}--;
	}

	if( /^enum\s+(\w+)/i ) {
	    $self->print( $self->{access}.": enum $1 {\n" );
	    $self->{inenum} = 1;
	}

	if( (! $self->{infunction}) && /^(\w+)\s+as\s+(.*)/i ) {
	    $self->print( $self->{access}.": ".$1." [$2];\n");
	    next;
	}

	if( /^end\s+class/i ) {
	    $self->print( "}\n" );
	}
    }
}

sub emit_class {
    my( $self ) = @_;
    return unless( $current_class );
    $self->print( $current_class );
    $self->print( ": ".join( ", ", @superclasses ) ) if( @superclasses );
    $self->print( " {\n" );
    $current_class = "";
}


sub parse_sub {
    my( $self, $what, $prototype ) = @_;

    unless( $prototype =~ /^(.*?)\((.*)\)(.*)$/ ) {
	return( $self->{access}.": $what $prototype {\n" );
    }
    my( $root, $args, $type ) = ($1,$2,$3);
    my @args = ();
    foreach my $arg (split( /\s*,\s*/, $args )) {
	push( @args, $self->parse_arg( $arg ) );
    }
    return( $self->{access}.": ".$what." ".$root."(".join(",",@args).") $type {\n" );
}
	    

sub parse_arg {
    my( $self, $arg ) = @_;

    if( $arg =~ /(.*)\s+(\w+)\s+As\s+(.*)\s+(=.*)$/ ) {
	$arg = $1." As $3  $2 $4";
    }
    elsif( $arg =~ /(.*)\s+(\w+)\s+As\s+(.*)$/ ) {
	$arg = $1." As $3  $2";
    }
    return( $arg );
}


sub print {
    my( $self, @args ) = @_;

    return( $self->SUPER::print( @args ) ) unless( $self->{comment} );
    foreach my $arg (@args) {
	last if( $arg =~ s/\n/$self->{comment}\n/ );
    }
    return( $self->SUPER::print( @args ) );
}


1;
