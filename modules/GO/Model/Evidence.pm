# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself


package GO::Model::Evidence;

=head1 NAME

  GO::Model::Evidence;

=head1 SYNOPSIS

  my $ev_l = $association->evidence_list;
  foreach my $ev (@$ev_l) {
    print "Evidence for association %s : %s\n",
      $association->gene_product->symbol,
      $ev->code;
  }

=head1 DESCRIPTION

evidence for an association

see http://www.geneontology.org/GO.evidence.html
for a list of evidence codes

=cut


use Carp qw(confess cluck);
use Exporter;
use GO::Utils qw(rearrange);
use GO::Model::Root;
use strict;
use vars qw(@ISA);

@ISA = qw(GO::Model::Root Exporter);


sub _valid_params {
    return qw(id code seq_acc xref seq_xref_list pub_xref_list);
}

=head2 code

  Usage   - $ev->code("IEA");
  Returns -
  Args    -

gets/sets the evidence code

see http://www.geneontology.org/GO.evidence.html

=cut

# dynamic method

=head2 seq_acc

  Usage   -
  Returns -
  Args    -

gets/sets the sequence accesion GO::Model::Xref

ALPHA CODE  - API may change

used to set the GO::Model::Xref list from a text string. eg

  $ev->seq_acc("SGD:RRP41; SGDID:L0003550");

will actually add two GO::Model::Xref objects

This method doesnt really belong in the GO::Model::* hierarchy as it
contains parsing code. Its a minor hack mainly due to the fact that
this data is still denormalized in the database.

=cut

sub seq_acc {
    my $self = shift;
    if (@_) {
        my $acc = shift;
        if (ref($acc)) {
            if (ref($acc) eq "ARRAY") {
                foreach (@$acc) {
                    $self->add_seq_xref($_);
                }
            }
            else {
                if (UNIVERSAL::isa($acc, "GO::Model::Xref")) {
                    $self->add_seq_xref($acc)
                }
                else {
                    confess("$acc is not a valid argument for $self -> seq_acc()");
                }
            }
        }
        else {
            # it's a string
            my @accs =
              split(/\;/, $acc);
            foreach my $acc (@accs) {
                $self->add_seq_xref($acc);
            }
        }
    }
    return
      join("; ",
           map {$_->as_str} @{$self->seq_xref_list || []});
}


=head2 add_seq_xref

  Usage   -
  Returns -
  Args    -

=cut

sub add_seq_xref {
    my $self = shift;
    my $xref = shift;
    if (ref($xref)) {
        if (UNIVERSAL::isa($xref, "GO::Model::Xref")) {
            $self->{seq_xref_list} = [] unless $self->{seq_xref_list};
            push(@{$self->{seq_xref_list}}, $xref);
        }
        else {
            confess("$xref is not a valid argument for $self -> add_seq_xref()");
        }
    }
    else {
        # string maybe in db:acc format
        if ($xref =~ /\s*(\S+?):(\S+)/) {
            my ($db, $acc) = ($1, $2);
            $acc =~ s/ *$//;
            $xref = 
              GO::Model::Xref->new({xref_dbname=>$db,
                                    xref_key=>$acc});
        }
        else {
            $xref = 
              GO::Model::Xref->new({xref_dbname=>"UNKNOWN",
                                    xref_key=>"$xref"});
        }
        confess("Assertion error") unless $xref->isa("GO::Model::Xref");
        $self->add_seq_xref($xref);
    }
}


=head2 add_pub_xref

  Usage   -
  Returns -
  Args    -

=cut

sub add_pub_xref {
    my $self = shift;
    my $xref = shift;
    if (ref($xref)) {
        if (UNIVERSAL::isa($xref, "GO::Model::Xref")) {
            $self->{pub_xref_list} = [] unless $self->{pub_xref_list};
            push(@{$self->{pub_xref_list}}, $xref);
        }
        else {
            confess("$xref is not a valid argument for $self -> add_pub_xref()");
        }
    }
    else {
        # string maybe in db:acc format
        if ($xref =~ /\s*(\S+?):(\S+)/) {
            my ($db, $acc) = ($1, $2);
            $acc =~ s/ *$//;
            $xref = 
              GO::Model::Xref->new({xref_dbname=>$db,
                                    xref_key=>$acc});
        }
        else {
            $xref = 
              GO::Model::Xref->new({xref_dbname=>"UNKNOWN",
                                    xref_key=>"$xref"});
        }
        confess("Assertion error") unless $xref->isa("GO::Model::Xref");
        $self->add_pub_xref($xref);
    }
}

