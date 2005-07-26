# $Id$
#
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

package GO::Parsers::GoOntParser;

=head1 NAME

  GO::Parsers::GoOntParser     - syntax parsing of GO .ontology flat files

=head1 SYNOPSIS

  do not use this class directly; use GO::Parser

=cut

=head1 DESCRIPTION

This generates Stag event streams from one of the various GO flat file
formats (ontology, defs, xref, associations). See GO::Parser for details

Examples of these files can be found at http://www.geneontology.org

A description of the event streams generated follows; Stag or an XML
handler can be used to catch these events

=head1 GO ONTOLOGY FILES

These files have the .ontology suffix. The stag-schema for the event
streams generated look like this:
 
  (ontology
   (source
     (source_type "s")
     (source_path "s")
     (source_mtime "i"))
   (term+
     (acc "s")
     (name "s")
     (is_root? "i")
     (relationship+
       (type "s")
       (obj "s"))
     (dbxref*
       (xref_dbname "s")
       (xref_key "s"))
     (synonym* "s")
     (secondaryid* "s")
     (is_obsolete? "i"))) 


=head1 AUTHOR

=cut

use Exporter;
use GO::Parsers::BaseParser;
@ISA = qw(GO::Parsers::BaseParser Exporter);

use Carp;
use FileHandle;
use strict qw(subs vars refs);

