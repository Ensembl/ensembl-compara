# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

package GO::Model::Xref;

=head1 NAME

  GO::Model::Xref;

=head1 SYNOPSIS

  my $xrefs = $term->dbxref_list();
  foreach my $xref (@$xrefs) P
    printf "Term %s has an xref %s:%s\n", 
            $term->name, $xref->xref_key, $xref->dbname;
  }

=head1 DESCRIPTION

represents a cross reference to an external database. an Xref is made
up of a key (ie the accession number, or whatever the value of the
unique field being keyed off of is) and a database name. this should
theorerically be enough to uniquely identify any databased entity.

=head1 NOTES

Like all the GO::Model::* classes, this uses accessor methods to get
or set the attributes. by using the accessor method without any
arguments gets the value of the attribute. if you pass in an argument,
then the attribuet will be set according to that argument.

for instance

  # this sets the value of the attribute
  $my_object->attribute_name("my value");

  # this gets the value of the attribute
  $my_value = $my_object->attribute_name();

=cut


use Carp qw(cluck confess);
use Exporter;
use GO::Utils qw(rearrange);
use GO::Model::Root;
use strict;
use vars qw(@ISA);

@ISA = qw(GO::Model::Root Exporter);


sub _valid_params {
    return qw(id xref_key xref_keytype xref_dbname xref_desc);
}

sub _valid_dbnames {
    return qw(go gxd sgd tair mgi fb sp sp_kw egad
	      ec medline pmid isbn omim embl publication U);
}


=head2 xref_key

  Usage   -
  Returns -
  Args    -

 accessor: gets/sets the key/id of the cross reference

=cut

sub xref_key {
    my $self = shift;
    $self->{xref_key} = shift if @_;
    if ($self->{xref_dbname} &&
        $self->{xref_dbname} =~ /interpro/i) {
        if ($self->{xref_key} && $self->{xref_key} =~ /(\S+) (.*)/) {
            $self->{xref_key} = $1;
            $self->{xref_desc} = $2;
        }
    }
    return $self->{xref_key};
}
*accession = \&xref_key;
*acc = \&xref_key;


=head2 xref_keytype

  Usage   -
  Returns -
  Args    -

 accessor: gets/sets the key/id type of the cross reference


=cut

sub xref_keytype {
    my $self = shift;
    $self->{xref_keytype} = shift if @_;
    return $self->{xref_keytype};
}


=head2 as_str

  Usage   -
  Returns -
  Args    -

=cut

sub as_str {
    my $self=shift;
#    cluck unless defined $self->xref_dbname;
#    cluck unless defined $self->xref_key;
    return $self->xref_dbname().":".$self->xref_key();
}


=head2 xref_dbname

  Usage   -
  Returns -
  Args    -

 accessor: gets/sets the database name of the cross reference

must be a valid database name

=cut

sub xref_dbname {
    my $self = shift;
    $self->{xref_dbname} = shift if @_;
    return $self->{xref_dbname};
}
*dbname = \&xref_dbname;

=head2 xref_desc

  Usage   -
  Returns -
  Args    -

 accessor: gets/sets the description of the accession no

useful for interpro

=cut

sub xref_desc {
    my $self = shift;
    $self->{xref_desc} = shift if @_;
    return $self->{xref_desc};
}

sub to_idl_struct {
    my $self = shift;
    return
      {
       dbname=>$self->xref_dbname,
       keyvalue=>$self->xref_key,
      };
}


=head2 to_xml

  Usage   - print $xref->to_xml()
  Returns - string
  Args    - indent [integer]

XML representation; you probably shouldnt call this directly, this
will be called by entities that own xrefs

=cut

sub to_xml {
    my $self = shift;
    my $indent = shift || "";

    my $text = $indent."<game:db_xref>\n";
    $text .= $indent."  <game:db_name>".
	$self->xref_dbname."</game:db_name>\n";
    if ( $self->xref_keytype ) {
	if ( $self->xref_keytype =~ /personal communication/ ) {
	    $text .= $indent."  <game:xref_type>".
		$self->xref_keytype."</game:xref_type>\n";
	    $text .= $indent."  <xref_person>".
		$self->xref_key."</xref_person>\n";
	}
	else {
	    if ($self->xref_keytype !~ /acc/) {
		$text .= $indent."  <game:xref_type>".
		    $self->xref_keytype."</game:xref_type>\n";
	    }
	    $text .= $indent."  <game:db_id>".
		$self->xref_key."</game:db_id>\n";
	}
    }
    else {
	$text .= $indent."  <game:db_id>".$self->xref_key."</game:db_id>\n";
    }
    $text .= $indent."</game:db_xref>\n";
    return $text;
}

sub to_ptuples {
    my $self = shift;
    my ($th) =
      rearrange([qw(tuples)], @_);
    my @s = ();
    my @desc = ($self->xref_desc);
    pop @desc unless $desc[0];
    push(@s,
         ["xref",
          $self->as_str,
          $self->xref_dbname,
          $self->xref_key,
          @desc,
          ]);
    @s;
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

    my $t =
      $self->apph->create_term_obj({name=>$self->as_str,
                                    acc=>$self->as_str});
    $subg->add_node($t);
    $subg->add_arc($t, $ref, "hasXref");
    return $subg;
}

1;
