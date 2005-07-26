# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

#!perl -w 
#
# MiscUtils.pm
# Copyright Berkeley Drosophila Genome Project 1999


=head1

Package for utility functions that dont fit anywhere else.

=cut

 
package GO::MiscUtils;

use Carp;
use Exporter;
use Data::Dumper;

@GO::MiscUtils::ISA = qw (Exporter);
@EXPORT_OK = qw(clean_field dd interpret_command_line_flags create_temp_filepath spell_greek);
use strict;

# Behavior Constants - public

# - - - - - - - - - - - PROCEDURES - - - - - - - - - - 

=head2 string2RegExp

string2RegExp
This function transforms a string into a regular expression
that will match the string.  This basically means preceeding
all special characters with a front-slash

=cut

sub string2RegExp
  {
    my ($in_string) = @_;
    my $search_string = '';
    my $num_chars = length($in_string);
    my $i;
    for ($i = 0; $i < $num_chars ; $i++)
      {
	my $char = substr($in_string, $i, 1);
	{
	  if ($char =~ /^\W$/)
	    {
	      $search_string .= "\\${char}";
	    }
	  else
	    {
	      $search_string .= $char;
	    }
	}
      }
    
    return $search_string;
  }

=head2 interpret_command_line_flags

usage example: 
  $argh = interpret_command_line_flags(\@ARGV, {db=>1, commit=>0});

  if ($argh->{db}) {
     $database = $argh->{db};
  }

  if ($argh->{commit}) {
    $commit_mode = 1;
  }

% myprog.pl -db bfd -commit <file1> <file2>

the first param is the argument listref (this will be spliced until
there are no more -<flag> commands)

the second param is a hashref of valid command lines flags (these have
to be preceeded by a hyphen on the cmd line). the key to the hash is
the command line flags, the hashed value is the number of subargs the
flag takes (usually 0 or 1).

the returned hashref is keyed by flag and if the flag was specified,
the hashref value for the key will be 
true/the flag values/an array ref of subargs

=cut

sub interpret_command_line_flags {
    my $argv_r = shift;
    my @ARGV = @{$argv_r};
    my $valid_flags = shift;

    my $argh = {};
    while (@ARGV && $ARGV[0] =~ /^-/) {
	my $flag = substr(shift @ARGV, 1);
	if (defined($valid_flags->{$flag})) {
	    my $n_subargs = $valid_flags->{$flag};
	    if ($n_subargs == 0) {
		$argh->{$flag} = 1;
	    }
	    elsif ($n_subargs == 1) {
		$argh->{$flag} = shift @ARGV;
	    }
	    else {
		$argh->{$flag} = [];
		while ($n_subargs) {
		    if (!$ARGV[0]) {
			confess("Not enough subargs for flag -$flag");
		    }
		    push(@{$argh->{$flag}}, shift @ARGV);
		    $n_subargs--;
		}
	    }
	}
	else {
	    my $usage = "command line args:\n".
	      join("\n", 
		   map {
		       "-".$_;
		   } keys %{$valid_flags});
	    if ($flag eq "help" || $flag eq "usage") {
		print "$usage\n";
	    }
	    else {
		confess("$flag not valid\n$usage");
	    }
	}
    }
    @{$argv_r} = @ARGV;
    return $argh;
}

=head2 create_temp_filepath

creates a temporary filepath

=cut

sub create_temp_filepath {
    my $identifier = shift || "tmp";
    my $directory = $ENV{TMP_DIR} || "/tmp";
    return $directory."/".$identifier.".".$$;
}



=head2 spell_greek

takes a word as a parameter and spells out any greek symbols encoded
within (eg s/&agr;/alpha/g)

=cut

sub spell_greek
{
    my $name = shift;

    $name =~ s/&agr;/alpha/g;
    $name =~ s/&bgr;/beta/g;
    $name =~ s/&ggr;/gamma/g;
    $name =~ s/&egr;/epsilon/g;
    $name =~ s/&igr;/iota/g;
    $name =~ s/&eegr;/eta/g;
    $name =~ s/&zgr;/zeta/g;
    $name =~ s/&Dgr;/Delta/g;
    $name =~ s/&dgr;/delta/g;
    $name =~ s/&thgr;/theta/g;
    $name =~ s/&PSgr;/Psi/g;
    $name =~ s/&ngr;/nu/g;
    $name =~ s/&mgr;/mu/g;

    return $name;
}


=head2 getAvailableFilename

Given a filename, this function checks whether it's 
available and returns it, appending .1, .2, .3 or
whichever is the first available value.

=cut

sub getAvailableFilename 
{
    my ($filename) = @_;
    my $suffix = '';

    while (-e $filename)
    {
	# Make up a new filename, derived from the original
	my $base_filename;
	if ($filename =~ /^(.*)\.([0-9][0-9]?)$/)
	{
	    $base_filename = $1;
	    my $on_revision = $2;
	    $suffix = ".".($on_revision + 1);
	}
	else
	{
	    $base_filename = $filename;
	    $suffix = ".2";
	}

	$filename = "${base_filename}${suffix}";
    }

    return $filename;
}

=head2 dd

dumps data

 args: ref

uses data dumper to print a dump of a hashref/obj

=cut

sub dd {
    my $obj = shift;
    my $d = Data::Dumper->new([$obj]);
    print $d->Dump;
}

=head2 clean_field

returns a cleanedup version of a field; eg trailing ws removed

=cut

sub clean_field {
    my $str = shift;
    $str =~ s/[ \r\t\n]*$//g;
    $str =~ s/^[ \r\t\n]//g;
    return $str;
}

1;
