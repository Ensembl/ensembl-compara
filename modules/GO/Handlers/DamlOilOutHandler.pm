# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.godatabase.org/dev
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

  GO::Handlers::DamlOilOutHandler     - 

=head1 SYNOPSIS

  use GO::Handlers::DamlOilOutHandler

=cut

=head1 DESCRIPTION

=head1 PUBLIC METHODS - 

=cut

# makes objects from parser events

package GO::Handlers::DamlOilOutHandler;
use base qw(GO::Handlers::ObjHandler);
use FileHandle;
#use GO::IO::DamlOil;
use XML::Writer;
use strict;

sub w {
    my $self = shift;
    $self->{_w} = shift if @_;
    return $self->{_w};
}

sub fh {
    my $self = shift;
    $self->{_fh} = shift if @_;
    return $self->{_fh};
}


sub init {
    my $self = shift;
    $self->SUPER::init(@_);
#    my $fh = FileHandle->new;
    my $fh = \*STDOUT;
    $self->fh($fh);
    return;
}

our $DAML = "http://www.daml.org/2001/03/daml+oil#"=>'daml';
our $OILED = "http://img.cs.man.ac.uk/oil/oiled#"=>'oiled';
our $RDF = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"=>'rdf';
our $RDFS = "http://www.w3.org/2000/01/rdf-schema#"=>'rdfs';

sub prefix_map {
    return
      {
       $DAML=>'daml',
       $RDF=>'rdf',
       $RDFS=>'rdfs',
       $OILED=>'oiled',
       ''=>'',
      };
}

sub export {
    my $self = shift;
    my $g = $self->g;
    
#    my $io =
#      GO::IO::DamlOil->new;
#    $io->write_graph($g);
#    
    $self->write_hdr;
    foreach my $t (@{$g->get_all_nodes}) {
        $self->write_classdef($t);
    }
    $self->write_end;
}


sub write_hdr {
    my $self = shift;
    my $fh = $self->fh;
    print $fh <<EOM;
<?xml version='1.0' encoding='UTF-8'?>
<rdf:RDF xmlns:daml="http://www.daml.org/2001/03/daml+oil#"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:oiled="http://img.cs.man.ac.uk/oil/oiled#"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" xmlns:xsd="http://www.w3.org/2000/10/XMLSchema#">
    <daml:Ontology rdf:about="">
        <dc:title>__EXPERIMENTAL__ GO DAML+OIL export </dc:title>
        <dc:creator>automatic</dc:creator>
        <dc:description></dc:description>
        <dc:subject></dc:subject>
        <daml:versionInfo>1.1</daml:versionInfo>
    </daml:Ontology>
EOM
}

sub write_end {
    my $self = shift;
    my $fh = $self->fh;
    print $fh <<EOM;
</rdf:RDF>
EOM
}

sub write_restr {
    my $self = shift;
    my ($on, $type, $to) = @_;
    my $fh = $self->fh;

    my $fmt = <<EOM;
  <rdfs:subClassOf>
    <daml:Restriction>
      <daml:onProperty rdf:resource="%s"/>
      <daml:$type rdf:resource="%s"/>
      </daml:Restriction>
  </rdfs:subClassOf>
EOM
    printf $fh $fmt, $on, $to;

}

sub write_sc {
    my $self = shift;
    my ($class) = @_;
    my $fh = $self->fh;

    my $fmt = <<EOM;
  <rdfs:subClassOf>
    <daml:Class rdf:about="%s"/>
  </rdfs:subClassOf>
EOM
    printf $fh $fmt,
      safe($class);
}

sub write_classdef {
    my $self = shift;
    my $t = shift;
    my $g = $self->g;
    my $fh = $self->fh;
    printf $fh
      "<rdfs:Class rdf:about=\"%s\">\n", 
        safe($t->name);

#    $self->write_restr("hasUniqueIdentifier", "hasValue", $t->acc);
    if ($t->definition) {
	printf $fh
	  "  <rdfs:comment>%s</rdfs:comment>\n", $t->definition;
    }
    my $syn = $t->synonym_list || [];
    map {
	$self->write_restr("hasSynonym", "hasValue", $_);
    } @$syn;

#    printf STDERR "DOING:%s\n", $t->name;
#    $self->w->startTag([$DAML,'Class'],
#                       [$RDF,'about']=>safe($t->name));
#    $self->w->dataElement([$RDFS,'label'],
#                          safe($t->name));
#    $self->w->dataElement([$RDFS,'comment'],
#                          $t->definition) if $t->definition;
    my $prels = $g->get_parent_relationships($t->acc);
    my $has_isa;
    foreach my $prel (@$prels) {
        my $type = $prel->type;
        my $pt = $g->get_term($prel->acc1);
        if (!$pt) {
            warn("no term for ".$prel->acc1);
            next;
        }
        if (lc($type) eq "is_a") {
	    $has_isa = 1;
	    $self->write_sc($pt->name);
        }
        else {
	    $self->write_restr(safe($type), "hasClass", safe($pt->name));
        }
    }
    if (!$has_isa) {
	my $categ = $g->category_term($t->acc);
	if ($categ) {
	    my $cn;
	    if (!$categ) {
		$cn = "Top";
	    }
	    else {
		$cn = $categ->name;
	    }
	    $self->write_sc($cn);
	}
    }
    printf $fh "</rdfs:Class>\n";
    return;
}

sub safe {
    my $word = shift;
    $word =~ s/ /_/g;
    $word =~ s/\-/_/g;
    $word =~ s/\'/prime/g;
    $word =~ tr/a-zA-Z0-9_//cd;
    $word =~ s/^([0-9])/_$1/;
    $word;
}

sub quote {
    my $word = shift;
    $word =~ s/\'//g;
    $word =~ s/\"/\\\"/g;
    $word =~ tr/a-zA-Z0-9_//cd;
    "\"$word\"";
}

1;