=head2 xref

  Usage   -
  Returns -
  Args    -

gets/sets the literature or sequence reference GO::Model::Xref

NOTE: at some point we may want to deprecate this method and persuade
API client code to call

  $ev->literature_xref

instead, to make explicit the fact that this is a literature reference
as opposed to a sequence reference

=cut

# dynamic method


=head2 xref_list

  Usage   -
  Returns - GO::Model::Xref listref
  Args    -

returns all (sequence and literature) references

=cut

sub xref_list {
    my $self = shift;
    if (@_) {
        confess("get only");
    }
    my @x = @{$self->pub_xref_list || []};
    push(@x, @{$self->seq_xref_list || []});
    return \@x;
}


=head2 xref

  Usage   -
  Returns -
  Args    -

deprected - sets first pub_xref_list

=cut

sub xref {
    my $self = shift;
    if (@_) {
        $self->pub_xref_list([@_]);
    }
    $self->pub_xref_list && $self->pub_xref_list->[0];
}


=head2 valid_codes

  Usage   - print join("; ", GO::Model::Evidence->valid_codes);
  Returns - string array
  Args    -

list of valid evidence codes

=cut

sub valid_codes {
    qw(IMP IGI IPI ISS IDA IEP IEA TAS NAS ND NR);
}

sub _initialize 
{

    my $self = shift;
    my $paramh = shift;
    if (!ref($paramh)) {
	confess("init param must be hash");
    }
    if ($paramh->{reference}) {
	my ($db, @keyparts) = split (/:/, $paramh->{reference});
        # usually there is only one : in the dbxref, but
        # MGI includes the dbname in the id, so their
        # dbxrefs look like this:
        # MGI:MGI:00000001
        my $key = join(":", @keyparts);
	if (!$key) {
	    $key = $db;
	    $db = "U";
	}
	else {
	    ($db) =~ tr/A-Z/a-z/;
	}
	my $xref = 
	  GO::Model::Xref->new({xref_key=>$key,
				xref_dbname=>$db});
	
	$self->xref($xref);
	delete $paramh->{reference};
    }
    $self->SUPER::_initialize($paramh);
}

sub to_idl_struct {
    my $self = shift;
    if (!$self->xref) {
	confess("$self has no xref");
    }
    return 
      {
       code=>$self->code,
       seq_acc=>$self->seq_acc,
       dbxref=>$self->xref->to_idl_struct,
      };
}


sub from_idl {
    my $class = shift;
    my $h = shift;
    $h->{dbxref} = GO::Model::Xref->from_idl($h->{dbxref});
    return $class->new($h);
}

# **** EXPERIMENTAL CODE ****
# the idea is to be homogeneous and use graphs for
# everything; eg gene products are nodes in a graph,
# associations are arcs
# cf rdf, daml+oil etc

# args - optional graph to add to
sub graphify {
    my $self = shift;
    my ($ref, $subg, $opts) =
      rearrange([qw(ref graph opts)], @_);

    $opts = {} unless $opts;
    $subg = $self->apph->create_graph_obj unless $subg;

    my $acc = sprintf("%s", $self);
    my $t =
      $self->apph->create_term_obj({name=>$acc,
                                    acc=>$acc});
    $subg->add_node($t);
    $subg->add_arc($t, $ref, "hasEvidence") if $ref;

    foreach my $xr (@{$self->xref_list || []}) {
        $xr->apph($self->apph);
        $xr->graphify($t, $subg);
    }
    my $code = $self->code;
    my $cn = $subg->get_node($code);
    if (!$cn) {
        $cn =
          $self->apph->create_term_obj({name=>$code,
                                        acc=>$code});
        $subg->add_node($cn);
    }
    $subg->add_arc($cn, $t, "hasCode");
    $subg;
}

1;