sub parse_fh {
    my ($self, $fh) = @_;

    my $file = $self->file;
    my @stat = stat($file);
    my $mtime = $stat[9];

    my $is_go;
    my @edgechars = qw(% < ~);
    my $reln_regexp = join("|", map {" $_ "} @edgechars);
    my $lnum = 0;
    my @stack = ();
    my $obs_depth;

    $self->start_event("ontology");

    my @fileparts = split(/\//, $file);
    $self->event(source => [
				     [source_type => 'file'],
				     [source_path => $fileparts[-1] ],
				     [source_mtime => $mtime ],
				    ]
			 );
    $self->handler->{ontology_type} = "root";

  PARSELINE:
    while (my $line = <$fh>) {
	$line =~ s/\r//g;
	chomp $line;
	$line =~ s/\s+$//;
	++$lnum;
        $self->line($line);
        $self->line_no($lnum);
	next if $line =~ /^\s*\!/;   # comment
	next if $line eq '\$';        # 
	next if $line eq '';        # 
	last if $line =~ /^\s*\$\s*$/;  # end of file

	# get rid of SGML directives, e.g. FADH<down>2</down>, as these confuse the relationship syntax
	$line =~ s/<\/?[A-Za-z]+>//g;
	$line = &spellGreek ($line);
	$line =~ s/&([a-z]+);/$1/g;

        $line =~ /( *)(.*)/;
        my $body = $2;
        my $indent = length($1);

        my $is_obs = 0;
        while ((scalar @stack) &&
               $stack[$#stack]->[0] >= $indent) {
            pop @stack;
            if (defined($obs_depth) &&
                $obs_depth >= $indent) {
                # no longer under obsolete node
                $obs_depth = undef;
            }
        }

        my $rchar;
        if ($body =~ /\@(\w+)\:(.*)/) {
            $rchar = $self->typemap($1);
            $body = $2;
        } else {
            $rchar = $self->typemap(substr($body, 0, 1));
            $body = substr($body, 1);
        }
        # +++++++++++++++++++++++++++++++++
        # parse body / main content of line
        # +++++++++++++++++++++++++++++++++
        my $currxref;
        my @parts = split(/($reln_regexp)/, $body);
	$self->start_event("term");
	for (my $i=0; $i < @parts; $i+=2) {
            my $part = $parts[$i];
            my ($name, @xrefs) =
              split(/\s*;\s+/, $part);
            $name = $self->unescapego($name);
            if ($name =~ /^obsolete/i && $i==0) {
                $obs_depth = $indent;
            }
            if ($name eq "Gene_Ontology") {
                $is_go =1;
            }
            if (defined($obs_depth)) {
                # set obsolete flag if we
                # are anywhere under the obsolete node
                $is_obs = 1;
            }
            if ($indent < 2 && $is_go) {
                $self->handler->{ontology_type} = $name;
            }
            elsif ($indent < 1) {
                $self->handler->{ontology_type} = $name;
            }
	    else {
	    }

            my $pxrefstr = shift @xrefs;
            if (!$pxrefstr) {
                $self->message("no primary xref");
                next PARSELINE;
            }
            # get the GO id for this line
            my ($pxref, @secondaryids) =
              split(/,\s+/, $pxrefstr);
            if ($i==0) {
                $currxref = $pxref;
                if ($currxref =~ /\s/) {
                    my $msg = "\"$pxref\" doesn't look valid";
                    $self->message($msg);
                }
                my $a2t = $self->acc2termname;
                my $prevname = $a2t->{$currxref};
                if ($prevname &&
                    $prevname ne $name) {
                    my $msg = "clash on $pxref; was '$prevname' now '$name'";
                    $self->message($msg);
                }
                $a2t->{$currxref} = $name;
                $self->event("id", $currxref);
                $self->event("name", $name);
                $self->event("is_obsolete", $is_obs) if $is_obs;
                $self->event("is_root", 1) if !$indent;
                map {
                    $self->event("secondaryid", $_);
                } @secondaryids;
            }
	    #            map {
	    #                $self->start_event("secondaryid");
	    #                $self->event("id", $_);
	    #                $self->end_event("secondaryid");
	    #            } @secondaryids;
            if ($i == 0) {
                # first part on line has main
                # info for this term
                foreach my $xref (@xrefs) {
                    my ($db,@rest) =
                      split(/:/,$xref);
		    my $dbacc = $self->unescapego(join(":", @rest));
		    if ($db eq "synonym") {
                        $self->event("synonym", $dbacc);
                    }
                    
		    #                    elsif ($dbacc =~ /\s/) {
		    #                        # db accessions should not have
		    #                        # spaces in them - this
		    #                        # indicates that there is a problem;
		    #                        # eg synonym spelled wrongly
		    #                        # [MetaCyc accessions have spaces!]
		    #                        my $msg =
		    #                          "ignoring $db:$dbacc - doesn't look like accession";
		    #                        $self->message({msg=>$msg,
		    #                                        line_no=>$lnum,
		    #                                        line=>$line,
		    #                                        file=>$file});
		    #                    }
                    else {
                        $self->event("dbxref", [[xref_dbname => $db], [xref_key => $dbacc]]);
                    }
                }
            } else {
                # other parts on line
                # have redundant info,
                # but the relationship
                # part is useful
                my $rchar = $self->typemap($parts[$i-1]);
		if (!$pxref) {
		    $self->message("problem with $name $currxref: rel $rchar has no parent/object");
		} else {
		    $self->event("relationship",
				 [[type => $rchar],
                                  [obj=>$pxref]]);
		}
            }
        }
	#$line =~ s/\\//g;
        # end of parse body
        if (@stack) {
            my $up = $stack[$#stack];
	    my $obj = $up->[1];
	    if (!$obj) {
		$self->message("problem with $currxref: rel $rchar has no parent/object [top of stack is @$up]");
	    } else {
		$self->event("relationship", [[type=>$rchar], [obj=>$up->[1]]]);
	    }
        } else {
	    #            $self->event("rel", "isa", "TOP");
        }
        $self->end_event("term");
        push(@stack, [$indent, $currxref]);
    }
    $self->pop_stack_to_depth(0);
    $self->parsed_ontology(1);
    #    use Data::Dumper;
    #    print Dumper $self;
}


sub typemap {
    my $self = shift;
    my $ch = shift;
    $ch =~ s/^ *//g;
    $ch =~ s/ *$//g;
    $ch =~ s/\$/is_a/;
    $ch =~ s/\%/is_a/;
    $ch =~ s/\</part_of/;
    $ch =~ s/\~/develops_from/;
    $ch;
}

sub unescapego {
    my $self = shift;
    my $ch = shift;
    $ch =~ s/\\//g;
    $ch;

}

sub spellGreek
{
    my $name = $_[0];

    $name =~ s/&Agr;/Alpha/g;
    $name =~ s/&agr;/alpha/g;
    $name =~ s/&Bgr;/Beta/g;
    $name =~ s/&bgr;/beta/g;
    $name =~ s/&Ggr;/Gamma/g;
    $name =~ s/&ggr;/gamma/g;
    $name =~ s/&Dgr;/Delta/g;
    $name =~ s/&dgr;/delta/g;
    $name =~ s/&Egr;/Epsilon/g;
    $name =~ s/&egr;/epsilon/g;
    $name =~ s/&zgr;/zeta/g;
    $name =~ s/&Zgr;/Zeta/g;
    $name =~ s/&eegr;/eta/g;
    $name =~ s/&EEgr;/Eta/g;
    $name =~ s/&thgr;/theta/g;
    $name =~ s/&THgr;/Theta/g;
    $name =~ s/&igr;/iota/g;
    $name =~ s/&Igr;/Iota/g;
    $name =~ s/&kgr;/kappa/g;
    $name =~ s/&Kgr;/Kappa/g;
    $name =~ s/&Lgr;/Lambda/g;
    $name =~ s/&lgr;/lambda/g;
    $name =~ s/&mgr;/mu/g;
    $name =~ s/&Mgr;/Mu/g;
    $name =~ s/&ngr;/nu/g;
    $name =~ s/&Ngr;/Nu/g;
    $name =~ s/&xgr;/xi/g;
    $name =~ s/&Xgr;/Xi/g;
    $name =~ s/&ogr;/omicron/g;
    $name =~ s/&Ogr;/Omicron/g;
    $name =~ s/&pgr;/pi/g;
    $name =~ s/&Pgr;/Pi/g;
    $name =~ s/&rgr;/rho/g;
    $name =~ s/&Rgr;/Rho/g;
    $name =~ s/&sgr;/sigma/g;
    $name =~ s/&Sgr;/Sigma/g;
    $name =~ s/&tgr;/tau/g;
    $name =~ s/&Tgr;/Tau/g;
    $name =~ s/&ugr;/upsilon/g;
    $name =~ s/&Ugr;/Upsilon/g;
    $name =~ s/&phgr;/phi/g;
    $name =~ s/&PHgr;/Phi/g;
    $name =~ s/&khgr;/chi/g;
    $name =~ s/&KHgr;/Chi/g;
    $name =~ s/&Psgr;/psi/g;
    $name =~ s/&PSgr;/Psi/g;
    $name =~ s/&ohgr;/omega/g;
    $name =~ s/&Ohgr;/Omega/g;

    if ($name =~ /&[A-Za-z]{1,2}gr;/) {
	confess("Don't know greek symbol '$name'\n");
    }

    return $name;
}

1;
