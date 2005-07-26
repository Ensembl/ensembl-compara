# makes objects from parser events

package GO::Handlers::ChadoXmlOutHandler;
use base qw(GO::Handlers::ObjHandler);
use FileHandle;
use GO::IO::XML;
use strict;

sub _valid_params { qw(w fh strictorder) }
sub init {
    my $self = shift;
    $self->SUPER::init(@_);
#    my $fh = FileHandle->new;
    my $fh = \*STDOUT;
    $self->fh($fh);
    return;
}

sub export {
    my $self = shift;
    require "Data/Stag/XMLWriter.pm";
    my $w = Data::Stag::XMLWriter->new;
    $w->start_event("chado");
    my $g = $self->g;
    my $it = $g->create_iterator;
    while (my $t = $it->next_node) {
	my $syns = $t->synonym_list;
	my $xrefs = $t->dbxref_list;
	$w->event(cvterm=>[
			   [feature_id=>$t->acc],
			   [dbxref => [
				       [accession => $t->primary_xref->accession],
				       [dbname    => $t->primary_xref->dbname],
				      ]],
			   [termname=>$t->name],
			   [cvname=>$t->type],
			   $t->definition ?
			   ([termdefinition=>$t->definition]) : (),
			   (map {
			       [cvtermsynonym=>[
						 [termsynonym=>$_],
						]
			       ]
			   } @$syns),
			   (map {
			       [cvterm_dbxref=>[
						[dbxref => [
							    [dbname=>$_->xref_dbname],
							    [accession=>$_->xref_key],
							   ]
						]
					       ]
			       ]
			   } @$xrefs),
			  ]
		 );
    }
    $it = $g->create_iterator;
    while (my $t = $it->next_node) {
	my $prels = $g->get_parent_relationships($t->acc);
	foreach my $prel (@$prels) {
	    $w->event(
		      cvrelationship=>[
				       [reltype=>$prel->type],
				       [subjterm_id=>$t->acc],
				       [objterm_id=>$prel->acc1],
				      ]
		     );
	}
    }
    my @nodes = @{$g->get_all_nodes};
    my $it = $g->create_iterator({direction=>"up"});

    # turn off for now
    @nodes = ();

    foreach my $node (@nodes) {
        $it->reset_cursor($node->acc);
        while (my $ni = $it->next_node_instance) {
	    $w->event(
		      cvpath=>[
			       [distance=>$ni->depth],
			       [subjterm_id=>$node->acc],
			       [objterm_id=>$ni->term->acc]
			      ]
		     );
        }
    }
    $w->end_event("chado");
#    my $fh = $self->fh;
#    print $fh $w->tree->xml;
}

1;
