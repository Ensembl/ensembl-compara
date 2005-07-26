# makes objects from parser events

package GO::Handlers::RdfOutHandler;
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

sub e_ontology {
    my $self = shift;
    my $g = $self->g;
    my $xml_out = GO::IO::XML->new(-output=>$self->fh);
    $xml_out->start_document();
    $xml_out->draw_node_graph(-graph=>$g);
    $xml_out->end_document();

}

1;
